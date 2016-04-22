//
//  Data.swift
//  SlimaneHTTPServer
//
//  Created by Yuki Takei on 4/10/16.
//  Copyright © 2016 MikeTOKYO. All rights reserved.
//

extension Data {
    public var signedBytes: [Int8] {
        return self.bytes.map { Int8(bitPattern: $0) }
    }

    public var bufferd: Buffer {
        return Buffer(bytes: self.bytes)
    }
}
