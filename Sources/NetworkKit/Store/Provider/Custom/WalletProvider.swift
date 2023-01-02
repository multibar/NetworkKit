import CoreKit
import Firebase
import Foundation
import OrderedCollections

internal final class WalletProvider: DefaultProvider {
    internal override func stream(for order: Store.Order) -> AsyncStream<Store.Order> {
        return AsyncStream { stream in
            Task {
                await order.accept()
                guard let wallet = route.wallet else {
                    await order.attach(.misroute)
                    await order.fail()
                    stream.yield(order)
                    stream.finish()
                    return
                }
                do {
                    async let response = try response(for: wallet)
                    await order.attach(try await response.sections)
                    await order.attach(try await response.listeners)
                    await order.complete()
                } catch {
                    await order.attach(error)
                }
                stream.yield(order)
                stream.finish()
            }
        }
    }
}
extension WalletProvider {
    private func response(for wallet: Wallet) async throws -> (sections: OrderedSet<Store.Section>, listeners: [Listener]) {
        return (sections: [], listeners: [])
    }
}
extension Route {
    fileprivate var wallet: Wallet? {
        switch destination {
        case .wallet(let wallet):
            return wallet
        default:
            return nil
        }
    }
}
