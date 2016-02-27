# SlimaneHTTP
An asynchronous http server and client powered by [Suv](https://github.com/noppoMan/Suv) in Swift

This is Web Server Layer for [Slimane](https://github.com/noppoMan/slimane.git)

## Features
- [x] HTTP Server(HTTP/1.1)
- [x] HTTP Client(HTTP/1.1)
- [ ] HTTPS Support


## Requirements
* [Suv](https://github.com/noppoMan/Suv)
* [uri-parser](https://github.com/Zewo/uri_parser#installation)
* [http-parser](https://github.com/Zewo/http_parser#installation)

## Installation

##### First You need to install dependeincies for Suv
See [Suv install guid](https://github.com/noppoMan/Suv#installation) to install dependeincies

### Linux

```sh
# Install uri-parser
$ git clone https://github.com/Zewo/uri_parser.git && cd uri_parser
$ make
& make install

# Install http-parser
$ git clone https://github.com/Zewo/http_parser.git && cd http_parser
$ make
$ make install
```

### Mac OS X
```sh
brew tap zewo/tap
brew install http_parser uri_parser
```

## API Reference
Full Api Reference is [here](http://rawgit.com/noppoMan/SlimaneHTTP/master/docs/api/index.html)

## Usage

### HTTP Server

Super easy!

```swift
import SlimaneHTTP

let server = SlimaneHTTP.createServer { result in
    if case .Success(let req, let res) = result {
        print(req.uri)
        res.write("Hello!!")
    } else {
      self.close()
    }
}

try! server.bind(Address(host: "127.0.0.1", port: 8888))
try! server.listen()
```


### HTTP Client
```swift
let request = HTTPClient(method: .GET, uri: URI(string: "127.0.0.1:8888"))

request.write()

request.completion { result in
    if case .Data(let response) = result {
      print(response.body) // Hello!
    }
}
```

## HTTP Server Documentaion

### Streaming

SlimaneHTTP Server Supports `Transfer-Encoding: Chunked` in HTTP/1.1  
Here is Example that respond large data with less memory.

```swift

import SlimaneHTTP
import Suv

let server = SlimaneHTTP.createServer { result in
    if case .Success(_, let res) = result {

        // specify Transfer-Encoding header
        res.setHeader("Transfer-Encoding", "Chunked")

        let fs = FileSystem(path: "/path/to/super-large-file.txt")

        fs.read(.R) {
          if case .Error(let error) = result {

            res.write("\(error)")

          } else if case .Data(let buffer) = result {

            // Write chunk
            res.write(buffer)

          } else {
              fs.close()

              // Write 0\r\n\r\n to close stream.
              res.end()
          }
        }

        res.writeHead() // write head
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
let server = SlimaneHTTP.createServer(...)

server.setNoDelay = true // Enable to use Nagle’s algorithm.

server.listen()
```

### Header Field

You can get/set both of request and response header

```swift
let server = SlimaneHTTP.createServer { result in
    if case .Success(let req, let res) = result {

        // Take header value for key
        req.getHeader("User-Agent")

        // Show all headers
        req.headers

        // Set header field
        res.setHeader("X-Access-Token", Crypto(.SHA256).hashSync("This is token"))

        res.write("{\"id\": 1, \"name\": \"Noppoman\"}")
    }
}
```

### HTTP Status

Use res.status() method to change responding status

```swift
let server = SlimaneHTTP.createServer { result in
    if case .Success(let req, let res) = result {
        res.status(.Created).write("{\"id\": 1, \"name\": \"Noppoman\"}")
    }
}
```

Available Status are [here](https://github.com/Zewo/HTTP/blob/5a3f4181e202ebe811334b3e11bf3886f724cbf6/Sources/Status.swift)


## HTTP Client Documentaion

### Handle basic http request/response

** Currently Streaming request is not supported **


#### Get
```swift
let request = HTTPClient(method: .GET, uri: URI(string: "http://miketokyo.com"))

request.write()

request.completion { result in
    // When server responded chunked content, each data will be catched with .Data
    if case .Data(let response) = result {
      print(response.body) // Hello!

    // When response is end can get response with .End
    } else if .End(let response) = result {

      print(response.status)

      // Can Get body data when the response is not streaming
      print(response.body)

      // Close connection if needed
      // request.close()

    // When connection is closed by server, cat detect with .Close
    } else if .Close = result {

    // Detect error
    } else if .Error(let error) = result {
      print(error)
    }
}
```

#### Post

```swift
let request = HTTPClient(method: .POST, uri: URI(string: "http://miketokyo.com/inquiry"))

request.setheader("Content-Type", "application/json;")

request.write("{\"name\": \"Noppoman\", \"message\": \"When will broadcast the next radio?\"}")

request.completion { result in
    if case .End(let response) = result {
      print(response.status) // 201
    }
}
```

## Package.swift

```swift
import PackageDescription

let package = Package(
    name: "MyApp",
          dependencies: [
              .Package(url: "https://github.com/noppoMan/SlimaneHTTP.git", majorVersion: 0, minor: 1),
          ]
 )
```

## License

(The MIT License)

Copyright (c) 2016 Yuki Takei(Noppoman) yuki@miketokyo.com

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the 'Software'), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and marthis permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
