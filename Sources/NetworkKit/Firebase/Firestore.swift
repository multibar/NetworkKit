import CoreKit
import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift

fileprivate let store = Firestore.firestore()
fileprivate let coins = store.collection("coins")
fileprivate let fiats = store.collection("fiats")
fileprivate let settings = store.collection("settings")

internal typealias Listener = ListenerRegistration

extension CollectionReference {
    internal var time: DocumentReference {
        return document("time")
    }
    internal func coin(_ code: String) -> DocumentReference {
        return document(code)
    }
    internal func fiat(_ code: String) -> DocumentReference {
        return document(code)
    }
}
extension Store {
    internal static func coin(by code: String) async throws -> Coin {
        return try await NetworkKit.coins.coin(code).getDocument(as: Coin.self)
    }
    internal static func fiat(by code: String) async throws -> Fiat {
        return try await NetworkKit.fiats.fiat(code).getDocument(as: Fiat.self)
    }
    internal static func coins(with query: Query) async throws -> [Coin] {
        switch query {
        case .none: return try await NetworkKit.coins.getDocuments().documents.compactMap{try $0.data(as: Coin.self)}
        }
    }
    internal static func observe(_ coin: Coin) async throws -> (observable: Observable<Coin>, listener: Listener) {
        let observable = Observable(coin)
        let listener = NetworkKit.coins.coin(coin.code).addSnapshotListener { [weak observable] document, _ in
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
