# Skelton
An asynchronous http server for Swift that adopts open-swift

This is Web Server Layer for [Slimane](https://github.com/slimane-swift/slimane.git)

## Usage

Super easy!

```swift
import Skelton

let server = Skelton { getLoad in
    let (request, stream) = try! getLoad()
    var res = Response(headers: [
      "Date": Time.rfc1123
    ])

    stream.send("\(res.description)\r\nHello!".data)
    try! stream.close()
}

try! server.bind(host: "127.0.0.1", port: 8888)
try! server.listen()
```


## Documention

### Request, Response
https://github.com/open-swift/S4

We are using S4.Request and S4.Response

### Streaming

Skelton Server Supports `Transfer-Encoding: Chunked` in HTTP/1.1  
Here is Example that respond large data with less memory.

```swift
import Skelton

var server = Skelton() {
    do {
        let (request, stream) = try $0()
        var res = Response(headers: [
          "Date": Time.rfc1123,
          "Transfer-encoding": "Chunked",
          "Connection": "Keep-Alive"
        ])

        stream.send(res.description.data) // Write Head
        stream.send(chunk: "aaaa".data) // Write body
        stream.end() // Write end
    } catch {
        print(error)
    }
}

try! server.bind(host: "127.0.0.1", port: 3000)
try! server.listen()
```

### Keep-Alive
Skelton supports Keep-Alive connection. Default Keep-Alive Timeout sec is 75. 0 is disable keep-alive.  
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
See the [Examples/HTTPServerCluster.swift](https://github.com/slimane-swift/Skelton/blob/master/Examples/HTTPServerCluster.swift)

## More!
Skelton adpots [open-swift](https://github.com/open-swift)

For more detail, plz visit [Docs for open-swift](https://github.com/open-swift/docs)

## Package.swift

```swift
import PackageDescription

let package = Package(
    name: "MyApp",
    dependencies: [
        .Package(url: "https://github.com/noppoMan/Skelton.git", majorVersion: 0, minor: 8),
    ]
 )
```

## License

Skelton is released under the MIT license. See LICENSE for details.
