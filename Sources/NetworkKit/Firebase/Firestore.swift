import CoreKit
import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift

fileprivate let store = Firestore.firestore()
fileprivate let coins = store.collection("coins")
fileprivate let fiats = store.collection("fiats")

internal typealias Listener = ListenerRegistration

extension CollectionReference {
    internal func coin(_ coin: Coin) -> DocumentReference {
        return document("\(coin.code)")
    }
    internal func fiat(_ fiat: Fiat) -> DocumentReference {
        return document("\(fiat.code)")
    }
}
extension Store {
    internal static func get(coin: Coin) async throws -> Coin {
        return try await coins.coin(coin).getDocument().data(as: Coin.self)
    }
    internal static func get(fiat: Fiat) async throws -> Fiat {
        return try await fiats.fiat(fiat).getDocument().data(as: Fiat.self)
    }
    internal static func get(coins query: Query) async throws -> [Coin] {
        switch query {
        case .none: return try await coins.getDocuments().documents.compactMap{try $0.data(as: Coin.self)}
        }
    }
    internal static func observe(coin: Coin) async throws -> (coin: Coin, observable: Observable<Coin>, listener: Listener) {
        let coin = try await get(coin: coin)
        let observable = Observable(coin)
        let listener = coins.coin(coin).addSnapshotListener { [weak observable] document, _ in
            observable?.value = try? document?.data(as: Coin.self)
        }
        return (coin: coin, observable: observable, listener: listener)
    }
}
public protocol Observer: AnyObject {
    func fetch()
}
extension Store {
    public class Observable<T: Any>: Hashable, Equatable {
        private let id = UUID()
        public weak var observer: Observer?
        public var value: T? {
            didSet {
                Task { await fetch() }
            }
        }
        public required init(_ value: T) {
            self.value = value
        }
        public func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
        public static func == (lhs: Observable, rhs: Observable) -> Bool {
            return lhs.id == rhs.id
        }
        
        @MainActor
        private func fetch() async {
            observer?.fetch()
        }
    }
}
extension Array where Element == Listener {
    internal mutating func destroy() {
        forEach({$0.remove()})
        removeAll()
    }
}
