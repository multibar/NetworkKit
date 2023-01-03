import CoreKit
import Foundation
import OrderedCollections

public protocol Customer: AnyObject {
    func receive(order: Store.Order, from store: Store) async
}

public final class Store: Provider {
    public let id = UUID()
    private var provider: Provider
    private weak var customer: Customer?

    public private(set) var route: Route
    public private(set) var query: Query
    public private(set) var lifetime: Core.Date = .now
        
    public var order: Store.Order? {
        return provider.order
    }
    public var preloaded: OrderedSet<Store.Section> {
        return provider.preloaded
    }
    
    public var loading: Bool {
        get async {
            switch await order?.status {
            case .created, .accepted:
                return true
            default:
                return false
            }
        }
    }
    
    public required init(route: Route, query: Store.Query = .none) {
        self.provider = Store.provider(for: route, query: query)
        self.route = route
        self.query = query
    }
    public func set(route: Route, query: Query = .none, load: Bool = true) {
        guard self.route != route && self.provider.route != route else { return }
        self.provider = Store.provider(for: route, query: query)
        self.route = route
        self.query = query
        guard load else { return }
        order(.reload)
    }
    public func set(query: Query, load: Bool = true) {
        self.query = query
        self.provider.queryable?.query = query
        guard load else { return }
        order(.reload)
    }
    public func set(customer: Customer, load: Bool = true) {
        self.customer = customer
        guard load else { return }
        order(.reload)
    }
    
    public func order(_ operation: Store.Order.Operation) {
        Task {
            revive()                                                                /// Updating store lifetime.
            if operation.cancellable { await order?.cancel() }                      /// Only cancellable operation can cancel previous cancellable order.
            for try await order in await accept(order: order(for: operation)) {     /// Iterating through stream.
                if order.provider != provider.id { return }                         /// Check if provider has changed while order was being executed.
                if await order.status == .cancelled { return }                      /// WIP: Don't stream cancelled order to customer.
                if await order.status == .failed && order.cancellable { expire() }  /// Expire store if order cancellable order failed, so that customer can expect reload on next check.
                await customer?.receive(order: order, from: self)                   /// Stream order to customer.
            }
        }
    }
    public func retry(_ order: Store.Order) {
        self.order(order.operation)
    }
    
    internal func accept(order: Store.Order) async -> AsyncStream<Store.Order> {
        return await provider.accept(order: order)
    }
    internal func destroy() {
        provider.destroy()
    }
    deinit {
        destroy()
    }
}

extension Store {
    private static func provider(for route: Route, query: Store.Query) -> Provider {
        switch route.destination {
        case .add:
            return AddProvider(route: route)
        case .wallet:
            return WalletProvider(route: route)
        case .wallets:
            return WalletsProvider(route: route)
        case .multibar:
            return MultibarProvider(route: route)
        default:
            return DefaultProvider(route: route)
        }
    }
}
extension Store {
    private func order(for operation: Store.Order.Operation) -> Store.Order {
        return Order(provider: provider.id, operation: operation, route: route)
    }
}
extension Store {
    public var expired: Bool {
        return lifetime.expired
    }
    public func expire() {
        lifetime = .now
    }
    public func updateIfNeeded() {
        guard expired else { return }
        order(.reload)
    }
    private func revive() {
        switch route.destination {
        case .wallets:
            lifetime = .minutes(10)
        default:
            lifetime = .hours(1)
        }
    }
}
extension Store: WorkstationListener {
    public func updated(workers: [Workstation.Worker]) {}
    public func queued(workers: [Workstation.Worker]) {}
}
