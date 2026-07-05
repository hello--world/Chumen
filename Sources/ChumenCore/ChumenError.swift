import Foundation

public enum ChumenError: Error, LocalizedError, Equatable {
    case missingCorePath
    case coreNotExecutable(String)
    case processAlreadyRunning
    case processNotRunning
    case invalidControllerURL
    case httpStatus(Int, String)
    case commandFailed(String)
    case systemProxyFailed(String)

    public var errorDescription: String? {
        switch self {
        case .missingCorePath:
            "Please choose a chumen-door, mihomo, or verge-mihomo executable first."
        case let .coreNotExecutable(path):
            "Core is not executable: \(path)"
        case .processAlreadyRunning:
            "Core is already running."
        case .processNotRunning:
            "Core is not running."
        case .invalidControllerURL:
            "Invalid external controller URL."
        case let .httpStatus(code, body):
            "Controller returned HTTP \(code): \(body)"
        case let .commandFailed(message):
            message
        case let .systemProxyFailed(message):
            message
        }
    }
}
