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
            string += "\(header.capitalizedString): \(value.capitalizedString)\(CRLF)"
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
     Seconds for keep alive timeout, if zero keep alive is disabled. Default is 15 (Same as Nginx)
     */
    public var keepAliveTimeout: UInt = 15
    
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
    
    private var establishedClients = [UnsafeMutablePointer<TCP>]()
    
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
        
        // connection GC
        let t = Timer(loop: loop, mode: .Interval, tick: 5000)
        t.start { [unowned self] in
            t.stop()
            debug("Pooled connections: \(self.establishedClients.count)")
            
            func conGC(client: UnsafeMutablePointer<TCP>, index: inout Int) -> Int {
                // TODO need to manage socket state
                if !client.memory.typeIsTcp || client.memory.isClosing() {
                    self.establishedClients.removeAtIndex(index)
                    index-=1
                    client.destroy()
                    client.dealloc(1)
                }
                index+=1
                return self.establishedClients.count > index ? conGC(self.establishedClients[index], index: &index) : index
            }
            
            if self.establishedClients.isEmpty { return }
            
            var index = 0
            conGC(self.establishedClients[index], index: &index)
            
            t.resume()
        }
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
        
        try server.listen(backlog) { [unowned self] result in
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
        // TODO need to fix more ARC friendly
        let client = UnsafeMutablePointer<TCP>.alloc(1)
        client.initialize((TCP(loop: loop)))
        
        self.establishedClients.append(client)
        
        do {
            // accept connection
            try server.accept(client.memory, queue: queue)
            
            // keep alive
            if self.keepAliveTimeout > 0 {
                try client.memory.setKeepAlive(true, delay: self.keepAliveTimeout)
            }
        }  catch {
            self.userOnConnection(.Error(error))
            client.memory.close()
        }
        
        // send handle to worker via ipc socket
        if Cluster.isMaster && shouldShareHandleWithWorker() {
            return sendHandleToWorker(client)
        }
        
        let parser = RequestParser { [unowned self] request in
            var req: HTTPRequest? = HTTPRequest(request)
            var res: HTTPResponse? = nil
            
            let onHeaderCompletion = { (response: HTTP.Response) -> () in
                if !client.memory.typeIsTcp {
                    return
                }
                
                if response.shouldChunkedRespond {
                    client.memory.write(response.headerDescription.bytes) { _ in
                        client.memory.unref()
                    }
                }
            }
            
            let onBody = { (bytes: [Int8]) -> () in
                client.memory.write(HTTPResponse.encodeAsStreamChunk(bytes)) { _ in
                    client.memory.unref()
                }
            }
            
            let completionHandler = { (response: HTTP.Response?) -> () in
                defer {
                    req = nil
                    res = nil
                }
                if self.keepAliveTimeout == 0 || !request.keepAlive {
                    return client.memory.close()
                }
                
                client.memory.unref()
            }
            
            let onMessageComplete = { (response: HTTP.Response) -> () in
                let bodyBytes = response.shouldChunkedRespond ? "\(0)\(CRLF)\(CRLF)".bytes : response.byteDescription
                
                if !client.memory.typeIsTcp {
                    return
                }
                
                client.memory.write(bodyBytes) { _ in
                    completionHandler(response)
                }
            }
            
            let onParseFailed = { (error: ErrorType, streaming: Bool) -> () in
                debug(error)
                if streaming {
                    return client.memory.write("\(0)\(CRLF)\(CRLF)".bytes) { _ in
                        client.memory.unref()
                    }
                }
                
                let response = self.errorResponse(.InternalServerError)
                client.memory.write(response.description.bytes) { _ in
                    completionHandler(nil)
                }
            }
            
            res = HTTPResponse(
                request: &req!,
                shouldCloseConnection: self.keepAliveTimeout == 0,
                onHeaderCompletion: onHeaderCompletion,
                onBody: onBody,
                onMessageComplete: onMessageComplete,
                onParseFailed: onParseFailed
            )
            
            self.userOnConnection(.Success(req!, res!))
        }
        
        client.memory.read { [unowned self] result in
            if case let .Data(buf) = result {
                do {
                    let data: [Int8] = buf.bytes.map{ Int8(bitPattern: $0) }
                    try parser.parse(data)
                } catch {
                    self.userOnConnection(.Error(error))
                    client.memory.close()
                }
            } else if case .Error(let error) = result {
                self.userOnConnection(.Error(error))
                client.memory.close()
            } else {
                // EOF
                client.memory.close()
            }
        }
    }
    
    private func shouldShareHandleWithWorker() -> Bool {
        return Cluster.workers.count > 0
    }
    
    // sending handles over a pipe
    private func sendHandleToWorker(client: UnsafeMutablePointer<TCP>){
        let worker = Cluster.workers[self.roundRobinCounter]
        
        // send stream to worker with ipc
        client.memory.write2(worker.ipcPipe!)
        client.memory.close()
        
        roundRobinCounter = (roundRobinCounter + 1) % Cluster.workers.count
    }
    
    /**
     Close server handle
     */
    public func close(){
        self.server.close()
    }
}
