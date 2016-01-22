//
//  HTTPClientTests.swift
//  SlimaneHTTP
//
//  Created by Yuki Takei on 2/19/16.
//  Copyright © 2016 MikeTOKYO. All rights reserved.
//

import XCTest
import Suv
import Core
import HTTP
import SlimaneHTTP
import CLibUv

class HTTPClientTests: XCTestCase {
    
    func testGetLargeContents(){
        waitUntil(10, description: "ListenAndConnect") { done in
            let request = HTTPClient(method: .GET, uri: URI(string: "http://miketokyo.com"))
            
            request.write()
            
            request.completion { result in
                if case .End(let res) = result {
                    XCTAssertEqual(res.statusCode, 200)
                    XCTAssertEqual(res.status, Status.OK)
                    XCTAssertGreaterThan(res.body.count, 0)
                    done()
                }
            }
            
            Loop.defaultLoop.run()
        }
    }
}


