//
//  HttpServerTests.swift
//  SlimaneHTTP
//
//  Created by Yuki Takei on 2/16/16.
//  Copyright © 2016 MikeTOKYO. All rights reserved.
//


import XCTest
import Suv
import Core
import HTTP
import SlimaneHTTP
import CLibUv

class HTTPServerTests: XCTestCase {

    // TODO fix clush
    func testListenWithoutKeepAlive(){
        waitUntil(5, description: "Listen without KeepAlive") { done in
            let server = SlimaneHTTP.createServer { result in
                if case .Success(_, let res) = result {
                    res.write("Hello!!")
                }
            }

            server.keepAliveTimeout = 0 // off

            try! server.bind(Address(host: "127.0.0.1", port: 8888))
            try! server.listen()

            let request = HTTPClient(method: .GET, uri: URI(string: "http://127.0.0.1:8888"))
            XCTAssertEqual(request.state, SocketState.Ready)
            
            request.write()
            
            request.completion { result in
                if case .End(let res) = result {
                    request.close()
                    XCTAssertEqual(res.headers["Connection"]!, "Close")
                    XCTAssertEqual(res.statusCode, 200)
                    XCTAssertEqual(res.status, Status.OK)
                    XCTAssertGreaterThan(res.body.count, 0)
                    XCTAssertEqual(request.state, SocketState.Closed)
                } else {
                    XCTFail()
                }
                
                server.close()
                Loop.defaultLoop.stop()
                done()
            }

            Loop.defaultLoop.run()
        }
    }

    func testListenWithKeepAlive(){
        waitUntil(5, description: "Listen with KeepAlive") { done in

            let server = SlimaneHTTP.createServer { result in
                if case .Success(_, let res) = result {
                    res.write("Hello!!")
                }
            }

            try! server.bind(Address(host: "127.0.0.1", port: 8889))
            try! server.listen()

            let request = HTTPClient(method: .GET, uri: URI(string: "http://127.0.0.1:8889"))
            XCTAssertEqual(request.state, SocketState.Ready)
            
            request.write()
            
            var responseCounter = 0
            
            request.completion { result in
                responseCounter += 1
                if case .End(let res) = result {
                    XCTAssertEqual(res.statusCode, 200)
                    XCTAssertEqual(res.status, Status.OK)
                    XCTAssertGreaterThan(res.body.count, 0)
                    XCTAssertEqual(request.state, SocketState.Connected)
                }
                
                if responseCounter >= 2 {
                    request.close()
                    server.close()
                    Loop.defaultLoop.stop()
                    done()
                }
            }
            
            // Reuse connection
            let timer = Timer(tick: 1)
            timer.start {
                timer.end()
                request.write()
            }

            Loop.defaultLoop.run()
        }
    }

    func testStreamedResponse(){
        waitUntil(5, description: "Streamed response with transfer encoding: chunked") { done in

            let server = SlimaneHTTP.createServer { result in
                if case .Success(_, let res) = result {
                    res.setHeader("Transfer-Encoding", "Chunked")

                    var counter = 1

                    let timer = Timer(mode: .Interval, tick: 100)

                    res.write("")

                    timer.start {
                        if counter >= 3 {
                            res.end()
                            timer.end()
                        } else {
                            res.write("message\(counter) ")
                        }
                        counter += 1
                    }
                }
            }

            try! server.bind(Address(host: "127.0.0.1", port: 8887))
            try! server.listen()
            
            
            // Client
            let request = HTTPClient(method: .GET, uri: URI(string: "http://127.0.0.1:8887"))
            XCTAssertEqual(request.state, SocketState.Ready)
            
            request.write()
            
            var receive = Buffer()
            
            request.completion { result in
                if case .Data(let buf) = result {
                    receive.append(buf)
                } else if case .End(let resonse) = result {
                    XCTAssertEqual(resonse.statusCode, 200)
                    XCTAssertEqual(resonse.status, Status.OK)
                    XCTAssertEqual(request.state, SocketState.Connected)
                    XCTAssertEqual(receive.toString()!, "message1 message2 ")
                    Loop.defaultLoop.stop()
                    done()
                } else {
                    XCTFail()
                }
            }
            
            Loop.defaultLoop.run()
        }

    }
}
