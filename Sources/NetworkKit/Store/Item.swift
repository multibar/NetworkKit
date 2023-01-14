import CoreKit
import Foundation

extension Store {
    public struct Item: Hashable {
        public let id       : UUID
        public let section  : UUID
        public let template : Template
        public let group    : Group?
        public init(id      : UUID = UUID(),
                    section : UUID,
                    template: Template,
                    group   : Group? = nil) {
            self.id         = id
            self.section    = section
            self.template   = template
            self.group      = group
        }
    }
}
extension Store.Item {
    public enum Template: Hashable {
        case tab(Tab)
        case add(Coin)
        case quote(coin: Store.Observable<Coin>)
        case wallet(Wallet)
        case phrase(number: Int, last: Bool)
        case text(Text)
        case option(Option)
        case toggle(Toggle)
        case stepper(Stepper)
        case encrypted(String)
        case decrypted([String])
        case footprint
        case button(Button.Action)
        case loader
        case spacer(Double)
    }
}
extension Store.Item {
    public enum Tab: Hashable {
        case add
        case settings
        case coin(Coin)
        
        public var route: Route {
            switch self {
            case .add: return Route(to: .add(.coins))
            case .settings: return Route(to: .settings(.all))
            case .coin(let coin): return Route(to: .wallets(coin))
            }
        }
    }
    public struct Group: Hashable {
        public let title  : String
        public let route  : Route
        public let order  : Int
        public let section: UUID
    }
    public enum Text: Hashable {
        case head  (NSAttributedString)
        case lead  (NSAttributedString)
        case body  (NSAttributedString)
        case quote (NSAttributedString)
        case center(NSAttributedString)
    }
    public enum Option: Hashable {
        case currency
        case passcode
        case biometry
        
        public var route: Route? {
            switch self {
            case .currency, .passcode, .biometry:
                return nil
            }
        }
    }
    public enum Toggle: Hashable {
        case keychain(Keychain.Location)
    }
    public enum Stepper: Hashable {
        case words(Int)
    }
    public struct Button: Hashable {
        public enum Action: Hashable {
            case route(Route)
            case decrypt(Wallet)
            case process(Coin, Wallet.Location)
            
            public var route: Route? {
                switch self {
                case .route(let route):
                    return route
                case .decrypt, .process:
                    return nil
                }
            }
        }
    }
}
extension Store.Item {
    public var route: Route? {
        switch template {
        case .tab(let tab)      : return tab.route
        case .add(let coin)     : return Route(to: .add(.coin(coin)))
        case .wallet(let wallet): return Route(to: .wallet(wallet))
        case .option(let option): return option.route
        case .button(let action): return action.route
        case .encrypted         : return nil
        case .decrypted         : return nil
        case .phrase            : return nil
        case .quote             : return nil
        case .text              : return nil
        case .toggle            : return nil
        case .stepper           : return nil
        case .footprint         : return nil
        case .loader            : return nil
        case .spacer            : return nil
        }
    }
}
extension Store.Item {
    public static func spacer(height: Double, section: UUID = UUID()) -> Store.Item {
        return Store.Item(section: section, template: .spacer(height))
    }
}
