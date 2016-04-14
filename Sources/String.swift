//
//  String.swift
//  SlimaneHTTPServer
//
//  Created by Yuki Takei on 4/10/16.
//  Copyright © 2016 MikeTOKYO. All rights reserved.
//

extension String {
    internal var bytes: [Int8] {
        return self.utf8.map{ Int8(bitPattern: $0) }
    }
}
