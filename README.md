# Skelton
An asynchronous http server for Swift

This is Web Server Layer for [Slimane](https://github.com/slimane-swift/slimane.git)

## Usage

Super easy!

```swift
import Skelton

let server = Skelton { getLoad in
    let (request, stream) = try! getLoad()

    let response = Response(data: "\(response.description)\r\nHello!".data)

    ResponseSerializer(stream: stream).serialize(response) { _ in
        stream.close()
    }
}

try! server.bind(host: "127.0.0.1", port: 8888)
try! server.listen()
```


## Documention

### Request, Response
https://github.com/slimane-swift/HTTPCore

We are using HTTPCore.Request and HTTPCore.Response

### Streaming

Skelton Server Supports `Transfer-Encoding: Chunked` in HTTP/1.1  
Here is Example that respond large data with less memory.

```swift
import Skelton

var server = Skelton() {
    do {
        let (request, stream) = try $0()

        let bodyStream: (WritableStream, @escaping ((Void) throws -> Void) -> Void) -> Void = { stream, completion in
            stream.write("aaaa".data) // this is stream writer for chunk
            completion {
                stream.close()
            }
        }

        ResponseSerializer(stream: stream).serialize(Response(body: bodyStream))

    } catch {
        print(error)
    }
}

try! server.bind(host: "127.0.0.1", port: 8888)
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
See the [Sources/Performance/main.swift](https://github.com/slimane-swift/Skelton/blob/master/Sources/Performance/main.swift)

## Package.swift

```swift
import PackageDescription

let package = Package(
    name: "MyApp",
    dependencies: [
        .Package(url: "https://github.com/noppoMan/Skelton.git", majorVersion: 0, minor: 9),
    ]
 )
```

## License

Skelton is released under the MIT license. See LICENSE for details.
