import Foundation

extension Network {
    public enum Progress {
        case loading
        case queued
        case downloading(progress: Double)
        case uploading(progress: Double)
        case paused
        case failed(error: Network.Failure)
        case finished(result: Result)
    }
}

extension Network.Progress {
    public enum Result {
        case data(Data)
        case file(URL)
        
        public var data: Data? {
            switch self {
            case .data(let data):
                return data
            default:
                return nil
            }
        }
        public var url: URL? {
            switch self {
            case .file(let url):
                return url
            default:
                return nil
            }
        }
    }
}
