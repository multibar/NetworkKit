import CoreKit
import Foundation
import OrderedCollections

fileprivate let workqueue = DispatchQueue(label: "com.workstation.queue", qos: .utility, attributes: .concurrent)

public protocol WorkstationListener: AnyObject {
    func updated(workers: [Workstation.Worker])
    func queued(workers: [Workstation.Worker])
}

extension Workstation {
    public class Context {
        public private(set) var workers: OrderedSet<Worker> = [] {
            didSet { listener?.updated(workers: workers.elements) }
        }
        public private(set) var queue: [Worker] = [] {
            didSet { listener?.queued(workers: queue) }
        }
        private var data: [Network.Request: Data] = [:]
        
        fileprivate weak var listener: WorkstationListener?
        
        private let lock = NSLock()
        
        public func workers(with request: Network.Request) -> [Worker] {
            return workers.filter({$0.request == request})
        }
        public func add(worker: Worker, enqueue: Bool) -> Bool {
            lock.lock(); defer { lock.unlock() }
            let coworkers = workers(with: worker.request)
            let allowed = coworkers.empty
            let identified = workers.first(where: {$0.id == worker.id})
            if enqueue && allowed && identified != nil {
                queue.append(worker)
                worker.progress = .queued
                return false
            }
            worker.task = coworkers.first(where: {$0.task != nil})?.task
            workers.updateOrAppend(worker)
            return allowed
        }
        public func remove(worker: Worker) {
            lock.lock(); defer { lock.unlock() }
            workers.remove(worker)
            guard workers(with: worker.request).empty else { return }
            data.removeValue(forKey: worker.request)
        }
        public func remove(with request: Network.Request) {
            lock.lock(); defer { lock.unlock() }
            workers.removeAll(where: {$0.request == request})
            data.removeValue(forKey: request)
        }
        public func dequeue(with request: Network.Request) {
            lock.lock(); defer { lock.unlock() }
            queue.removeAll(where: {$0.request == request})
        }
        public func data(at request: Network.Request) -> Data? {
            lock.lock(); defer { lock.unlock() }
            return data[request]
        }
        public func add(data: Data, to request: Network.Request) {
            lock.lock(); defer { lock.unlock() }
            var current = self.data[request] ?? Data()
            current.append(contentsOf: data)
            self.data[request] = current
        }
    }
}

public class Workstation: NSObject {
    private let identifier = "com.network.background"
    private var sessions: Sessions!
        
    private let context = Context()
    
    public var backgroundCompletion: (() -> Void)?
    
    public var workers: [Worker] { context.workers.elements }
    public var queue: [Worker] { context.queue }
    
    public var listener: WorkstationListener? {
        get { context.listener }
        set { context.listener = newValue }
    }

    public static let shared = Workstation()

    private override init() {
        super.init()
        sessions = Sessions(foreground: Network.Session.foreground(cache: .none, delegate: self).session,
                            background: Network.Session.background(delegate: self, identifier: identifier).session)
    }
    
    public static func get<T: Decodable>(object type: T.Type,
                                         with configuration: Configuration,
                                         id: UUID = UUID(),
                                         enqueue: Bool = false,
                                         progress: @escaping (Double) -> Void = {_ in},
                                         completion: @escaping (Result<T, Network.Failure>) -> Void) {
        workqueue.async {
            guard let request = Network.Request(configuration: configuration) else {
                completion(.failure(.url))
                return
            }
            Workstation.shared.perform(work: .short(request: request), id: id, enqueue: enqueue) { output in
                switch output.progress {
                case .uploading(let percent):
//                    log(event: "Worker uploading — \(percent*100)%", source: .network)
                    progress(percent)
                case .downloading(let percent):
//                    log(event: "Worker downloading — \(percent*100)%", source: .network)
                    progress(percent)
                case .loading:
                    var message = "Started — \(configuration.method.rawValue): \(request.url.string)"
                    if let data = configuration.body, let json = String(data: data, encoding: .utf8) {
                        message.append(contentsOf: ", parameters: \(json.replacingOccurrences(of: "\\", with: ""))")
                    }
                    log(event: message, source: .network)
                    progress(0)
                case .finished(let result):
                    guard let data = result.data else {
                        log(event: "Failed — \(configuration.method.rawValue): \(request.url.string), failure: data", source: .network)
                        completion(.failure(.data("Failed to extract data in Workstation for url: \(request.url.string)")))
                        return
                    }
                    do {
                        var message = "Finished — \(configuration.method.rawValue): \(request.url.string)"
                        if let json = String(data: data, encoding: .utf8) {
                            message.append(contentsOf: ", response: \(json.replacingOccurrences(of: "\\", with: ""))")
                        }
                        let response = try JSONDecoder().decode(T.self, from: data)
                        log(event: message, source: .network)
                        completion(.success(response))
                    } catch {
                        log(event: "Failed to decode — \(configuration.method.rawValue): \(request.url.string),\nerror: \(error)", source: .network)
                        completion(.failure(.decode(error)))
                    }
                case .failed(let failure):
                    switch failure {
                    case .cancelled:
                        log(event: "Cancelled — \(configuration.method.rawValue): \(request.url.string)", source: .network)
                        break
                    default:
                        log(event: "Failed — \(configuration.method.rawValue): \(request.url.string), failure: \(failure)", source: .network)
                        completion(.failure(failure))
                    }
                default:
                    log(event: "Worker \(output.progress)", source: .network)
                }
            }
        }
    }
    
