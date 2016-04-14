# SlimaneHTTP
An asynchronous http server for Swift that adopts open-swift

This is Web Server Layer for [Slimane](https://github.com/noppoMan/slimane.git)

## Usage

Super easy!

```swift
import SlimaneHTTPServer

let server = HTTPServer { result in
    let (request, stream) = try! $0()
    var res = Response(headers: [
      "data": Header(Time.rfc1123)
    ])

    stream.send("\(res.description)\r\nHello!".data)
    stream.close()
}

try! server.bind(Address(host: "127.0.0.1", port: 8888))
try! server.listen()
```


## Documention

### Request, Response
https://github.com/open-swift/S4

We are using S4.Request and S4.Response

### Streaming

SlimaneHTTP Server Supports `Transfer-Encoding: Chunked` in HTTP/1.1  
Here is Example that respond large data with less memory.

```swift
import SlimaneHTTPServer

var server = HTTPServer() {
    do {
        let (request, stream) = try $0()
        var res = Response(headers: [
          "data": Header(Time.rfc1123),
          "transfer-encoding": HeaderValues("Chunked"),
          "connection": Header("Keep-Alive")
        ])

        stream.send(res.description.data) // Write Head
        stream.send(Response.chunkedEncode(string: "aaaa")) // Write body
        stream.end() // Write end
        stream.unref() // unref counter
    } catch {
        print(error)
    }
}

try! server.bind(Address(host: "127.0.0.1", port: 3000))
try! server.listen()
```

### Keep-Alive
SlimaneHTTP supports Keep-Alive connection. Default Keep-Alive Timeout sec is 75. 0 is disable keep-alive.  
You can change keep alive timeout sec to assign unsigned numner to `server.keepAliveTimout` member variable.

```swift
server.keepAliveTimout = 120 // 2 min
```

### Nodelay(Nagle’s algorithm.)

```swift
let server = HTTPServer(...)

server.setNoDelay = true // Enable to use Nagle’s algorithm.

server.listen()
```

### HTTP Status

```swift
let response = Response(status: .created)
```


### Working With Cluster
See the [Examples/HTTPServerCluster.swift](https://github.com/noppoMan/SlimaneHTTPServer/blob/master/Examples/HTTPServerCluster.swift)

## More!
SlimaneHTTPServer adpots [open-swift](https://github.com/open-swift)

For more detail, plz visit [Docs for open-swift](https://github.com/open-swift/docs)

## Package.swift

```swift
import PackageDescription

let package = Package(
    name: "MyApp",
    dependencies: [
        .Package(url: "https://github.com/noppoMan/SlimaneHTTPServer.git", majorVersion: 0, minor: 1),
    ]
 )
```

## License

(The MIT License)

Copyright (c) 2016 Yuki Takei(Noppoman) yuki@miketokyo.com

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the 'Software'), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and marthis permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
