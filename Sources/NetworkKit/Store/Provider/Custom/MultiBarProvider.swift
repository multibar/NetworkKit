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
                    async let tabs = try tabs()
                    await order.attach(try await tabs)
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
    private func tabs() async throws -> Store.Section {
        var codes = OrderedSet(Keychain.wallets().compactMap({$0.coin}))
        if codes.empty { codes = ["TON"] }
        let id = UUID()
        var items: OrderedSet<Store.Item> = try await OrderedSet(codes.asyncMap { code in
            return Store.Item(section: id, template: .tab(.coin(try await Store.coin(by: code))))
        })
        items.append(Store.Item(section: id, template: .tab(.add)))
        let section = Store.Section(id: id,
                                    template: .tabs,
                                    items: items,
                                    footer: .spacer(height: 32))
        return section
    }
}
