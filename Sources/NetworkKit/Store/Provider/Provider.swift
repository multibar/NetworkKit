import CoreKit
import Foundation
import OrderedCollections

internal protocol Provider: AnyObject {
    var id: UUID { get }
    var route: Route { get }
    var order: Store.Order? { get }
    var preloaded: OrderedSet<Store.Section> { get }
    
    func accept(order: Store.Order) async -> AsyncStream<Store.Order>
    func destroy()
}
internal protocol Queryable: Provider {
    var query: Store.Query { get set }
}
extension Provider {
    internal var queryable: Queryable? {
        return self as? Queryable
    }
}

internal class DefaultProvider: Provider {
    internal let id = UUID()
    internal let route: Route
    internal private(set) var order: Store.Order?
    
    internal var preloaded: OrderedSet<Store.Section> { [.loader] }
    
    internal init(route: Route) {
        self.route = route
    }
    
    internal func accept(order: Store.Order) async -> AsyncStream<Store.Order> {
        self.order = order
        switch order.operation {
        case .reload, .store:
            return stream(for: order)
        }
    }
    internal func stream(for order: Store.Order) -> AsyncStream<Store.Order> {
        return AsyncStream {$0.finish()}
    }
    
    internal func destroy() {
        order = nil
    }
}
