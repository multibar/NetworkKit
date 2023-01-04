import CoreKit
import Foundation

extension Network {
    public struct Market {
        public enum Configuration: NetworkKit.Configuration {
            case info(coin: Coin)
            case quote(coin: Coin, fiat: Fiat)
            
            public var scheme: Network.Scheme {
                return .https
            }
            public var host: String {
                return "pro-api.coinmarketcap.com"
            }
            public var port: Int? {
                return nil
            }
            public var path: String {
                switch self {
                case .info:
                    return "/v2/cryptocurrency/info"
                case .quote:
                    return "/v2/cryptocurrency/quotes/latest"
                }
            }
            public var parameters: [URLQueryItem]? {
                var items: [URLQueryItem] = []
                switch self {
                case .info(let coin):
                    items.append(URLQueryItem(name: "id", value: coin.id.cmc.string))
                case .quote(let coin, let fiat):
                    items.append(URLQueryItem(name: "id", value: coin.id.cmc.string))
                    items.append(URLQueryItem(name: "convert_id", value: fiat.id.cmc.string))
                }
                return items.empty ? nil : items
            }
            public var method: Network.Method {
                switch self {
                case .info, .quote:
                    return .get
                }
            }
            public var components: URLComponents {
                var components = URLComponents()
                components.scheme = scheme.rawValue
                components.host = host
                components.path = path
                components.queryItems = parameters
                return components
            }
            public var URL: URL? {
                return components.url
            }
            public var key: Network.Api.Key? {
                return Network.shared.configuration?.market
            }
            public var token: String? {
                return nil
            }
            public var body: Data? {
                return nil
            }
            public var cache: Network.Session.Cache {
                return .none
            }
        }
    }
}
extension Store {
    internal struct Market {}
}
