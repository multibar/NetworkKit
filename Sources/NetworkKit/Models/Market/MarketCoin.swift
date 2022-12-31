//import CoreKit
//import Foundation
//
//extension Store.Market.Data {
//    internal struct Coin: Codable, Hashable {
//        internal let btc: Info?
//        internal let eth: Info?
//        internal let ton: Info?
//        internal let usdt: Info?
//        
//        internal let usd: Info?
//        internal let eur: Info?
//        
//        private enum CodingKeys: String, CodingKey {
//            case btc  = "1"
//            case eth  = "1027"
//            case ton  = "11419"
//            case usdt = "825"
//            
//            case usd  = "2781"
//            case eur  = "2790"
//        }
//    }
//}
//extension Store.Market.Data.Coin {
//    internal func info(for coin: Coin) -> Info? {
//        switch coin {
//        case .btc : return btc
//        case .eth : return eth
//        case .ton : return ton
//        case .usdt: return usdt
//        }
//    }
//}
