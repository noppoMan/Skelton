//
//  Stream.swift
//  SlimaneHTTPServer
//
//  Created by Yuki Takei on 4/15/16.
//
//

import C7
import CLibUv

public final class HTTPStream: AsyncStream {
    
    public var closed: Bool {
        return stream.isClosing()
    }
    
    let stream: TCP
    
    init(stream: TCP){
        self.stream = stream
    }
    
    public func setKeepAlive(delay: UInt) throws {
        try stream.setKeepAlive(true, delay: delay)
    }
    
    public func send(data: Data, timingOut deadline: Double = 0 /* infinit */, result: (Void throws -> Void) -> Void = { _ in}) {
        stream.write(data.bufferd) { res in
            result {
                if case .Error(let error) = res {
                    throw error
                }
            }
        }
    }
    
    public func receive(upTo byteCount: Int = 2048 /* ignored */, timingOut deadline: Double = 0 /* infinit */, result: (Void throws -> Data) -> Void) {
        stream.read { res in
            if case .Data(let buf) = res {
                result { buf.data }
            }
            else if case .Error(let error) = res {
                result { throw error }
            }
            else {
                result { throw SuvError.UVError(code: UV_EOF.rawValue) }
            }
        }
    }
    
    public func end(){
        stream.write("\(0)\(CRLF)\(CRLF)".bytes)
    }
    
    public func close() -> Bool {
        if closed {
            return true
        }
        stream.close()
        return stream.isClosing()
    }
    
    public func unref() {
        stream.unref()
    }
    
    public func flush(timingOut deadline: Double, result: (Void throws -> Void) -> Void = {_ in }) {
        // noop
    }
}
