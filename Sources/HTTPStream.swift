//
//  Stream.swift
//  SlimaneHTTPServer
//
//  Created by Yuki Takei on 4/15/16.
//
//

public typealias HTTPStream = TCPSocket

let CRLF = "\r\n"

extension HTTPStream {
    public func end(){
        self.send(Data("\(0)\(CRLF)\(CRLF)"))
    }
    
    public func send(chunk data: Data, timingOut deadline: Double = .never, completion: ((Void) throws -> Void) -> Void = { _ in }) {
        var chunk: Data = ""
        chunk += String(data.bytes.count, radix: 16)
        chunk += CRLF
        chunk += "\(data)"
        chunk += CRLF

        self.send(chunk, timingOut: deadline, completion: completion)
    }
}

extension HTTPStream: Equatable {}

public func ==(lhs: HTTPStream, rhs: HTTPStream) -> Bool {
    return ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
}

