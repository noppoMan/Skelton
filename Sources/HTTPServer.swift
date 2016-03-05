//
//  HTTPServer.swift
//  SlimaneHTTP
//
//  Created by Yuki Takei on 1/11/16.
//  Copyright © 2016 MikeTOKYO. All rights reserved.
//

#if os(Linux)
    import Glibc
#else
    import Darwin.C
#endif

import HTTP
import HTTPParser
import Suv
import CLibUv

/**
 Result enum for on HTTP Connection

 - Success: For getting request and response objects
 - Error: For getting Error
 */
public enum HTTPConnectionResult {
   case Success(HTTPRequest, HTTPResponse)
   case Error(ErrorType)
}

extension HTTP.Response {

   internal var byteDescription: [Int8] {
       return headerDescription.bytes + body
   }

   internal var headerDescription: String {
       var string = "HTTP/1.1 \(statusCode) \(reasonPhrase)\(CRLF)"

       for (header, value) in headers {
           string += "\(header): \(value)\(CRLF)"
       }

       string += "\(CRLF)"

       return string
   }

   public var shouldChunkedRespond: Bool {
       return headers["transfer-encoding"]?.lowercaseString == "chunked"
   }
}

public class HTTPServer {

    /**
    Event loop
    */
    public let loop: Loop

    /**
    The maximum number of tcp established connection that server can handle
    */
    public var backlog: UInt = 1024

    /**
    Seconds for keep alive timeout, if zero keep alive is disabled. Default is 75 (Same as Nginx)
    */
    public var keepAliveTimeout: UInt = 75

    /**
    Sets the maximum number of requests that can be served through one keep-alive connection. After the maximum number of requests are made, the connection is closed.
    */
    public var keepaliveRequests: UInt = 100

    /**
    Flag for Enable / disable Nagle’s algorithm.
    */
    public var setNoDelay = false


    private var roundRobinCounter = 0

    private let userOnConnection : HTTPConnectionResult -> ()

    private let server: TCPServer

    /**
    - parameter loop: Event loop
    - parameter ipcEnable: if true TCP is initilized as ipcMode and it can't bind, false it is initialized as basic TCP handle instance
    - parameter onConnection: Connection handler
    */
    public init(loop: Loop = Loop.defaultLoop, ipcEnable: Bool = false, onConnection: HTTPConnectionResult -> () = {_ in}) {
        self.loop = loop
        self.userOnConnection = onConnection
        self.server = TCPServer(loop: loop, ipcEnable: ipcEnable)
        
        // Ignore SIGPIPE
        signal(SIGPIPE, SIG_IGN)
    }

    /**
    Bind address

    - parameter addr: Bind Address
    - throws: SuvError.UVError
    */
    public func bind(addr: Address) throws {
        try server.bind(addr)
    }

    /**
    Listen HTTP Server
    */
    public func listen() throws {
        if server.socket.typeIsTcp && self.setNoDelay {
            try (server.socket as! TCP).setNoDelay(true)
        }
        
        try server.listen(backlog) { result in
            if case .Success(let queue) = result {
                self.onConnection(queue)
            }
            else if case .Error(let err) = result {
                return self.userOnConnection(.Error(err))
            }
        }
    }

    private func errorResponse(status: Status) -> HTTP.Response {
        return HTTP.Response(
            statusCode: status.statusCode,
            reasonPhrase: status.reasonPhrase,
            headers: [
                "content-type": "text/html",
                "date": Time.rfc1123
            ],
            body: "\(status.statusCode) \(status.reasonPhrase)".bytes
        )
    }

    private func onConnection(queue: Pipe?) {
        let client = TCP(loop: loop)
        
        // accept connection
        do {
            try server.accept(client, queue: queue)
        }  catch {
            self.userOnConnection(.Error(error))
            client.close()
        }
        
        // send handle to worker via ipc socket
        if Cluster.isMaster && shouldShareHandleWithWorker() {
            return sendHandleToWorker(client)
        }
    
        let parser = RequestParser { [unowned self] request in
//            if self.keepAliveTimeout > 0 {
//                do {
//                    if self.server.socket.typeIsTcp {
//                        try (self.server.socket as! TCP).setKeepAlive(true, delay: self.keepAliveTimeout)
//                    }
//                } catch {
//                    debug(error)
//                    return client.close()
//                }
//            }
            
            let req = HTTPRequest(request)

            let onHeaderCompletion = { (response: HTTP.Response) -> () in
                if response.shouldChunkedRespond {
                    client.write(response.headerDescription.bytes) { _ in
                        client.unref()
                    }
                }
            }

            let onBody = { (bytes: [Int8]) -> () in
                client.write(HTTPResponse.encodeAsStreamChunk(bytes)) { _ in
                    client.unref()
                }
            }

            let completionHandler = { [unowned self] (response: HTTP.Response?) -> () in
                if self.keepAliveTimeout == 0 || !request.keepAlive {
                    return client.close()
                }
                client.unref()
            }

            let onMessageComplete = { (response: HTTP.Response) -> () in
                let bodyBytes = response.shouldChunkedRespond ? "\(0)\(CRLF)\(CRLF)".bytes : response.byteDescription
                client.write(bodyBytes) { _ in
                    completionHandler(response)
                }
            }

            let onParseFailed = { [unowned self] (error: ErrorType, streaming: Bool) -> () in
                debug(error)
                if streaming {
                    return client.write("\(0)\(CRLF)\(CRLF)".bytes) { _ in
                        client.unref()
                    }
                }

                let response = self.errorResponse(.InternalServerError)
                client.write(response.description.bytes) { _ in
                    completionHandler(nil)
                }
            }

            let res = HTTPResponse(
                req,
                shouldCloseConnection: self.keepAliveTimeout == 0,
                onHeaderCompletion: onHeaderCompletion,
                onBody: onBody,
                onMessageComplete: onMessageComplete,
                onParseFailed: onParseFailed
            )

            self.userOnConnection(.Success(req, res))
        }

        client.read { [unowned client] result in
            if case let .Data(buf) = result {
                do {
                    let data: [Int8] = buf.bytes.map{ Int8(bitPattern: $0) }
                    try parser.parse(data)
                } catch {
                    self.userOnConnection(.Error(error))
                    client.close()
                }
            } else if case .Error(let error) = result {
                self.userOnConnection(.Error(error))
                client.close()
            } else {
                // EOF
                client.close()
            }
        }
    }

    private func shouldShareHandleWithWorker() -> Bool {
        return Cluster.workers.count > 0
    }
    
    // sending handles over a pipe
    private func sendHandleToWorker(client: TCP){
        let worker = Cluster.workers[self.roundRobinCounter]

        // send stream to worker with ipc
        client.write2(worker.ipcPipe!)
        client.close() // not immediately

        roundRobinCounter = (roundRobinCounter + 1) % Cluster.workers.count
    }

    /**
    Close server handle
    */
    public func close(){
        self.server.close()
    }
}
