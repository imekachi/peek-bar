import XCTest
import Sparkle
@testable import PeekBar

final class UpdateMetadataTests: XCTestCase {
    private var repoRoot: URL!

    override func setUp() {
        super.setUp()
        repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    func testDeclaredVersionFieldsAreSynced() throws {
        let projectYML = try String(
            contentsOf: repoRoot.appendingPathComponent("project.yml"),
            encoding: .utf8
        )
        let infoPlist = try String(
            contentsOf: repoRoot.appendingPathComponent("PeekBar/Resources/Info.plist"),
            encoding: .utf8
        )

        let marketingVersion = try XCTUnwrap(
            firstCapture(in: projectYML, pattern: #"MARKETING_VERSION:\s*([0-9]+\.[0-9]+\.[0-9]+)"#)
        )
        let shortVersion = try XCTUnwrap(
            firstCapture(in: infoPlist, pattern: #"<key>CFBundleShortVersionString</key>\s*<string>([^<]+)</string>"#)
        )
        XCTAssertEqual(marketingVersion, shortVersion)

        let projectBundleVersion = try XCTUnwrap(
            firstCapture(in: projectYML, pattern: #"CURRENT_PROJECT_VERSION:\s*([0-9]+\.[0-9]+\.[0-9]+)"#)
        )
        let bundleBuild = try XCTUnwrap(
            firstCapture(in: infoPlist, pattern: #"<key>CFBundleVersion</key>\s*<string>([^<]+)</string>"#)
        )
        XCTAssertEqual(marketingVersion, projectBundleVersion)
        XCTAssertEqual(marketingVersion, bundleBuild)
    }

    func testReleaseVersionWouldBeNewerThanShippedZeroOneZero() throws {
        let projectYML = try String(
            contentsOf: repoRoot.appendingPathComponent("project.yml"),
            encoding: .utf8
        )

        let marketingVersion = try XCTUnwrap(
            firstCapture(in: projectYML, pattern: #"MARKETING_VERSION:\s*([0-9]+\.[0-9]+\.[0-9]+)"#)
        )
        let result = SUStandardVersionComparator.default.compareVersion("0.1.0", toVersion: marketingVersion)

        XCTAssertEqual(result, .orderedAscending)
    }

    func testManualUpdateCheckCacheBustHookExportsSparkleSelector() {
        let selector = NSSelectorFromString("updater:mayPerformUpdateCheck:error:")

        XCTAssertNotNil(class_getInstanceMethod(SparkleUpdateDelegateBridge.self, selector))
    }

    private func firstCapture(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              match.numberOfRanges > 1,
              let captureRange = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return String(text[captureRange])
    }
}
