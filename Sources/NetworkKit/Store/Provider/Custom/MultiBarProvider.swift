import CoreKit
import Foundation
import OrderedCollections

internal final class MultibarProvider: DefaultProvider {
    internal override var preloaded: OrderedSet<Store.Section> {[]}
    internal override func stream(for order: Store.Order) -> AsyncStream<Store.Order> {
        return AsyncStream { stream in
            Task {
                await order.accept()
                do {
                    async let coins = try get()
                    await order.attach(try await coins)
                    await order.complete()
                } catch {
                    await order.attach(error)
                    await order.fail()
                }
                stream.yield(order)
                stream.finish()
            }
        }
    }
}
extension MultibarProvider {
    private func get(coins query: Store.Query = .none) async throws -> Store.Section {
        let coins = try await Store.get(coins: query)
        let id = UUID()
        var items = OrderedSet(coins.compactMap({Store.Item(section: id, template: .tab(.coin($0)))}))
        items.append(Store.Item(section: id, template: .tab(.add)))
        let section = Store.Section(id: id,
                                    template: .tabs,
                                    items: items,
                                    footer: .spacer(height: 32))
        return section
    }
}
