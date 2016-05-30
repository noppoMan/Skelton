//
//  Response.swift
//  SlimaneHTTPServer
//
//  Created by Yuki Takei on 4/10/16.
//  Copyright © 2016 MikeTOKYO. All rights reserved.
//

let CRLF = "\r\n"

extension Response {
    public static func chunkedEncode(string: String) -> Data {
        return Data(chunkedEncode(data: Data(string)).map{ Byte($0) })
    }
    
    public static func chunkedEncode(data: Data) -> Data {
        return Data(chunkedEncode(bytes: data.signedBytes).map{ Byte($0) })
    }
    
    public static func chunkedEncode(bytes: [Int8]) -> [Int8] {
        var chunkedBytes = [Int8]()
        chunkedBytes.append(contentsOf: String(bytes.count, radix: 16).bytes)
        chunkedBytes.append(contentsOf: CRLF.bytes)
        chunkedBytes.append(contentsOf: bytes)
        chunkedBytes.append(contentsOf: CRLF.bytes)
        return chunkedBytes
    }
}
