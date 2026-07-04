import Foundation
import os

enum StartupLog {
    private static let logger = Logger(subsystem: "com.imekachi.PeekBar", category: "startup")

    static func emit(_ message: String) {
        logger.info("\(message, privacy: .public)")
        if let data = (message + "\n").data(using: .utf8) {
            FileHandle.standardError.write(data)
        }
    }
}
