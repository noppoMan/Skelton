//
//  Skelton.swift
//  Skelton
//
//  Created by Yuki Takei on 6/17/16.
//
//

#if os(Linux)
    import Glibc
#else
    import Darwin.C
#endif

@_exported import Suv
@_exported import HTTPCore
import Foundation

public enum HttpConnection {
    case onRequest(Request, DuplexStream)
    case onError(Error)
    case onResetByPeer
}

/**
 Result enum for on HTTP Connection
 
 - Success: For getting request and response objects
 - Error: For getting Error
 */
public typealias HTTPOnConnection = (HttpConnection) -> Void

public final class Skelton {
    
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
    
    public var shouldKeepAlive: Bool {
        return keepAliveTimeout > 0
    }
    
    /**
     Sets the maximum number of requests that can be served through one keep-alive connection. After the maximum number of requests are made, the connection is closed.
     */
    public var keepaliveRequests: UInt = 100
    
    /**
     Flag for Enable / disable Nagle’s algorithm.
     */
    public var setNoDelay = false
    
    private var roundRobinCounter = 0
    
    private let requestHandler: HTTPOnConnection
    
    private let socket: TCP
    
    // Current connected clients count.
    public var clientsConnected: Int {
        return socketsConnected.count
    }
    
    public var socketsConnected = [TCP]()
    
    /**
     - parameter loop: Event loop
     - parameter ipcEnable: if true TCP is initilized as ipcMode and it can't bind, false it is initialized as basic TCP handle instance
     - parameter onConnection: Connection handler
     */
    public init(loop: Loop = Loop.defaultLoop, requestHandler: @escaping HTTPOnConnection = {_ in}) {
        self.loop = loop
        self.requestHandler = requestHandler
        self.socket = TCP(loop: loop)
        signal(SIGPIPE, SIG_IGN)
    }
    
    /**
     Bind address
     
     - parameter addr: Bind Address
     - throws: SuvError.UVError
     */
    public func bind(host: String = "0.0.0.0", port: Int) throws {
        try socket.bind(Address(host: host, port: port))
    }

    
    /**
     Listen HTTP Server
     */
    public func listen() throws {
        if self.setNoDelay {
            try socket.setNoDelay(true)
        }
        
        if Cluster.isWorker {
            let ipcChannel = Suv.Pipe(loop: loop, ipcEnable: true)
            ipcChannel.retain()
            ipcChannel.openIPCChannel()
            ipcChannel.read2(pendingType: .tcp) { result in
                switch result {
                case .success(let queue):
                    self.onConnection(queue)
                case .failure(let error):
                    self.requestHandler(.onError(error))
                }
            }
        } else {
            try socket.listen(backlog) { [unowned self] result in
                switch result {
                case .success(_):
                    self.onConnection(nil)
                case .failure(let error):
                    self.requestHandler(.onError(error))
                }
            }
        }
        
        Loop.defaultLoop.run()
    }
    
    public func closeClientsConnected() {
        for client in socketsConnected {
            client.close()
        }
    }
    
    /**
     Close server handle
     */
    public func close() {
        socket.close()
    }
    
    private func onConnection(_ queue: Suv.Pipe?) {
        let client = TCP(loop: loop)
        socketsConnected.append(client)
        
        client.retain()
        
        client.onClose { [unowned self, unowned client] in
            client.release()
            if let index = self.socketsConnected.index(of: client) {
                self.socketsConnected.remove(at: index)
            }
        }
        
        do {
            if let queue = queue {
                queue.release()
                try queue.accept(client)
            } else {
                try socket.accept(client)
            }
        } catch {
            client.close()
            self.requestHandler(.onError(error))
            return
        }
        
        if Cluster.isMaster && hasWorker {
            sendHandleToWorker(client)
            return
        }
        
        var parser: RequestParser? = RequestParser()
        
        client.read { [unowned self, unowned client] result in
            do {
                switch result {
                case .success(let data):
                    if let request = try parser?.parse(data) {
                        self.requestHandler(.onRequest(request, client))
                        parser = nil
                    }
                case .failure(let error):
                    client.close()
                    switch error {
                    case Suv.StreamError.eof:
                        self.requestHandler(.onResetByPeer)
                    default:
                        self.requestHandler(.onError(error))
                    }
                }
            } catch {
                client.close()
                self.requestHandler(.onError(error))
            }
        }
    }
    
    private var hasWorker: Bool {
        return Cluster.workers.count > 0
    }
    
    // sending handles over a pipe
    private func sendHandleToWorker(_ client: TCP){
        let worker = Cluster.workers[self.roundRobinCounter]
        // send stream to worker with ipc
        client.write2(ipcPipe: worker.ipcChan!)
        client.close()
        
        roundRobinCounter = (roundRobinCounter + 1) % Cluster.workers.count
    }
}

