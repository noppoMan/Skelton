//
//  debug.swift
//  SlimaneHTTP
//
//  Created by Yuki Takei on 2/20/16.
//  Copyright © 2016 MikeTOKYO. All rights reserved.
//

func debug<T>(val: T){
    if let debugMode = Process.env["SLIMANE_HTTP_DEBUG"] {
        if debugMode == "" {
            return
        }
        print(val)
    }
}

extension String {
    internal var bytes: [Int8] {
        return self.utf8.map{ Int8(bitPattern: $0) }
    }
}