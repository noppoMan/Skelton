//
//  HTTPClient.swift
//  SlimaneHTTP
//
//  Created by Yuki Takei on 1/30/16.
//  Copyright © 2016 MikeTOKYO. All rights reserved.
//

import Core
import Suv
import HTTP
import HTTPParser

public enum HTTPResponseResult {
    case Data(Buffer), End(HTTP.Response), Error(ErrorType), Close
}

public enum SocketState {
    case Ready, Connecting, Connected, Closing, Closed
}

/**
 HTTP Client
 */
public class HTTPClient {
    
    /**
     The HTTP Method to use this request.
    */
    public let method: HTTP.Method
    
    /**
     The Uri to use this request.
     */
    public let uri: URI
    
    //public var followRedirect = true
    
    private let port: Int
    
    private let socket: TCP
    
    private let httpVersion = "1.1"
    
    private var headers = [String: String]()
    
    private var onFinished: HTTPResponseResult -> () = {_ in}
    
    private var headerDescription: String {
        return headers.map { k, v in "\(k): \(v)" }.joinWithSeparator(CRLF)
    }
    
    /**
     Current socket state
    */
    public private(set) var state: SocketState = .Ready
    
    /**
     Returns true is the socket is stil active
    */
    public var socketIsActive: Bool {
        return self.socket.typeIsTcp && !self.socket.isClosing()
    }
    
    /**
     - parameters loop: Event loop
     - parameters method: The HTTP Method
     - parameters uri: The URI // ex. URI(string: "http://miketokyo.com")
    */
    public init(loop: Loop = Loop.defaultLoop, method: HTTP.Method, uri: URI){
        self.socket = TCP(loop: loop)
        self.method = method
        self.uri = uri
        self.port = self.uri.port == nil ? 80 : self.uri.port!
        
        setHeader("User-Agent", value: "SlimaneHTTP-Client/0.1.0")
        setHeader("Accept", value: "*/*")
        if let host = uri.host {
            setHeader("HOST", value: host)
        }
    }
    
    /**
     For setting request header field
     
     - parameter key: HTTP header field key name
     - parameter key: HTTP header field value
    */
    public func setHeader(key: String, value: String) {
        headers[key] = value
    }
    
    /**
     Get value that corresponded with specific header key name
     
     - parameter key: HTTP header field key name
     */
    public func getHeader(header: String) -> String? {
        for (key, value) in headers where key.lowercaseString == header.lowercaseString {
            return value
        }
        return nil
    }
    
    /**
     Write the http packet
     
     - parameter data: The HTTP Body Data
     */
    public func write(data: String = ""){
        if !socketIsActive { return }
        
        self.write(Buffer(data))
    }
    
    /**
     Write the http packet
     
     - parameter data: The HTTP Body Data
     */
    public func write(data: Buffer){
        if !socketIsActive { return }
        
        guard let host = self.uri.host else {
            return onFinished(.Error(SuvError.ArgumentError(message: "The option of `host` is required")))
        }
        
        self.state = .Connecting
        
        self.socket.connect(host: host, port: self.port) { [unowned self] result in
            self.state = .Connected
            
            if case .Error(let err) = result {
                return self.onFinished(.Error(err))
            }
            
            let reqStr = "\(self.method) \(self.uri.path ?? "/") HTTP/\(self.httpVersion)\(CRLF)\(self.headerDescription)\(CRLF)\(CRLF)\(data.toString()!)"
            
            let parser = RequestParser { request in
                self.onConnect(Buffer(reqStr))
            }
            
            do {
                try parser.parse(reqStr)
            } catch {
                self.onFinished(.Error(error))
            }
        }
    }
    
    /**
     Close established http connection
     */
    public func close(){
        if !socketIsActive { return }
        
        self.socket.shutdown()
        self.state = .Closed
    }
    
    /**
     completion handler for http stream.
     This will be called when received the all of response data or failed parsing response or eof detected.
    */
    public func completion(callback: HTTPResponseResult -> ()){
        self.onFinished = callback
    }
    
    private func onBody(bodyBytes: [Int8]){
        var buf = Buffer()
        buf.append(bodyBytes)
        self.onFinished(.Data(buf))
    }
    
    private func onMessageComplete(response: HTTP.Response){
        if response.headers["connection"]?.lowercaseString == "close" {
            self.close()
        } else {
            self.socket.unref()
        }
        
        self.onFinished(.End(response))
    }
    
    private func onHeaderComplete(response: HTTP.Response){}
    
    private func onConnect(data: Buffer){
        if !socketIsActive { return }
        
        self.socket.write(data) { [unowned self] result in
            if case .Error(let err) = result {
                return self.onFinished(.Error(err))
            }
            
            let parser = ResponseParser(
                headerCompletion: self.onHeaderComplete,
                onBody: self.onBody,
                messageCompletion: self.onMessageComplete
            )
            
            self.socket.read { result in
                if case .Data(let buf) = result {
                    do {
                        let data: [Int8] = buf.bytes.map{ Int8(bitPattern: $0) }                        
                        try parser.parse(data)
                    } catch {
                        self.onFinished(.Error(error))
                        self.close()
                    }
                } else if case .Error(let error) = result {
                    self.onFinished(.Error(error))
                    self.close()
                } else {
                    self.onFinished(.Close)
                    self.close()
                }
            }
        }
    }
}