    public func perform(work: Worker.Work,
                        id: UUID,
                        enqueue: Bool = false,
                        progress: @escaping (Network.Output) -> Void) {
        workqueue.async {
            guard let url = work.url else {
                progress(Network.Output(id: id, progress: .failed(error: .url)))
                return
            }
            let worker = Worker(id: id, work: work, source: url, progress: .loading, leech: progress)
            guard self.context.add(worker: worker, enqueue: enqueue) else { return }
            worker.progress = .loading
            switch work {
            case .short(let request):
                worker.task = self.sessions.foreground.dataTask(with: request.original)
            case .download(let request, let session):
                worker.task = self.sessions.session(for: session).downloadTask(with: request.original)
            case .upload(let data, let request, let session):
                worker.task = self.sessions.session(for: session).uploadTask(with: request.original, from: data)
            }
            worker.task?.resume()
        }
    }
    
    public func toggle(worker: Worker, completion: @escaping (Network.Progress) -> Void) {
        guard let task = worker.task else {
            completion(worker.progress)
            return
        }
        switch worker.progress {
        case .paused:
            task.resume()
            worker.progress = .downloading(progress: task.progress.fractionCompleted)
        case .downloading:
            task.suspend()
            worker.progress = .paused
        default: break
        }
        completion(worker.progress)
    }
    
    public func cancel(worker: Worker) {
        context.remove(worker: worker)
        worker.task?.cancel()
        worker.progress = .failed(error: .cancelled)
        push(queued: worker.id)
    }
    
    private func push(queued id: UUID) {
        guard let queued = context.queue.first(where: {$0.id == id}) else { return }
        context.dequeue(with: queued.request)
        perform(work: queued.work, id: queued.id, enqueue: false, progress: queued.leech)
    }
    
    deinit {
        sessions.all.forEach({$0.invalidateAndCancel()})
    }
}

extension Workstation: URLSessionDataDelegate {
    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard let request = dataTask.originalRequest?.modern, !context.workers(with: request).empty else { return }
        context.add(data: data, to: request)
    }
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let request = task.originalRequest?.modern else { return }
        let data = context.data(at: request)
        let workers = context.workers(with: request)
        workqueue.async {
            for worker in workers {
                switch worker.work {
                case .short:
                    if let error = error {
                        worker.progress = .failed(error: .unknown(error))
                    } else if let data = data {
                        worker.progress = .finished(result: .data(data))
                    }
                default:
                    guard let error = error else { continue }
                    workers.forEach{$0.progress = .failed(error: (error as NSError).code == 28 ? .space : .unknown(error))}
                }
                self.push(queued: worker.id)
            }
            self.context.remove(with: request)
        }
    }
}
extension Workstation: URLSessionDownloadDelegate {
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let request = downloadTask.originalRequest?.modern else { return }
        let workers = context.workers(with: request)
        workers.forEach({push(queued: $0.id)})
        context.remove(with: request)
        workers.forEach({$0.progress = .finished(result: .file(location))})
    }
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didResumeAtOffset fileOffset: Int64, expectedTotalBytes: Int64) {
        guard let request = downloadTask.originalRequest?.modern else { return }
        workqueue.async {
            self.context.workers(with: request).forEach{$0.progress = .downloading(progress: downloadTask.progress.fractionCompleted)}
        }
    }
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard let request = downloadTask.originalRequest?.modern else { return }
        workqueue.async {
            self.context.workers(with: request).forEach{$0.progress = .downloading(progress: downloadTask.progress.fractionCompleted)}
        }
    }
    public func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        guard let request = task.originalRequest?.modern else { return }
        workqueue.async {
            self.context.workers(with: request).forEach{$0.progress = .uploading(progress: task.progress.fractionCompleted)}
        }
    }
    public func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        backgroundCompletion?()
        backgroundCompletion = nil
    }
}
