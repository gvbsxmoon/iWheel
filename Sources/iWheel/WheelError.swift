import Foundation

enum WheelError: LocalizedError {
    case frameworkUnavailable(String)
    case symbolMissing(String)
    case noDevices

    var errorDescription: String? {
        switch self {
        case .frameworkUnavailable(let name):
            return "Could not load the private framework \(name). Unsupported macOS version?"
        case .symbolMissing(let name):
            return "Missing symbols in \(name): the private API changed in this macOS version."
        case .noDevices:
            return "No multitouch trackpad found."
        }
    }
}
