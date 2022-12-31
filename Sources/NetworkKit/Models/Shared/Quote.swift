import CoreKit
import Foundation

extension Array where Element == Coin.Quote {
    ///Returns quote chosen by user, if none — returns first.
    public var preferred: Coin.Quote? {
        return first(where: {$0.fiat == Settings.Network.fiat}) ?? first
    }
}
