import Skelton
import Foundation

func observeWorker(_ worker: Worker){
    worker.send(.message("message from master"))

    worker.onEvent { event in
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
    for _ in 0..<ProcessInfo.cpus().count {
        var worker = try! Cluster.fork(silent: false)
        observeWorker(worker)
    }

    let server = Skelton()
    try! server.bind(host: "0.0.0.0", port: 8888)
    try! server.listen()

} else {
    
    let server = Skelton() { result in
        switch result {
        case .onRequest(let request, let stream):
            ResponseSerializer(stream: stream).serialize(Response(body: "Welecom to Slimane!".data)) { _ in
                stream.close()
            }
        case .onError(let error):
            print(error)
        default:
            break
        }
    }

    print("listening: \(Process.pid)")
    try! server.listen()
}
