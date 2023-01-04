import CoreKit
import Foundation

extension Array where Element == Coin.Quote {
    ///Returns quote preferred by user, if none — returns first.
    public var preferred: Coin.Quote? {
        return first(where: {$0.fiat.code == Settings.Network.Fiat.preferred}) ?? first
    }
}
