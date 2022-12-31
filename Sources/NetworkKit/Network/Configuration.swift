import Foundation

public protocol Configuration {
    var scheme: Network.Scheme       { get }
    var host: String                 { get }
    var port: Int?                   { get }
    var path: String                 { get }
    var parameters: [URLQueryItem]?  { get }
    var method: Network.Method       { get }
    var components: URLComponents    { get }
    var URL: URL?                    { get }
    var key: Network.Api.Key?        { get }
    var token: String?               { get }
    var body: Data?                  { get }
    var cache: Network.Session.Cache { get }
}

extension Network {
    public struct Configuration {
        public let firebase: String?
        public let market: Network.Api.Key?
        
        public init(firebase: String? = nil, market: Api.Key? = nil) {
            self.firebase = firebase
            self.market = market
        }
    }
}
