//import CoreKit
//import Foundation
//
//extension Store.Market.Data.Coin.Info {
//    internal struct Quotes: Codable, Hashable {
//        internal let usd: Quote?
//        internal let eur: Quote?
//        
//        private enum CodingKeys: String, CodingKey {
//            case usd = "2781"
//            case eur = "2790"
//        }
//    }
//}
//extension Store.Market.Data.Coin.Info.Quotes {
//    internal struct Quote: Codable, Hashable {
//        internal let price: Double?
//        internal let x24h: Double?
//        
//        private enum CodingKeys: String, CodingKey {
//            case price
//            case x24h = "percent_change_24h"
//        }
//    }
//}
//extension Store.Market.Data.Coin.Info.Quotes {
//    internal func quote(for fiat: Fiat) -> Quote? {
//        switch fiat {
//        case .usd: return usd
//        case .eur: return eur
//        }
//    }
//}
