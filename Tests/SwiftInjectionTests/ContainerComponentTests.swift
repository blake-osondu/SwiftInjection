import XCTest
import SwiftUI
import ViewInspector
@testable import SwiftInjection
@testable import SwiftInjectionCore

final class ContainerComponentTests: XCTestCase {

    private func texts(_ values: ClosedRange<Int>) -> String {
        values.map { #"{"text": {"value": "\#($0)"}}"# }.joined(separator: ",")
    }

    func testStacksRenderAllChildrenInOrder() throws {
        // More than the old 10-slot limit; the old 7th slot also rendered the 6th child.
        for kind in ["vStack", "hStack", "zStack", "lazyVStack", "lazyHStack", "group", "form"] {
            let screen = try RenderedScreen(#"{"\#(kind)": {"children": [\#(texts(1...12))]}}"#)
            XCTAssertEqual(try screen.texts(), (1...12).map(String.init), kind)
            XCTAssertEqual(screen.reportedErrors, [], kind)
        }
    }

    func testStackAlignmentAndSpacingReadState() throws {
        let screen = try RenderedScreen(#"""
        {"vStack": {"alignment": {"var": "align"}, "spacing": {"var": "gap"}, "children": [{"text": {"value": "a"}}]}}
        """#, state: ["align": "leading", "gap": 12])
        let stack = try screen.inspect().find(ViewType.VStack.self)
        XCTAssertEqual(try stack.alignment(), .leading)
        XCTAssertEqual(try stack.spacing(), 12)
        XCTAssertEqual(screen.reportedErrors, [])
    }

    func testInvalidAlignmentIsReportedAndFallsBack() throws {
        let screen = try RenderedScreen(#"{"hStack": {"alignment": "diagonal", "children": []}}"#)
        XCTAssertEqual(try screen.inspect().find(ViewType.HStack.self).alignment(), .center)
        XCTAssertEqual(Set(screen.reportedErrors), [EvaluationError.typeMismatch(op: "resolve", expected: "InjectedVerticalAlignment", got: "diagonal").description])
    }

    func testScrollViewSectionAndControlGroup() throws {
        let screen = try RenderedScreen(#"""
        {"scrollView": {"axes": "horizontal", "showsIndicators": false, "children": [
          {"section": {"title": {"var": "heading"}, "footer": {"text": {"value": "foot"}}, "children": [{"text": {"value": "row"}}]}},
          {"controlGroup": {"children": [{"text": {"value": "control"}}]}}
        ]}}
        """#, state: ["heading": "Head"])
        XCTAssertEqual(Set(try screen.texts()), ["Head", "row", "foot", "control"])
        XCTAssertEqual(screen.reportedErrors, [])
    }

    func testGrids() throws {
        let screen = try RenderedScreen(#"""
        {"vStack": {"children": [
          {"grid": {"horizontalSpacing": 4, "children": [
            {"gridRow": {"alignment": "top", "children": [{"text": {"value": "a"}}, {"text": {"value": "b"}}]}}
          ]}},
          {"lazyVGrid": {"columns": [{"size": "adaptive", "minimum": 80}], "pinnedViews": ["sectionHeaders"],
                         "children": [{"text": {"value": "c"}}]}},
          {"lazyHGrid": {"rows": [{"size": "fixed", "value": 40}], "children": [{"text": {"value": "d"}}]}}
        ]}}
        """#)
        XCTAssertEqual(try screen.texts(), ["a", "b", "c", "d"])
        XCTAssertEqual(screen.reportedErrors, [])
    }

    func testGridItemRendersItsConfiguration() throws {
        let item = try JSONDecoder().decode(InjectedGridItem.self, from: Data(#"{"size": "adaptive", "minimum": 80, "maximum": 120, "spacing": 6, "alignment": "leading"}"#.utf8)).render
        guard case let .adaptive(minimum, maximum) = item.size else { return XCTFail("\(item.size)") }
        XCTAssertEqual(minimum, 80)
        XCTAssertEqual(maximum, 120)
        XCTAssertEqual(item.spacing, 6)
        XCTAssertEqual(item.alignment, .leading)

        guard case .fixed(40) = InjectedGridItem(size: .fixed, value: 40).render.size else { return XCTFail() }
        XCTAssertEqual([InjectedPinnedScrollableViews.sectionHeaders, .sectionFooters].render, [.sectionHeaders, .sectionFooters])
    }

    func testTabsAndNavigation() throws {
        let screen = try RenderedScreen(#"""
        {"navigationStack": {"root":
          {"tab": {"selection": "tab", "children": [
            {"navigationLink": {"label": {"text": {"value": "Open"}}, "destination": {"text": {"value": "Detail"}}}},
            {"text": {"value": "Second"}}
          ]}}
        }}
        """#, state: ["tab": 1])
        XCTAssertNoThrow(try screen.inspect().find(ViewType.TabView.self))
        // ViewInspector can't render through NavigationLink's label closure, so check the label is the payload's view.
        let link = try screen.inspect().find(ViewType.NavigationLink.self)
        let label = try link.labelView().view(InjectedContent.self).actualView().view
        guard case let .text(text) = label else { return XCTFail("\(label)") }
        XCTAssertEqual(text.value, "Open")
        XCTAssertEqual(try screen.inspect().find(text: "Second").string(), "Second")
        XCTAssertEqual(screen.reportedErrors, [])
    }

    func testContainersNestAndShareState() throws {
        let screen = try RenderedScreen(#"""
        {"vStack": {"children": [
          {"hStack": {"children": [{"text": {"value": {"var": "a"}}}, {"zStack": {"children": [{"text": {"value": {"var": "b"}}}]}}]}}
        ]}}
        """#, state: ["a": "outer", "b": "inner"])
        XCTAssertEqual(try screen.texts(), ["outer", "inner"])
    }
}
