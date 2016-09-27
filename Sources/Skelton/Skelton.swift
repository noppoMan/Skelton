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

/**
 Result enum for on HTTP Connection
 
 - Success: For getting request and response objects
 - Error: For getting Error
 */
public typealias HTTPConnection = (() throws -> (Request, Stream)) -> ()

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
    
    private let userOnConnection: HTTPConnection
    
    private let server: TCPServer
    
    // Current connected clients count.
    public var clientsConnected: Int {
        return socketsConnected.count
    }
    
    public var socketsConnected = [TCPSocket]()
    
    /**
     - parameter loop: Event loop
     - parameter ipcEnable: if true TCP is initilized as ipcMode and it can't bind, false it is initialized as basic TCP handle instance
     - parameter onConnection: Connection handler
     */
    public init(loop: Loop = Loop.defaultLoop, ipcEnable: Bool = false, onConnection: @escaping HTTPConnection = {_ in}) {
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
    public func bind(host: String = "0.0.0.0", port: Int) throws {
        try server.bind(URL(string: "http://\(host):\(port)")!)
    }
    
    /**
     Listen HTTP Server
     */
    public func listen() throws {
        if let socket = server.socket , self.setNoDelay {
            try socket.setNoDelay(true)
        }
        
        try server.listen(backlog) { [unowned self] getQueue in
            do {
                self.onConnection(try getQueue())
            } catch {
                self.userOnConnection {
                    throw error
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
        server.close()
    }
    
    private func onConnection(_ queue: PipeSocket?) {
        let client = TCPSocket()
        socketsConnected.append(client)
        
        let unmanaged = Unmanaged.passRetained(client)
        
        client.onClose { [unowned self, unowned client] in
            unmanaged.release()
            if let index = self.socketsConnected.index(of: client) {
                self.socketsConnected.remove(at: index)
            }
        }
        
        do {
            // accept connection
            try server.accept(client, queue: queue)
        }  catch {
            client.close()
            self.userOnConnection {
                throw error
            }
        }
        
        // send handle to worker via ipc socket
        if Cluster.isMaster && hasWorker {
            return sendHandleToWorker(client)
        }
        
        let parser = RequestParser()
        
        client.read { [unowned self, unowned client] getData in
            do {
                let data = try getData()
                if let request = try parser.parse(data) {
                    self.userOnConnection {
                        (request, client)
                    }
                }
            } catch StreamWrapError.eof {
                client.close()
                self.userOnConnection {
                    throw StreamError.closedStream(data: [])
                }
            } catch {
                if !self.shouldKeepAlive {
                    client.close()
                    self.userOnConnection {
                        throw error
                    }
                }
            }
        }
    }
    
    private var hasWorker: Bool {
        return Cluster.workers.count > 0
    }
    
    // sending handles over a pipe
    private func sendHandleToWorker(_ client: TCPSocket){
        let worker = Cluster.workers[self.roundRobinCounter]
        
        // send stream to worker with ipc
        client.write(queue: worker.ipcChan!)
        client.close()
        
        roundRobinCounter = (roundRobinCounter + 1) % Cluster.workers.count
    }
}

