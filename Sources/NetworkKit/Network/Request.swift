import CoreKit
import Foundation

extension Network {
    public struct Request: Hashable {
        public private(set) var original: URLRequest
        private var _key: Api.Key?
        public let url: URL
        public var method: Network.Method? {
            get {
                guard let value = original.httpMethod else { return nil }
                return Network.Method(rawValue: value)
            }
            set { original.httpMethod = newValue?.rawValue }
        }
        public var body: Data? {
            get { original.httpBody }
            set { original.httpBody = newValue }
        }
        public var client: String? {
            get { original.value(forHTTPHeaderField: "User-Agent") }
            set { original.setValue(newValue, forHTTPHeaderField: "User-Agent") }
        }
        public var key: Api.Key? {
            get { _key }
            set {
                if let header = _key?.header { original.setValue(nil, forHTTPHeaderField: header) }
                _key = key
                guard let value = newValue?.value,
                      let header = newValue?.header
                else { return }
                original.setValue(value, forHTTPHeaderField: header)
            }
        }
        public var token: String? {
            get { original.value(forHTTPHeaderField: "Authorization") }
            set {
                guard let token = newValue else { original.setValue(nil, forHTTPHeaderField: "Authorization"); return }
                original.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
        }
        
        public init?(configuration: NetworkKit.Configuration) {
            guard let url = configuration.URL else { return nil }
            self.original = URLRequest(url: url)
            self.url = url
            self.key = configuration.key
            self.body = configuration.body
            self.token = configuration.token
            self.method = configuration.method
            self.client = System.App.client
        }
        public init?(request: URLRequest) {
            guard let url = request.url else { return nil }
            self.original = request
            self.url = url
        }
    }
}
extension Network.Request {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(original)
        hasher.combine(original.httpBody)
    }
    public static func ==(lhs: Network.Request, rhs: Network.Request) -> Bool {
        return lhs.original == rhs.original && lhs.body == rhs.body
    }
}
extension URLRequest {
    public var modern: Network.Request? {
        return Network.Request(request: self)
    }
}
