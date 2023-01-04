import CoreKit

extension Settings.Keys {
    public struct Network {
        private init() {}
    }
}
extension Settings.Keys.Network {
    public struct Fiat {
        private init() {}
    }
}
extension Settings.Keys.Network.Fiat {
    public static let preferred = "settings/keys/network/fiat/preferred"
}
