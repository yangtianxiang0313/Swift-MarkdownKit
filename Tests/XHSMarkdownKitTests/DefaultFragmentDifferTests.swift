import UIKit
import XCTest
@testable import XHSMarkdownKit

final class DefaultFragmentDifferTests: XCTestCase {

    func testCustomFragmentWithoutOverrideUsesDefaultContentEquality() {
        let differ = DefaultFragmentDiffer()
        let oldFragment = CustomTestFragment(fragmentId: "custom.1", nodeType: FragmentNodeType(rawValue: "custom.node"), payload: "old")
        let newFragment = CustomTestFragment(fragmentId: "custom.1", nodeType: FragmentNodeType(rawValue: "custom.node"), payload: "new")

        let changes = differ.diff(old: [oldFragment], new: [newFragment])

        XCTAssertFalse(hasUpdate(changes))
    }

    func testCustomFragmentWithOverrideCanDriveUpdate() {
        let differ = DefaultFragmentDiffer()
        let oldFragment = ComparableCustomTestFragment(fragmentId: "custom.1", payload: "old")
        let newFragment = ComparableCustomTestFragment(fragmentId: "custom.1", payload: "new")

        let changes = differ.diff(old: [oldFragment], new: [newFragment])

        XCTAssertTrue(hasUpdate(changes))
    }

    func testBlockQuoteContainerStyleChangeTriggersUpdate() {
        let differ = DefaultFragmentDiffer()
        let child = makeChildFragment(id: "child.1")

        let old = BlockQuoteContainerFragment(
            fragmentId: "bq.1",
            config: BlockQuoteContainerConfiguration(
                childFragments: [child],
                depth: 1,
                barColor: .lightGray,
                barWidth: 2,
                barLeftMargin: 8
            )
        )
        let new = BlockQuoteContainerFragment(
            fragmentId: "bq.1",
            config: BlockQuoteContainerConfiguration(
                childFragments: [child],
                depth: 1,
                barColor: .red,
                barWidth: 2,
                barLeftMargin: 8
            )
        )

        let changes = differ.diff(old: [old], new: [new])

        XCTAssertTrue(hasUpdate(changes))
    }

    func testViewFragmentMaxWidthChangeTriggersUpdate() {
        let differ = DefaultFragmentDiffer()

        var oldContext = FragmentContext()
        oldContext[MaxWidthKey.self] = 200
        let oldFragment = ViewFragment(
            fragmentId: "img.1",
            nodeType: .image,
            reuseIdentifier: .markdownImageView,
            context: oldContext,
            content: EmptyFragmentContent(),
            makeView: { UIView() },
            configure: { _ in }
        )

        var newContext = FragmentContext()
        newContext[MaxWidthKey.self] = 320
        let newFragment = ViewFragment(
            fragmentId: "img.1",
            nodeType: .image,
            reuseIdentifier: .markdownImageView,
            context: newContext,
            content: EmptyFragmentContent(),
            makeView: { UIView() },
            configure: { _ in }
        )

        let changes = differ.diff(old: [oldFragment], new: [newFragment])
        XCTAssertTrue(hasUpdate(changes))
    }

    private func hasUpdate(_ changes: [FragmentChange]) -> Bool {
        changes.contains {
            if case .update = $0 { return true }
            return false
        }
    }

    private func makeChildFragment(id: String) -> ViewFragment {
        ViewFragment(
            fragmentId: id,
            nodeType: .paragraph,
            reuseIdentifier: .textView,
            content: EmptyFragmentContent(),
            makeView: { UIView() },
            configure: { _ in }
        )
    }
}

private final class CustomTestFragment: RenderFragment {
    let fragmentId: String
    let nodeType: FragmentNodeType
    var spacingAfter: CGFloat = 0
    let payload: String

    init(fragmentId: String, nodeType: FragmentNodeType, payload: String) {
        self.fragmentId = fragmentId
        self.nodeType = nodeType
        self.payload = payload
    }
}

private final class ComparableCustomTestFragment: RenderFragment {
    let fragmentId: String
    let nodeType: FragmentNodeType = FragmentNodeType(rawValue: "custom.node")
    var spacingAfter: CGFloat = 0
    let payload: String

    init(fragmentId: String, payload: String) {
        self.fragmentId = fragmentId
        self.payload = payload
    }

    func isContentEqual(to other: any RenderFragment) -> Bool {
        guard let rhs = other as? ComparableCustomTestFragment else { return false }
        guard fragmentId == rhs.fragmentId else { return false }
        guard nodeType == rhs.nodeType else { return false }
        guard spacingAfter == rhs.spacingAfter else { return false }
        return payload == rhs.payload
    }
}
