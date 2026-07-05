import XCTest
@testable import PeekBar

final class HideStrategyTests: XCTestCase {
    private let representativeScreenWidths: [CGFloat] = [
        1280, 1440, 1680, 1920, 2560, 3440, 5120, 6016,
    ]

    func testCollapsedWidthAcrossRepresentativeScreensIsBounded() {
        for screenWidth in representativeScreenWidths {
            let width = HideWidth.collapsedWidth(screenWidth: screenWidth)

            // Must exceed the screen so the leftmost icon clears the edge, yet stay bounded.
            XCTAssertGreaterThanOrEqual(width, screenWidth)
            XCTAssertGreaterThanOrEqual(width, HideWidth.minimum)
            XCTAssertLessThanOrEqual(width, HideWidth.cap)
            XCTAssertNotEqual(width, 10_000)
        }
    }

    func testCollapsedWidthFallbackForInvalidScreenWidth() {
        let invalidWidths: [CGFloat] = [0, -1, .nan, .infinity]

        for screenWidth in invalidWidths {
            let width = HideWidth.collapsedWidth(screenWidth: screenWidth)

            XCTAssertGreaterThan(width, 0)
            XCTAssertGreaterThanOrEqual(width, HideWidth.minimum)
            XCTAssertLessThanOrEqual(width, HideWidth.cap)
            XCTAssertNotEqual(width, 10_000)
        }
    }

    func testLengthMappingCollapsedExceedsExpanded() {
        let screenWidth: CGFloat = 1920

        let collapsed = HideWidth.length(collapsed: true, screenWidth: screenWidth)
        let expanded = HideWidth.length(collapsed: false, screenWidth: screenWidth)

        XCTAssertGreaterThan(collapsed, expanded)
        XCTAssertEqual(expanded, HideWidth.expandedWidth)
    }

    func testCollapsedWidthOnNormalScreenHidesIcons() {
        let screenWidth: CGFloat = 1920
        let width = HideWidth.collapsedWidth(screenWidth: screenWidth)

        XCTAssertGreaterThanOrEqual(width, screenWidth)
    }

    @MainActor
    func testPrimaryCollapseRefusesWhenBoundaryIsRightOfToggle() {
        let toggleFrame = CGRect(x: 100, y: 0, width: 24, height: 24)
        let separatorFrame = CGRect(x: 140, y: 0, width: 8, height: 24)

        let shouldRefuse = LengthInflationStrategy.shouldRefuseCollapse(
            separatorFrame: separatorFrame,
            toggleFrame: toggleFrame
        )

        XCTAssertTrue(shouldRefuse)
    }

    @MainActor
    func testAlwaysHiddenFallbackAlsoRefusesWhenBoundaryIsRightOfToggle() {
        let toggleFrame = CGRect(x: 100, y: 0, width: 24, height: 24)
        let separatorFrame = CGRect(x: 140, y: 0, width: 8, height: 24)

        let shouldRefuse = LengthInflationStrategy.shouldRefuseCollapse(
            separatorFrame: separatorFrame,
            toggleFrame: toggleFrame
        )

        // Ideal spec behavior excludes Toggle Icon by identity. With this release's length-
        // inflation backend, secondary uses the same recoverability fallback as primary.
        XCTAssertTrue(shouldRefuse)
    }
}
