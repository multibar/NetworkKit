import Foundation

extension Network {
    public enum Failure: Error, Hashable {
        case url
        case skip
        case data(String)
        case space
        case misroute
        case finished
        case cancelled
        case decode(Error)
        case message(String)
        
        case key
        case encryption
        case decryption
        
        case unknown(Error)
        
        public var description: String {
            switch self {
            case .url:
                return "URL configuration error"
            case .skip:
                return "Skip"
            case .data(let more):
                return more
            case .space:
                return "Out of space on device"
            case .misroute:
                return "Route is not configured properly."
            case .finished:
                return "Finished"
            case .cancelled:
                return "Cancelled"
            case .decode(let error):
                return "Decode error: \(error)"
            case .key:
                return "Missing private key"
            case .encryption:
                return "Failed to encrypt."
            case .decryption:
                return "Failed to decrypt."
            case .message(let message):
                return message
            case .unknown(let error):
                return "Unknown error: \(error)"
            }
        }
        public var copy: String {
            switch self {
            default:
                return description
            }
        }
        
        public static func == (lhs: Network.Failure, rhs: Network.Failure) -> Bool {
            lhs.hashValue == rhs.hashValue
        }
        public func hash(into hasher: inout Hasher) {
            hasher.combine(description)
        }
    }
}
