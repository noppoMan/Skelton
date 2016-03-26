//
//  HTTPResponse.swift
//  SlimaneHTTP
//
//  Created by Yuki Takei on 1/11/16.
//  Copyright © 2016 MikeTOKYO. All rights reserved.
//

import Foundation
import HTTP
import HTTPParser
import Suv

let CRLF = "\r\n"

/**
 HTTP Response Type
 */
public class HTTPResponse {
    /**
     context for keeping values that are used in high layer application.
     */
    public var context: [String: Any] = [:]
    
    
    private let shouldCloseConnection: Bool
    
    /**
     Checking for either header is already sent or not
     */
    public private(set) var headerIsAlreadySent = false
    
    private var _parser: ResponseParser? = nil
    
    private var parser: ResponseParser {
        return _parser!
    }
    
    private var request: HTTPRequest
    
    private var status = Status.OK
    
    private var _headers: [String: String] = [:]
    
    private(set) var beforeWriteCallback: (() -> ())? = nil
    
    private(set) var afterWriteCallback: (Response? -> ())? = nil
    
    private var onParseFailed: (ErrorType, Bool) -> Void = { err, _ in print(err) }
    
    /**
     -parameter request: HTTPRequest
     -parameter shouldCloseConnection: If true server will shoutdown connection even though request header has Connection: Keep-Alive
     -parameter onHeaderCompletion: Handler for http header parsing completion
     -parameter onBody: HTTPRequest Handler for each body callback this is able to use when transfer-encoding is enabled
     -parameter onMessageComplete: Handler for http message parsing completion
     -parameter onParseFailed: Handler for http parsing error
     */
    public init(request: inout HTTPRequest,
        shouldCloseConnection: Bool,
        onHeaderCompletion: Response -> Void = {_ in},
        onBody: [Int8] -> Void = {_ in},
        onMessageComplete: Response -> Void = {_ in},
        onParseFailed: (ErrorType, Bool) -> Void = { err, _ in print(err) }
    ){
        self.shouldCloseConnection = shouldCloseConnection
        self.request = request
        
        self.onParseFailed = onParseFailed
        
        self._parser = ResponseParser(
            headerCompletion: onHeaderCompletion,
            onBody: onBody,
            messageCompletion: { [unowned self] response in
                if let cb = self.afterWriteCallback {
                    cb(response)
                }
                onMessageComplete(response)
            }
        )
    }
    
    /**
     Calback for bwfore writing response
     */
    public func beforeWrite(callback: () -> ()){
        self.beforeWriteCallback = callback
    }
    
    /**
     Calback for after writing response
     */
    public func afterWrite(callback: Response? -> ()){
        self.afterWriteCallback = callback
    }
}

extension HTTPResponse {
    
    /**
     Returns all headers
     */
    public var headers: [String: String] {
        return _headers
    }
    
    /**
     Returns header value for key
     */
    public func getHeader(header: String) -> String? {
        for (key, value) in headers where key.lowercaseString == header.lowercaseString {
            return value
        }
        return nil
    }
    
    /**
     For setting http header field
     */
    public func setHeader(name: String, _ value: String) {
        _headers[name.lowercaseString] = value
    }
    
    /**
     For settig http status
     */
    public func status(status: Status) -> HTTPResponse {
        self.status = status
        return self
    }
    
    /**
     Returns true if `Transfer-Encoding: Chunked`
     */
    public var shouldChunkedRespond: Bool {
        return getHeader("transfer-encoding")?.lowercaseString == "chunked"
    }
}

extension HTTPResponse {
    
    /**
     String header description
     */
    public var headerDescription: String {
        let headerDescription = headers.map { k, v in return "\(k): \(v)" }.joinWithSeparator(CRLF)
        return "HTTP/1.1 \(String(status.statusCode)) \(status.reasonPhrase)\(CRLF)\(headerDescription)\(CRLF)\(CRLF)"
    }
    
    /**
     End http session. If Transfer-encoding is Chunked, You should call end() at the last.
     */
    public func end() {
        do {
            if shouldChunkedRespond {
                try parser.parse("\(0)\(CRLF)\(CRLF)".bytes)
            } else {
                try parser.eof()
            }
        } catch {
            onParseFailed(error, self.shouldChunkedRespond)
        }
    }
    
    /**
     Prepare to write data to client
     
     - parameter body: Buffer to write
     */
    public func write(body: Buffer){
        let data: [Int8] = body.bytes.map { Int8(bitPattern: $0) }
        write(data)
    }
    
    /**
     Prepare to write data to client
     
     - parameter body: String value to write
     */
    public func write(body: String){
        let data: [Int8] = body.bytes
        write(data)
    }
    
    /**
     Prepare to write data to client
     
     - parameter body: Int8 array bytes to write
     */
    public func write(body: [Int8]){
        if headerIsAlreadySent {
            if self.shouldChunkedRespond {
                return parseBody(HTTPResponse.encodeAsStreamChunk(body))
            }
            
            print("Can't set headers after they are sent")
        }
        
        writeHead(body)
        
        if body.count > 0 {
            parseBody(body)
        }
    }
    
    internal static func encodeAsStreamChunk(bytes: [Int8]) -> [Int8] {
        var chunkedBytes = [Int8]()
        chunkedBytes.appendContentsOf(String(NSString(format:"%2X", bytes.count)).trim().bytes)
        chunkedBytes.appendContentsOf(CRLF.bytes)
        chunkedBytes.appendContentsOf(bytes)
        chunkedBytes.appendContentsOf(CRLF.bytes)
        
        return chunkedBytes
    }
    
    public func writeHead(body: [Int8]) {
        if headerIsAlreadySent {
            return
        }
        
        if shouldCloseConnection || !request.keepAlive {
            setHeader("Connection", "Close")
        } else {
            setHeader("Connection", "Keep-Alive")
        }
        
        if !shouldChunkedRespond {
            if getHeader("content-length") == nil {
                setHeader("content-length", "\(body.count)")
            }
        }
        
        if getHeader("content-type") == nil {
            setHeader("content-type", "text/html")
        }
        
        setHeader("Date", Time.rfc1123)
        
        if let beforeWrite = self.beforeWriteCallback {
            beforeWrite()
        }
        
        do {
            try parser.parse(headerDescription.bytes)
        } catch {
            onParseFailed(error, self.shouldChunkedRespond)
        }
        
        self.headerIsAlreadySent = true
    }
    
    private func parseBody(body: [Int8]){
        do {
            try parser.parse(body)
        } catch {
            onParseFailed(error, self.shouldChunkedRespond)
        }
    }
}
