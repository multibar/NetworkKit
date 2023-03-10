import CoreKit
import Foundation
import OrderedCollections

internal final class AddProvider: DefaultProvider {
    internal override func stream(for order: Store.Order) -> AsyncStream<Store.Order> {
        return AsyncStream { stream in
            Task {
                await order.accept()
                do {
                    switch route.add {
                    case .coins:
                        async let coins = try coins()
                        await order.attach(try await coins)
                        await order.complete()
                    case .coin(let coin):
                        async let coin = try result(for: coin, add: .coin(coin))
                        await order.attach(try await coin)
                        await order.complete()
                    case .store(let store):
                        switch store {
                        case .location(let coin):
                            async let sections = try result(for: coin, add: .store(.location(coin)))
                            await order.attach(try await sections)
                            await order.complete()
                        case .recovery(let coin, let location, let words):
                            switch order.operation {
                            case .reload:
                                async let sections = try result(for: coin, add: .store(.recovery(coin, location, words)))
                                await order.attach(try await sections)
                                await order.complete()
                            case .store(let phrases, let coin, let location, let key):
                                let wallet = try await self.store(phrases: phrases, with: coin, at: location, with: key)
                                await order.attach(.wallet(wallet))
                                await order.complete()
                            default:
                                await order.attach(.misroute)
                                await order.fail()
                            }
                        }
                    default:
                        await order.attach(.misroute)
                        await order.fail()
                    }
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
extension AddProvider {
    private func coins(for query: Store.Query = .none) async throws -> Store.Section {
        let coins = try await Store.coins(with: query)
        let id = UUID()
        let items = OrderedSet(coins.sorted(by: {$0.info.order < $1.info.order}).compactMap({Store.Item(section: id, template: .add($0))}))
        let section = Store.Section(id: id,
                                    items: items,
                                    footer: .spacer(height: 32))
        return section
    }
    private func result(for coin: Coin, add: Route.Add) async throws -> OrderedSet<Store.Section> {
        var words = coin.info.words
        var keychain = false
        let header = UUID()
        let headers: OrderedSet<Store.Item> = {
            var items: OrderedSet<Store.Item> = []
            items.append(.spacer(height: 8, section: header))
            switch add {
            case .store(let store):
                switch store {
                case .recovery(_, let location, _):
                    switch location {
                    case .cloud:
                        items.append(Store.Item(section: header, template: .text(.head("Cloud".attributed))))
                    case .keychain:
                        items.append(Store.Item(section: header, template: .text(.head("Keychain".attributed))))
                    }
                default:
                    items.append(Store.Item(section: header, template: .text(.head(coin.info.title.attributed))))
                    items.append(Store.Item(section: header, template: .text(.center(coin.links.origin.source.attributed))))
                }
            default:
                items.append(Store.Item(section: header, template: .text(.head(coin.info.title.attributed))))
                items.append(Store.Item(section: header, template: .text(.center(coin.links.origin.source.attributed))))
            }
            items.append(.spacer(height: 8, section: header))
            return items
        }()
        let toggle = UUID()
        let stepper = UUID()
        let button = UUID()
        let buttons: OrderedSet<Store.Item> = {
            var items: OrderedSet<Store.Item> = []
            switch add {
            case .coin(let coin):
                coin.perks.forEach({ perk in
                    switch perk {
                    case .key:
                        items.append(Store.Item(section: button, template: .button(.route(Route(to: .add(.store(.location(coin))))))))
                    case .wallet:
                        items.append(Store.Item(section: button, template: .button(.route(Route(to: .add(.import(coin)))))))
                        items.append(Store.Item(section: button, template: .button(.route(Route(to: .add(.create(coin)))))))
                    }
                })
                items.append(.spacer(height: 0))
                items.append(Store.Item(section: button, template: .text(.center(longText.attributed))))
            case .store(let store):
                switch store {
                case .location(let coin):
                    items.append(Store.Item(section: button,
                                            template: .button(.route(Route(to: .add(.store(.recovery(coin, .keychain(.device), coin.info.words))))))))
                    items.append(Store.Item(section: button,
                                            template: .button(.route(Route(to: .add(.store(.recovery(coin, .cloud, coin.info.words))))))))
                    items.append(.spacer(height: 0))
                    items.append(Store.Item(section: button,
                                            template: .text(.center(longText.attributed))))
                case .recovery(let coin, let location, let count):
                    words = count
                    for number in 1...count {
                        items.append(Store.Item(section: button, template: .phrase(number: number, last: number == count)))
                    }
                    items.append(Store.Item(section: button, template: .button(.process(coin, location))))
                    switch location {
                    case .keychain:
                        keychain = true
                    default:
                        break
                    }
                }
            default:
                break
            }
            return items
        }()
        let sections: OrderedSet<Store.Section> = {
            if add.recovery {
                if keychain {
                    return [
                        .spacer(height: 8),
                        Store.Section(id: header,
                                      header: .coin(coin),
                                      items: headers),
                        Store.Section(id: toggle,
                                      items: [Store.Item(section: toggle, template: .toggle(.keychain(.device)))]),
                        Store.Section(id: stepper,
                                      items: [.spacer(height: 8, section: stepper), Store.Item(section: stepper, template: .stepper(.words(words)))]),
                        Store.Section(id: button,
                                      header: .spacer(height: 24),
                                      items: buttons)
                    ]
                } else {
                    return [
                        .spacer(height: 8),
                        Store.Section(id: header,
                                      header: .coin(coin),
                                      items: headers,
                                      footer: .perks(coin)),
                        Store.Section(id: stepper,
                                      items: [Store.Item(section: stepper, template: .stepper(.words(words)))]),
                        Store.Section(id: button,
                                      header: .spacer(height: 24),
                                      items: buttons)
                    ]
                }
            } else {
                return [
                    .spacer(height: 8),
                    Store.Section(id: header,
                                  header: .coin(coin),
                                  items: headers,
                                  footer: .perks(coin)),
                    Store.Section(id: button,
                                  header: .spacer(height: 24),
                                  items: buttons)
                ]
            }
        }()
        return sections
    }
    private func store(phrases: [String], with coin: Coin, at location: Wallet.Location, with key: String) async throws -> Wallet {
        guard let encrypted = encrypt(secret: phrases.joined(separator: " "), with: key) else { throw Network.Failure.encryption }
        let wallets = Keychain.wallets().filter({$0.coin == coin.code && $0.location == location}).count
        let wallet = Wallet(title: Self.title(for: location, number: wallets + 1), coin: coin.code, phrase: encrypted, location: location)
        switch location {
        case .cloud:
            break
        case .keychain:
            try Keychain.save(wallet)
            if wallet.location.device {
                try Keychain.save(key, for: wallet)
            }
        }
        return wallet
    }
}

extension AddProvider {
    private static func title(for location: Wallet.Location, number: Int) -> String {
        switch location {
        case .cloud:
            return "Cloud Wallet \(number)"
        case .keychain(let location):
            switch location {
            case .device:
                return "Device Wallet \(number)"
            case .icloud:
                return "iCloud Wallet \(number)"
            }
        }
    }
}
extension AddProvider {
    private var longText: String {
        "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum."
    }
}
extension Route.Add {
    fileprivate var recovery: Bool {
        switch self {
        case .store(let store):
            switch store {
            case .recovery:
                return true
            default:
                return false
            }
        default:
            return false
        }
    }
}
