import CoreKit
import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift

fileprivate let store = Firestore.firestore()
fileprivate let coins = store.collection("coins")
fileprivate let fiats = store.collection("fiats")

internal typealias Listener = ListenerRegistration

extension CollectionReference {
    internal func coin(_ code: String) -> DocumentReference {
        return document(code)
    }
    internal func fiat(_ code: String) -> DocumentReference {
        return document(code)
    }
}
extension Store {
    internal static func get(coin code: String) async throws -> Coin {
        return try await coins.coin(code).getDocument().data(as: Coin.self)
    }
    internal static func get(fiat code: String) async throws -> Fiat {
        return try await fiats.fiat(code).getDocument().data(as: Fiat.self)
    }
    internal static func get(coins query: Query) async throws -> [Coin] {
        switch query {
        case .none: return try await coins.getDocuments().documents.compactMap{try $0.data(as: Coin.self)}
        }
    }
    internal static func observe(_ coin: Coin) async throws -> (observable: Observable<Coin>, listener: Listener) {
        let observable = Observable(coin)
        let listener = coins.coin(coin.code).addSnapshotListener { [weak observable] document, _ in
            observable?.value = try? document?.data(as: Coin.self)
        }
        return (observable: observable, listener: listener)
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
