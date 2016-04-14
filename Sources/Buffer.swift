//
//  Buffer.swift
//  SlimaneHTTPServer
//
//  Created by Yuki Takei on 4/10/16.
//  Copyright © 2016 MikeTOKYO. All rights reserved.
//


extension Buffer {
    public var data: Data {
        return Data(self.bytes)
    }
}