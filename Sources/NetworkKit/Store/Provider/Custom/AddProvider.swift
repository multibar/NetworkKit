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
                    async let coin = try get(coin: coin, stage: .coin(coin))
                    await order.attach(try await coin)
                    await order.complete()
                case .store(let store):
                    switch store {
                    case .location(let coin):
                        async let coin = try get(coin: coin, stage: .store(.location(coin)))
                        await order.attach(try await coin)
                        await order.complete()
                    default:
                        break
                    }
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
        let items = OrderedSet(coins.sorted(by: {$0.info.order < $1.info.order}).compactMap({Store.Item(section: id, template: .add($0))}))
        let section = Store.Section(id: id,
                                    items: items,
                                    footer: .spacer(height: 32))
        return section
    }
    private func get(coin: Coin, stage: Route.Add.Stage) async throws -> OrderedSet<Store.Section> {
        print(coin)
        let header = UUID()
        let buttons = UUID()
        let items: OrderedSet<Store.Item> = {
            var items: OrderedSet<Store.Item> = []
            switch stage {
            case .store(let store):
                switch store {
                case .location(let coin):
                    print(coin)
                    items.append(Store.Item(section: header, template: .button(route: Route(to: .add(stage: .store(.recovery(coin, .keychain)))))))
                    items.append(Store.Item(section: header, template: .button(route: Route(to: .add(stage: .store(.recovery(coin, .cloud)))))))
                    items.append(.spacer(height: 0))
                    items.append(Store.Item(section: header, template: .text(.center(longText.attributed))))
                case .recovery(let coin, let location):
                    break
                }
            default:
                coin.perks.forEach({ perk in
                    switch perk {
                    case .key:
                        items.append(Store.Item(section: header, template: .button(route: Route(to: .add(stage: .store(.location(coin)))))))
                    case .wallet:
                        items.append(Store.Item(section: header, template: .button(route: Route(to: .add(stage: .import(coin))))))
                        items.append(Store.Item(section: header, template: .button(route: Route(to: .add(stage: .create(coin))))))
                    }
                })
            }
            return items
        }()
        return [
            .spacer(height: 8),
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

extension AddProvider {
    fileprivate var longText: String { "Long read text describing the endless possibilities of using \neither iCloud Keychain or Google's Firestore Cloud.\nBoth solutions are so great and offers so many perks,\nyou can't even imagine. \nAlmost forgot to say, you can even export your \nprivate encryption key! \nGood luck."
    }
}
