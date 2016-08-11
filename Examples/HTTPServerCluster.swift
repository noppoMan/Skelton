import Suv
import Time

func observeWorker(_ worker: Worker){
    worker.send(.message("message from master"))

    worker.onIPC { event in
        if case .message(let str) = event {
            print(str)
        }

        else if case .online = event {
            print("Worker: \(worker.id) is online")
        }

        else if case .exit(let status) = event {
            print("Worker: \(worker.id) is dead. status: \(status)")
            let worker = try! Cluster.fork(silent: false)
            observeWorker(worker)
        }
    }
}

if Cluster.isMaster {
    for _ in 0..<OS.cpus().count {
        var worker = try! Cluster.fork(silent: false)
        observeWorker(worker)
    }

    var server = Skelton()
    try! server.bind(host: "0.0.0.0", port: 8888)
    try! server.listen()

} else {
    var server = Skelton(ipcEnable: true) {
        do {
            let (request, stream) = try $0()
            var res = Response(headers: ["Date": Time().rfc1123])

            if !request.isKeepAlive {
                res.headers["Connection"] = "Close"
            }

            let content = "Hello! I'm a \(CommandLine.pid)"

            if request.isChunkEncoded {
                stream.send(res.description.data) // Write Head
                stream.send(chunk: content.data) // send body
                stream.end() // end stream
            } else {
                res.contentLength = content.characters.count
                stream.send("\(res.description)\(CRLF)\(content)".data)
            }

            //if !res.isKeepAlive {
                try! stream.close()
            //}
        } catch {
            print(error)
        }
    }

    print("listening: \(CommandLine.pid)")
    try! server.listen()
}
