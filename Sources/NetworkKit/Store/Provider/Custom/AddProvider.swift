import CoreKit
import Foundation
import OrderedCollections

internal final class AddProvider: DefaultProvider {
    internal override func stream(for order: Store.Order) -> AsyncStream<Store.Order> {
        return AsyncStream { stream in
            Task {
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
                        async let sections = try get(coin: coin, stage: .store(.location(coin)))
                        await order.attach(try await sections)
                        await order.complete()
                    case .recovery(let coin, let location):
                        switch order.operation {
                        case .reload:
                            async let sections = try get(coin: coin, stage: .store(.recovery(coin, location)))
                            await order.attach(try await sections)
                            await order.complete()
                        case .store(let phrases, let coin, let location, let password):
                            try await self.store(phrases: phrases, with: coin, at: location, with: password)
                            await order.complete()
                        }
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
        let coins = try await Store.coins(with: query)
        let id = UUID()
        let items = OrderedSet(coins.sorted(by: {$0.info.order < $1.info.order}).compactMap({Store.Item(section: id, template: .add($0))}))
        let section = Store.Section(id: id,
                                    items: items,
                                    footer: .spacer(height: 32))
        return section
    }
    private func get(coin: Coin, stage: Route.Add.Stage) async throws -> OrderedSet<Store.Section> {
        let header = UUID()
        let headers: OrderedSet<Store.Item> = {
            var items: OrderedSet<Store.Item> = []
            switch stage {
            case .store(let store):
                switch store {
                case .location(let coin):
                    items.append(.spacer(height: 8, section: header))
                    items.append(Store.Item(section: header, template: .text(.head(coin.info.title.attributed))))
                case .recovery:
                    items.append(.spacer(height: 8, section: header))
                }
            default:
                items.append(.spacer(height: 8, section: header))
                items.append(Store.Item(section: header, template: .text(.head(coin.info.title.attributed))))
            }
            return items
        }()
        let button = UUID()
        let buttons: OrderedSet<Store.Item> = {
            var items: OrderedSet<Store.Item> = []
            switch stage {
            case .coin(let coin):
                coin.perks.forEach({ perk in
                    switch perk {
                    case .key:
                        items.append(Store.Item(section: button, template: .button(route: Route(to: .add(stage: .store(.location(coin)))))))
                    case .wallet:
                        items.append(Store.Item(section: button, template: .button(route: Route(to: .add(stage: .import(coin))))))
                        items.append(Store.Item(section: button, template: .button(route: Route(to: .add(stage: .create(coin))))))
                    }
                })
                items.append(Store.Item(section: button, template: .text(.center(longText.attributed))))
            case .store(let store):
                switch store {
                case .location(let coin):
                    items.append(Store.Item(section: button, template: .button(route: Route(to: .add(stage: .store(.recovery(coin, .keychain)))))))
                    items.append(Store.Item(section: button, template: .button(route: Route(to: .add(stage: .store(.recovery(coin, .cloud)))))))
                    items.append(.spacer(height: 0))
                    items.append(Store.Item(section: button, template: .text(.center(longText.attributed))))
                case .recovery(let coin, let location):
                    items.append(Store.Item(section: button, template: .recovery(coin, location)))
                }
            default:
                break
            }
            return items
        }()        
        return [
            .spacer(height: 8),
            Store.Section(id: header,
                          header: .coin(coin),
                          items: headers),
            Store.Section(id: button,
                          header: .spacer(height: 24),
                          items: buttons)
        ]
    }
    private func store(phrases: [String], with coin: Coin, at location: Wallet.Location, with password: String) async throws {
        guard let encrypted = encrypt(secret: phrases.joined(separator: " "), with: password) else { throw Network.Failure.encryption }
        let wallets = Keychain.wallets().filter({$0.coin == coin.code}).count
        let wallet = Wallet(title: "Wallet \(wallets + 1)", coin: coin.code, phrase: encrypted, location: location)
        switch location {
        case .cloud:
            break
        case .keychain:
            try Keychain.save(wallet: wallet)
        }
    }
}

extension AddProvider {
    fileprivate var longText: String { "Long read text describing the endless possibilities of using either iCloud Keychain or Google's Firestore Cloud. Both solutions are so great and offers so many perks, you can't even imagine. \nAlmost forgot to say, you can even export your private encryption key! Good luck."
    }
}
