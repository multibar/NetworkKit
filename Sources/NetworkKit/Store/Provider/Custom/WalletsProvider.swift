import CoreKit
import Firebase
import Foundation
import OrderedCollections

internal final class WalletsProvider: DefaultProvider {
    internal override func stream(for order: Store.Order) -> AsyncStream<Store.Order> {
        return AsyncStream { stream in
            Task {
                await order.accept()
                guard let coin = route.coin else {
                    await order.attach(.misroute)
                    await order.fail()
                    stream.yield(order)
                    stream.finish()
                    return
                }
                do {
                    async let response = try response(for: coin)
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
extension WalletsProvider {
    private func response(for coin: Coin) async throws -> (sections: OrderedSet<Store.Section>, listeners: [Listener]) {
        async let header = try header(for: coin)
        async let wallets = try wallets(for: coin)
        var sections = try await OrderedSet([header.section])
        sections.append(contentsOf: try await wallets)
        return (sections: sections, listeners: [try await header.listener])
    }
    private func header(for coin: Coin) async throws -> (section: Store.Section, listener: Listener) {
        let response = try await Store.observe(coin)
        let id = UUID()
        let section = Store.Section(id: id,
                                    header: .title(.large(text: coin.info.title)),
                                    items: [
                                        .spacer(height: 8, section: id), // Will be 16 because LayoutKit adds separators
                                        Store.Item(section: id, template: .quote(coin: response.observable))
                                    ])
        return (section: section, listener: response.listener)
    }
    private func wallets(for coin: Coin) async throws -> OrderedSet<Store.Section> {
        let wallets = Keychain.wallets().filter({$0.coin == coin.code})
        var sections: OrderedSet<Store.Section> = []
        wallets.forEach { wallet in
            let section = UUID()
            sections.append(Store.Section(id: section,
                                          header: .spacer(height: 8),
                                          items: [Store.Item(section: section, template: .wallet(wallet))]))
        }
        return sections
    }
}
extension Route {
    fileprivate var coin: Coin? {
        switch destination {
        case .wallets(let coin):
            return coin
        default:
            return nil
        }
    }
}
