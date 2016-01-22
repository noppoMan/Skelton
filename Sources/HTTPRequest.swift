//
//  HTTPRequest.swift
//  SlimaneHTTP
//
//  Created by Yuki Takei on 1/11/16.
//  Copyright © 2016 MikeTOKYO. All rights reserved.
//

import HTTP
import Core

/**
 HTTP Request Type
 */
public class HTTPRequest {
    internal var request: Request
    
    /**
     - parameter request: HTTP.Request instance
    */
    public init(_ request: Request){
        self.request = request
    }
    
    /**
     context for keeping values that are used in high layer application.
     */
    public var context: [String: Any] {
        get {
            return request.context
        }
        set {
            request.context = newValue
        }
    }
    
    /**
     Returns MediaType for request
    */
    public var contentType: MediaType? {
        get {
            return request.contentType
        }
    }
    
    /**
     If true the request need to upgrade specific protocol(WebSocket, HTTP/2.0 etc..)
    */
    public var upgrade: Bool {
        get {
            return request.upgrade
        }
    }
    
    /**
     Http major version
    */
    public var majorVersion: Int {
        get {
            return request.majorVersion
        }
    }
    
    /**
     Http minor version
     */
    public var minorVersion: Int {
        get {
            return request.minorVersion
        }
    }
    
    /**
     String encoded body data
    */
    public var bodyString: String? {
        get {
            return request.bodyString
        }
    }
    
    /**
     Hex String encoded body data
     */
    public var bodyHexString: String {
        get {
            return request.bodyHexString
        }
    }
    
    /**
     Int8 Byte array body data
     */
    public var body: [Int8] {
        get {
            return request.body
        }
    }
    
    /**
     parameters that are in uri.
     If incoming url is /path/:id we can get the :id with params["id"]
    */
    public var params: [String: String] {
        get {
            return request.parameters
        }
        set {
            request.parameters = newValue
        }
    }
    
    /**
     Query string in uri
    */
    public var query: [String: String] {
        get {
            return request.uri.query
        }
    }
    
    /**
     All header values
    */
    public var headers: [String: String] {
        get {
            return request.headers
        }
    }
    
    /**
     keepalive
    */
    public var keepAlive: Bool {
        get {
            return request.keepAlive
        }
    }
    
    /**
     Returns parsed uri
    */
    public var uri : URI {
        get {
            return request.uri
        }
    }
    
    /**
     Returns requested http method
    */
    public var method : HTTP.Method {
        get {
            return request.method
        }
    }
    
    /**
     Take header value for key
    */
    public func getHeader(header: String) -> String? {
        return request.getHeader(header)
    }

}