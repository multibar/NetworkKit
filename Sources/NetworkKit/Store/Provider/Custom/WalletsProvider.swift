import CoreKit
import Firebase
import Foundation
import OrderedCollections

internal final class WalletsProvider: DefaultProvider {
    internal override func stream(for order: Store.Order) -> AsyncStream<Store.Order> {
        return AsyncStream { stream in
            Task {
                await order.accept()
                guard let empty = route.coin else {
                    await order.attach(.misroute)
                    await order.fail()
                    stream.yield(order)
                    stream.finish()
                    return
                }
                do {
                    async let coin = try get(coin: empty)
                    await order.attach(try await coin.section)
                    await order.attach(try await coin.listener)
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
    private func get(coin: Coin) async throws -> (section: Store.Section, listener: Listener) {
        let response = try await Store.observe(coin: coin)
        let id = UUID()
        let section = Store.Section(id: id,
                                    header: .title(.large(text: response.coin.info.title)),
                                    items: [
                                        .spacer(height: 8, section: id), // Will be 16 because LayoutKit adds separators
                                        Store.Item(section: id, template: .quote(coin: response.observable))
                                    ])
        return (section: section, listener: response.listener)
    }
}
extension Route {
    public var coin: Coin? {
        switch destination {
        case .add(let stage):
            switch stage {
            case .coin(let coin):
                return coin
            default:
                return nil
            }
        case .wallets(let coin):
            return coin
        default:
            return nil
        }
    }
}
