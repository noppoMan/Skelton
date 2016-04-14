import Suv
import SlimaneHTTPServer

func observeWorker(worker: inout Worker){
    worker.send(.Message("message from master"))

    worker.on { event in
        if case .Message(let str) = event {
            print(str)
        }

        else if case .Online = event {
            print("Worker: \(worker.id) is online")
        }

        else if case .Exit(let status) = event {
            print("Worker: \(worker.id) is dead. status: \(status)")
            worker = try! Cluster.fork(silent: false)
            observeWorker(&worker)
        }
    }
}

if Cluster.isMaster {
    for _ in 0..<OS.cpuCount {
        var worker = try! Cluster.fork(silent: false)
        observeWorker(&worker)
    }

    var server = HTTPServer()
    try! server.bind(Address(host: "0.0.0.0", port: 8888))
    try! server.listen()

} else {
    var server = HTTPServer(ipcEnable: true) {
        do {
            let (request, stream) = try $0()
            var res = Response(headers: ["data": Header(Time.rfc1123)])

            if request.isKeepAlive {
                res.headers["connection"] = Header("Keep-Alive")
            } else {
                res.headers["connection"] = Header("Close")
            }

            let content = "Hello! I'm a \(Process.pid)"

            if request.isChunkEncoded {
                stream.send(res.description.data) // Write Head
                stream.send(Response.chunkedEncode(string: content)) // send body
                stream.end() // end stream
            } else {
                res.contentLength = content.characters.count
                stream.send("\(res.description)\(CRLF)\(content)".data)
            }

            if !res.isKeepAlive {
                stream.close()
            } else {
                stream.unref()
            }
        } catch {
            print(error)
        }
    }

    print("listening: \(Process.pid)")
    try! server.listen()
}
