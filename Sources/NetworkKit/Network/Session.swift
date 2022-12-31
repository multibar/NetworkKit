import CoreKit
import Foundation

extension Network {
    public enum Session {
        case foreground(cache: Cache, delegate: URLSessionDelegate? = nil)
        case background(delegate: URLSessionDelegate, identifier: String)
        
        public var session: URLSession {
            let headers = Network.Session.headers
            switch self {
            case .foreground(let cache, let delegate):
                switch cache {
                case .ram:
                    let configuration: URLSessionConfiguration = .ephemeral
                    configuration.httpAdditionalHeaders = headers
                    return URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
                case .disk:
                    let configuration: URLSessionConfiguration = .default
                    configuration.httpAdditionalHeaders = headers
                    return URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
                case .none:
                    let configuration: URLSessionConfiguration = .ephemeral
                    configuration.httpAdditionalHeaders = headers
                    configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
                    configuration.urlCache = nil
                    return URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
                }
            case .background(let delegate, let identifier):
                let configuration: URLSessionConfiguration = .background(withIdentifier: identifier)
                configuration.httpAdditionalHeaders = headers
                configuration.sessionSendsLaunchEvents = true
                return URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
            }
        }
        
        internal static let headers: [String: String] = {
            let acceptEncoding: String = "gzip;q=1.0, compress;q=0.5"
            let acceptLanguage = Locale.preferredLanguages.prefix(6).enumerated().map { index, languageCode in
                let quality = 1.0 - (Double(index) * 0.1)
                return "\(languageCode);q=\(quality)"
            }.joined(separator: ", ")
            return [
                "Accept-Encoding": acceptEncoding,
                "Accept-Language": acceptLanguage,
                "User-Agent": System.App.client
            ]
        }()
    }
}
extension Network.Session {
    public enum Cache {
        case ram
        case disk
        case none
    }
}
extension Network.Session {
    internal struct Sessions {
        internal let ram : URLSession
        internal let disk: URLSession
        internal let none: URLSession
        
        internal init() {
            self.ram  = Network.Session.foreground(cache: .ram).session
            self.disk = Network.Session.foreground(cache: .disk).session
            self.none = Network.Session.foreground(cache: .none).session
        }
        internal var all: [URLSession] {
            return [ram, disk, none]
        }
        internal func session(for cache: Network.Session.Cache) -> URLSession {
            switch cache {
            case .ram : return ram
            case .disk: return disk
            case .none: return none
            }
        }
        internal enum Session {
            case `default`
            case ephemeral
        }
    }
}
