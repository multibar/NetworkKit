import CoreKit
import Foundation
import OrderedCollections

extension Store {
    public struct Section   : Hashable {
        public let id       : UUID
        public let template : Template
        public var header   : Header?
        public var items    : OrderedSet<Store.Item>
        public let footer   : Footer?
        public init(id      : UUID = UUID(),
                    template: Template = .auto,
                    header  : Header? = nil,
                    items   : OrderedSet<Store.Item> = [],
                    footer  : Footer? = nil) {
            self.id         = id
            self.template   = template
            self.header     = header
            self.items      = items
            self.footer     = footer
        }
    }
}
extension Store.Section {
    public enum Template: Hashable {
        case tabs
        case auto
        case settings
    }
}
extension Store.Section {
    public enum Header: Hashable {
        case coin(Coin)
        case title(Title, route: Route? = nil)
        case spacer(height: Double)
        
        public var title: String? {
            switch self {
            case .title(let title, _):
                return title.text
            default:
                return nil
            }
        }
        public var route: Route? {
            switch self {
            case .title(_, let route):
                return route
            case .coin:
                return nil
            case .spacer:
                return nil
            }
        }
        
        public enum Title: Hashable {
            case large(text: String)
            case medium(text: String)
            case small(text: String)
            
            public var text: String {
                switch self {
                case .large(let title):
                    return title
                case .medium(let title):
                    return title
                case .small(let title):
                    return title
                }
            }
        }
    }
}
extension Store.Section {
    public enum Footer: Hashable {
        case spacer(height: Double)
        case button(route: Route)
        case perks(Coin)
        
        public var route: Route? {
            switch self {
            case .spacer:
                return nil
            case .button(let route):
                return route
            case .perks:
                return nil
            }
        }
    }
}
extension Store.Section {
    public static var loader: Store.Section {
        let id = UUID()
        return Store.Section(id: id, items: [Store.Item(section: id, template: .loader)])
    }
    public static var empty: Store.Section {
        let id = UUID()
        return Store.Section(id: id, items: [Store.Item(section: id, template: .loader)])
    }
    public static func spacer(height: Double) -> Store.Section {
        let id = UUID()
        return Store.Section(id: id, items: [Store.Item(section: id, template: .spacer(height))])
    }
}
