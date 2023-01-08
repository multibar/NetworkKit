import CoreKit
import Foundation
import OrderedCollections

extension Store {
    public actor Order: Hashable, Equatable {
        public nonisolated let id = UUID()
        public nonisolated let provider: UUID
        public nonisolated let operation: Operation
        public nonisolated let route: Route
        public nonisolated let created: Time = .now
        public private(set) var status: Status = .created
        public private(set) var package: Package = .empty
        public private(set) var sections: OrderedSet<Store.Section> = []
        public private(set) var failures: OrderedSet<Network.Failure> = []
        internal private(set) var listeners: [Listener] = []
                
        internal init(provider: UUID, operation: Operation, route: Route) {
            self.provider = provider
            self.operation = operation
            self.route = route
        }
        
        public nonisolated func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
        public static func == (lhs: Order, rhs: Order) -> Bool {
            return lhs.id == rhs.id
        }
        
        private func destroy() {
            sections.removeAll()
            failures.removeAll()
            listeners.destroy()
        }
        deinit {
            listeners.destroy()
        }
    }
}
extension Store.Order {
    internal func accept() {
        switch status {
        case .created:
            status = .accepted
        default:
            return
        }
    }
    internal func complete() {
        switch status {
        case .created, .accepted:
            status = .completed
        default:
            return
        }
    }
    internal func cancel() {
        guard operation.cancellable else { return }
        switch status {
        case .created, .accepted:
            status = .cancelled
            destroy()
        default:
            return
        }
    }
    internal func fail() {
        switch status {
        case .created, .accepted:
            status = .failed
            destroy()
        default:
            return
        }
    }
    internal func attach(_ package: Package) {
        guard status == .created || status == .accepted else { return }
        self.package = package
    }
    internal func attach(_ section: Store.Section) {
        guard status == .created || status == .accepted else { return }
        self.sections.append(section)
    }
    internal func attach(_ sections: OrderedSet<Store.Section>) {
        guard status == .created || status == .accepted else { return }
        self.sections.append(contentsOf: sections)
    }
    internal func attach(_ listener: Listener) {
        guard status == .created || status == .accepted else { return }
        self.listeners.append(listener)
    }
    internal func attach(_ listeners: [Listener]) {
        guard status == .created || status == .accepted else { return }
        self.listeners.append(contentsOf: listeners)
    }
    internal func attach(_ error: Error) {
        guard status == .created || status == .accepted else { return }
        self.failures.append(error as? Network.Failure ?? .unknown(error))
    }
    internal func attach(_ failure: Network.Failure) {
        guard status == .created || status == .accepted else { return }
        self.failures.append(failure)
    }
    internal func attach(_ failures: [Network.Failure]) {
        guard status == .created || status == .accepted else { return }
        self.failures.append(contentsOf: failures)
    }
    internal func detach(_ section: Store.Section) {
        self.sections.remove(section)
    }
    internal func detach(_ failure: Network.Failure) {
        self.failures.remove(failure)
    }
}
extension Store.Order {
    public enum Operation: Hashable, Equatable {
        case reload
        case store(phrases: [String], coin: Coin, location: Wallet.Location, key: String)
        case rename(wallet: Wallet, with: String)
        case delete(wallet: Wallet)
        case decrypt(wallet: Wallet, with: String? = nil)
        
        public var cancellable: Bool {
            self == .reload
        }
    }
    public enum Package: Hashable, Equatable {
        case empty
        case wallet(Wallet)
        
        public var wallet: Wallet? {
            switch self {
            case .empty:
                return nil
            case .wallet(let wallet):
                return wallet
            }
        }
    }
    public enum Status: Hashable, Equatable {
        case created
        case accepted
        case completed
        case cancelled
        case failed
    }
}
extension Store.Order {
    public nonisolated var cancellable: Bool {
        return operation.cancellable
    }
    public nonisolated var instantaneous: Bool {
        return Time.now.seconds - created.seconds < 0.1
    }
}
extension OrderedSet where Element == Store.Order {
    public func cancel() async {
        forEach { order in
            Task { await order.cancel() }
        }
    }
}
