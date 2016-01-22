//
//  SlimaneHTTP.swift
//  SlimaneHTTP
//
//  Created by Yuki Takei on 1/11/16.
//  Copyright © 2016 MikeTOKYO. All rights reserved.
//

import Suv

/**
 SlimaneHTTP Type
*/
public class SlimaneHTTP {
   /**
    Alias type of HTTPClient
   */
   public typealias Client = HTTPClient

   /**
    For creating server. this is similar with node.js's http.createServer()


    ## Usage
    ```swift
    import SlimaneHTTP

    let server = SlimaneHTTP { req, res in
       print(req.uri.path)

       res.write("OK")
    }

    try! server.bind(Address(host: "127.0.0.1", port: 8887))
    try! server.listen()

    Loop.defaultLoop.run()
    ```


    - parameter loop: Event loop
    - parameter onConnection: Connection handler
   */
   public static func createServer(loop: Loop = Loop.defaultLoop, onConnection: HTTPConnectionResult -> () = {_ in}) -> HTTPServer {
       return HTTPServer(loop: Loop.defaultLoop, ipcEnable: Cluster.isWorker, onConnection: onConnection)
   }
}
