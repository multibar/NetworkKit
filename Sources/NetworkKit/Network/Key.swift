import Foundation

extension Network.Api {
    public struct Key {
        public let value: String
        public let header: String
        
        public init(value: String, header: String) {
            self.value = value
            self.header = header
        }
    }
}
