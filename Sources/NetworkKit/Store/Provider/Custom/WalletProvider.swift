import CoreKit
import Firebase
import Foundation
import OrderedCollections

internal final class WalletProvider: DefaultProvider {
    internal override func stream(for order: Store.Order) -> AsyncStream<Store.Order> {
        return AsyncStream { stream in
            Task {
                await order.accept()
                stream.yield(order)
                guard let wallet = route.wallet else {
                    await order.attach(.misroute)
                    await order.fail()
                    stream.yield(order)
                    stream.finish()
                    return
                }
                do {
                    switch order.operation {
                    case .reload:
                        async let response = try response(for: wallet)
                        await order.attach(try await response.sections)
                        await order.attach(try await response.listeners)
                        await order.complete()
                    case .rename(let wallet, let title):
                        let wallet = try await rename(wallet, with: title)
                        await order.attach(.wallet(wallet))
                        await order.complete()
                    case .delete(let wallet):
                        try await delete(wallet)
                        await order.complete()
                    default:
                        break
                    }
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
        async let header = try header(for: wallet)
        var sections = try await OrderedSet([header])
        return (sections: sections, listeners: [])
    }
    private func header(for wallet: Wallet) async throws -> Store.Section {
        let id = UUID()
        let section = Store.Section(id: id,
                                    header: .title(.large(text: wallet.title)),
                                    items: [
                                        .spacer(height: 8, section: id), // Will be 16 because LayoutKit adds separators
                                    ])
        return section
    }
}
extension WalletProvider {
    private func rename(_ wallet: Wallet, with title: String) async throws -> Wallet {
        let wallet = wallet.renamed(with: title)
        switch wallet.location {
        case .cloud:
            break
        case .keychain:
            try Keychain.save(wallet)
        }
        return wallet
    }
    private func delete(_ wallet: Wallet) async throws {
        switch wallet.location {
        case .cloud:
            break
        case .keychain:
            try Keychain.delete(wallet)
        }
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
extension Wallet {
    fileprivate func renamed(with title: String) -> Wallet {
        return Wallet(id: id,
                      title: title,
                      coin: coin,
                      phrase: phrase,
                      created: created,
                      location: location)
    }
}
