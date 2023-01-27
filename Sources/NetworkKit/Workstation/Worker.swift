#if canImport(UIKit)
import UIKit
#endif
import CoreKit
import Foundation

extension Workstation.Worker {
    public enum Work: Hashable {
        case short(request: Network.Request)
        case download(request: Network.Request, session: Workstation.Session)
        case upload(data: Data, request: Network.Request, session: Workstation.Session)
        
        public func hash(into hasher: inout Hasher) {
            hasher.combine(request)
        }
        public var request: Network.Request {
            switch self {
            case .short(let request):
                return request
            case .download(let request, _):
                return request
            case .upload(_, let request, _):
                return request
            }
        }
        public var url: URL? {
            return request.url
        }
    }
}

extension Workstation {
    public class Worker: Hashable {
        public let id: UUID
        public let work: Work
        public let source: URL
        public let leech: (Network.Output) -> Void
        public var leeches: [UUID: (Network.Output) -> Void]
        public let created: Date
        public internal(set) var task: URLSessionTask?
        public internal(set) var progress: Network.Progress {
            didSet {
                #if canImport(UIKit)
                switch progress {
                case .loading:
                    UIApplication.shared.endBackgroundTask(background)
                    background = UIApplication.shared.beginBackgroundTask(expirationHandler: { [weak self] in
                        self?.task?.cancel()
                    })
                case .failed, .finished:
                    UIApplication.shared.endBackgroundTask(background)
                    background = .invalid
                default:
                    break
                }
                #endif
                let output = Network.Output(id: id, progress: progress)
                leeches.values.forEach({$0(output)})
            }
        }
        public var request: Network.Request { work.request }
        
        #if canImport(UIKit)
        private var background = UIBackgroundTaskIdentifier(rawValue: 0)
        #endif
        
        public static func ==(lhs: Worker, rhs: Worker) -> Bool {
            return lhs.id == rhs.id && lhs.source == rhs.source && lhs.work == rhs.work
        }
        public func hash(into hasher: inout Hasher) {
            hasher.combine(id)
            hasher.combine(work)
            hasher.combine(source)
        }
        
        // MARK: - Init
        init(id: UUID,
             work: Work,
             source: URL,
             progress: Network.Progress,
             leech: @escaping (Network.Output) -> Void) {
            self.id = id
            self.work = work
            self.source = source
            self.progress = progress
            self.leech = leech
            self.leeches = [id: leech]
            self.created = Date()
        }
        init(id: UUID,
             work: Work,
             source: URL,
             progress: Network.Progress,
             leech: @escaping (Network.Output) -> Void,
             leeches: [UUID: (Network.Output) -> Void]) {
            self.id = id
            self.work = work
            self.source = source
            self.progress = progress
            self.leech = leech
            self.leeches = leeches
            self.created = Date()
        }
    }
}
