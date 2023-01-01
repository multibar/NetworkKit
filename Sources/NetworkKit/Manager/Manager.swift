import CoreKit
import Firebase
import Foundation

extension Network {
    public final class Manager {
        public static let shared = Manager()
        public private(set) var configuration: Network.Configuration?
        
        private var _state: System.User.State?
        
        public func initialize(with configuration: Network.Configuration) {
            self.configuration = configuration
            if let firebase = configuration.firebase, let options = FirebaseOptions(contentsOfFile: firebase) {
                FirebaseApp.configure(options: options)
            } else {
                FirebaseApp.configure()
            }
            listeners()
        }
        private init() {
            log(event: "NetworkKit initialized")
            Core.Manager.shared.network = self
        }
        private func listeners() {
            Auth.auth().addStateDidChangeListener { auth, user in
                let state: System.User.State = user != nil ? .authorized : .unauthorized
                guard self._state != nil else { self._state = state; return }
                Core.Manager.shared.bridges.forEach({$0.user(state: state)})
            }
        }
    }
}

extension Network.Manager: NetworkBridge {
    public var host: String {
        return "multi.bar"
    }
    public var user: System.User? {
        guard let user = Auth.auth().currentUser else { return nil }
        return System.User(id: user.uid)
    }
    public var state: System.User.State {
        return _state ?? (Auth.auth().currentUser != nil ? .authorized : .unauthorized)
    }
    public func app(state: System.App.State) {}
    public func user(state: System.User.State) {}
}
