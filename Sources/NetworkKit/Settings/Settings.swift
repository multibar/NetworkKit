import CoreKit

extension Settings {
    public struct Network {
        private init() {}
    }
}
extension Settings.Network {
    public struct Fiat {
        private init() {}
    }
}
extension Settings.Network.Fiat {
    public static var preferred: String {
        get { Settings.get(value: String.self, for: Settings.Keys.Network.Fiat.preferred) ?? "USD" }
        set { Settings.set(value: newValue, for: Settings.Keys.Network.Fiat.preferred) }
    }
}
