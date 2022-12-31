import CoreKit
import Foundation

extension Settings {
    public struct Network {
        public static var test: Bool {
            get {
                return Settings.get(value: Bool.self, for: Settings.Keys.Network.test) ?? false
            } set {
                Settings.set(value: newValue, for: Settings.Keys.Network.test)
            }
        }
        public static var fiat: Fiat? {
            get {
                guard let data = Settings.get(value: Data.self, for: Settings.Keys.Network.fiat),
                      let fiat = try? JSONDecoder().decode(Fiat.self, from: data) else { return nil }
                return fiat
            } set {
                Settings.set(value: try? JSONEncoder().encode(newValue), for: Settings.Keys.Network.fiat)
            }
        }
    }
}
