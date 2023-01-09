import CoreKit
import Foundation
import OrderedCollections

internal final class MultibarProvider: DefaultProvider {
    internal override var preloaded: OrderedSet<Store.Section> {[]}
    internal override func stream(for order: Store.Order) -> AsyncStream<Store.Order> {
        return AsyncStream { stream in
            Task {
                await order.accept()
                stream.yield(order)
                do {
                    async let tabs = try tabs()
                    async let settings = try settings()
                    async let footprint = try footprint()
                    await order.attach(try await tabs)
                    await order.attach(try await settings)
                    await order.attach(try await footprint)
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
        var codes = (try? await Store.coins().sorted(by: {$0.info.order < $1.info.order}).compactMap({$0.code})) ?? Keychain.wallets().compactMap({$0.coin})
        if codes.empty { codes = ["TON"] }
        let id = UUID()
        var items: OrderedSet<Store.Item> = try await OrderedSet(codes.asyncMap { code in
            return Store.Item(section: id, template: .tab(.coin(try await Store.coin(by: code))))
        })
        items.append(Store.Item(section: id, template: .tab(.add)))
        let section = Store.Section(id: id,
                                    template: .tabs,
                                    items: items,
                                    footer: .spacer(height: 16))
        return section
    }
    private func settings() async throws -> Store.Section {
        let settings = UUID()
        var items: OrderedSet<Store.Item> = [
            .spacer(height: 16, section: settings),
            Store.Item(section: settings, template: .option(.currency)),
            Store.Item(section: settings, template: .option(.passcode))
        ]
        switch System.Device.biometry {
        case .faceID, .touchID:
            items.append(Store.Item(section: settings, template: .option(.biometry)))
        default:
            break
        }
        let section = Store.Section(id: settings,
                                    template: .settings,
                                    header: .title(.large(text: "Settings")),
                                    items: items,
                                    footer: .spacer(height: 32))
        return section
    }
    private func footprint() async throws -> Store.Section {
        let footprint = UUID()
        let items: OrderedSet<Store.Item> = [
//            Store.Item(section: footprint, template: .footprint),
            Store.Item(section: footprint, template: .text(.center("https://github.com/multibar/wallet".attributed))),
            Store.Item(section: footprint, template: .text(.center("Version \(System.App.version)".attributed)))
        ]
        let section = Store.Section(id: footprint,
                                    template: .auto,
                                    items: items,
                                    footer: .spacer(height: 32))
        return section
    }
}
