import Skelton

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

            var response = Response(body: "Hello! I'm a \(CommandLine.pid)".data)

            if !request.isKeepAlive {
                response.headers["Connection"] = "Close"
            }

            ResponseSerializer(stream: stream).serialize(response)
            if !response.isKeepAlive {
                stream.close()
            }
        } catch {
            print(error)
        }
    }

    print("listening: \(CommandLine.pid)")
    try! server.listen()
}
