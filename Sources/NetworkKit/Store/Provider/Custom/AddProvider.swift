import CoreKit
import Foundation
import OrderedCollections

internal final class AddProvider: DefaultProvider {
    internal override func stream(for order: Store.Order) -> AsyncStream<Store.Order> {
        return AsyncStream { stream in
            Task {
                await order.accept()
                switch route.stage {
                case .coins:
                    async let coins = try get()
                    await order.attach(try await coins)
                    await order.complete()
                case .coin(let coin):
                    async let coin = try get(coin: coin)
                    await order.attach(try await coin)
                    await order.complete()
                default:
                    await order.attach(.misroute)
                    await order.fail()
                }
                stream.yield(order)
                stream.finish()
            }
        }
    }
}
extension AddProvider {
    private func get(coins query: Store.Query = .none) async throws -> Store.Section {
        let coins = try await Store.get(coins: query)
        let id = UUID()
        let items = OrderedSet(coins.sorted(by: {$0.info.order < $1.info.order}).compactMap({Store.Item(section: id, template: .coin($0))}))
        let section = Store.Section(id: id,
                                    items: items,
                                    footer: .spacer(height: 32))
        return section
    }
    private func get(coin: Coin) async throws -> OrderedSet<Store.Section> {
        let header = UUID()
        let buttons = UUID()
        let items: OrderedSet<Store.Item> = {
            var items: OrderedSet<Store.Item> = []
            coin.perks.forEach({ perk in
                switch perk {
                case .key:
                    items.append(Store.Item(section: header, template: .button(route: Route(to: .add(stage: .store(coin))))))
                case .wallet:
                    items.append(Store.Item(section: header, template: .button(route: Route(to: .add(stage: .import(coin))))))
                    items.append(Store.Item(section: header, template: .button(route: Route(to: .add(stage: .create(coin))))))
                }
            })
            return items
        }()
        return [
            .spacer(height: 32),
            Store.Section(id: header,
                          header: .coin(coin),
                          items: [
                            .spacer(height: 8, section: header),
                            Store.Item(section: header, template: .text(.head(coin.info.title.attributed))),
                            Store.Item(section: header, template: .text(.center(coin.links.origin.source.attributed))),
                            .spacer(height: 8, section: header)
                          ],
                          footer: .perks(coin)),
            Store.Section(id: buttons,
                          header: .spacer(height: 24),
                          items: items)
        ]
    }
}
