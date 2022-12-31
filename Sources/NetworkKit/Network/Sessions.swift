import Foundation

extension Workstation {
    public enum Session {
        case foreground
        case background
    }
    public struct Sessions {
        public let foreground: URLSession
        public let background: URLSession
        
        public var all: [URLSession] {
            return [foreground, background]
        }
        public func session(for session: Session) -> URLSession {
            switch session {
            case .foreground: return foreground
            case .background: return background
            }
        }
    }
}
