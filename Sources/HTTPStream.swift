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
    
    public enum Error: ErrorProtocol {
        case EOF
    }
    
    public var closed: Bool {
        return stream.isClosing()
    }
    
    let stream: TCP
    
    init(stream: TCP){
        self.stream = stream
    }
    
    public func setKeepAlive(_ delay: UInt) throws {
        stream.unref()
        try stream.setKeepAlive(true, delay: delay)
    }
    
    public func send(_ data: Data, timingOut deadline: Double = .never, completion result: ((Void) throws -> Void) -> Void = { _ in}) {
        stream.write(buffer: data.bufferd) { res in
            result {
                if case .Error(let error) = res {
                    throw error
                }
            }
        }
    }
    
    public func receive(upTo byteCount: Int = 2048 /* ignored */, timingOut deadline: Double = .never, completion result: ((Void) throws -> Data) -> Void) {
        stream.read { res in
            if case .Data(let buf) = res {
                result { buf.data }
            }
            else if case .Error(let error) = res {
                result { throw error }
            }
            else {
                result { throw Error.EOF }
            }
        }
    }
    
    public func end(){
        stream.write(bytes: "\(0)\(CRLF)\(CRLF)".bytes)
    }
    
    public func close() throws {
        if closed {
            throw StreamError.closedStream(data: [])
        }
        stream.close()
    }
    
    public func flush(timingOut deadline: Double, completion result: ((Void) throws -> Void) -> Void = {_ in }) {
        // noop
    }
}
