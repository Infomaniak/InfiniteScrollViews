import XCTest
@testable import InfiniteScrollViews
#if canImport(SwiftUI)
import SwiftUI
#endif

final class InfiniteScrollViewsTests: XCTestCase {
#if canImport(SwiftUI)
    func testProxyDeliversRequestQueuedBeforeConnection() {
        let coordinator = InfiniteScrollViewProxyCoordinator()
        let proxy = InfiniteScrollViewProxy(coordinator: coordinator)
        var receivedIndexes = [Int]()

        proxy.scrollTo(42, anchor: .center)
        var receivedAnchor: InfiniteScrollViewAnchor?
        var receivedAnimated = false
        coordinator.connect(animated: true) { index, anchor, animated in
            guard let index = index as? Int else { return .incompatible }
            receivedIndexes.append(index)
            receivedAnchor = anchor
            receivedAnimated = animated
            return .handled
        }

        XCTAssertEqual(receivedIndexes, [42])
        XCTAssertEqual(receivedAnchor, .center)
        XCTAssertTrue(receivedAnimated)
    }

    func testProxyKeepsQueuedRequestUntilCompatibleViewConnects() {
        let coordinator = InfiniteScrollViewProxyCoordinator()
        let proxy = InfiniteScrollViewProxy(coordinator: coordinator)
        var receivedIndex: Int?

        proxy.scrollTo(7)
        coordinator.connect(animated: false) { index, _, _ in
            index is String ? .handled : .incompatible
        }
        coordinator.connect(animated: false) { index, _, _ in
            guard let index = index as? Int else { return .incompatible }
            receivedIndex = index
            return .handled
        }

        XCTAssertEqual(receivedIndex, 7)
    }

    func testProxyDeliversRepeatedRequests() {
        let coordinator = InfiniteScrollViewProxyCoordinator()
        let proxy = InfiniteScrollViewProxy(coordinator: coordinator)
        var receivedIndexes = [Int]()

        func deliverPendingRequest() {
            coordinator.connect(animated: false) { index, _, _ in
                guard let index = index as? Int else { return .incompatible }
                receivedIndexes.append(index)
                return .handled
            }
        }

        proxy.scrollTo(5)
        deliverPendingRequest()
        proxy.scrollTo(5)
        deliverPendingRequest()

        XCTAssertEqual(receivedIndexes, [5, 5])
    }

    func testProxyRequestsSwiftUIUpdateForEveryScroll() {
        let coordinator = InfiniteScrollViewProxyCoordinator()
        var updateCount = 0
        let proxy = InfiniteScrollViewProxy(coordinator: coordinator) {
            updateCount += 1
        }

        proxy.scrollTo(1)
        proxy.scrollTo(2)

        XCTAssertEqual(updateCount, 2)
        coordinator.connect(animated: false) { index, _, _ in
            guard let index = index as? Int else { return .incompatible }
            XCTAssertEqual(index, 2)
            return .handled
        }
    }
#endif

#if os(macOS)
    func testReaderProxyScrollsContainedInfiniteScrollView() throws {
        var proxy: InfiniteScrollViewProxy?
        var renderedIndexes = [Int]()
        let reader = InfiniteScrollViewReader { readerProxy in
            proxy = readerProxy
            return InfiniteScrollView(
                changeIndex: 0,
                increaseIndexAction: { $0 + 1 },
                decreaseIndexAction: { $0 - 1 },
                orientation: .vertical
            ) { index in
                TrackingContent(index: index) {
                    renderedIndexes.append($0)
                }
            }
            .frame(width: 200, height: 100)
        }
        let hostingView = NSHostingView(rootView: reader)
        hostingView.frame = CGRect(x: 0, y: 0, width: 200, height: 100)
        hostingView.layoutSubtreeIfNeeded()
        let scrollView = try XCTUnwrap(
            firstSubview(of: NSInfiniteScrollView<Int>.self, in: hostingView)
        )

        let oldContentView = try XCTUnwrap(scrollView.documentView?.subviews.first)
        withAnimation {
            proxy?.scrollTo(99)
        }
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        hostingView.layoutSubtreeIfNeeded()

        XCTAssertTrue(renderedIndexes.contains(99))
        XCTAssertNotNil(oldContentView.superview)
    }

    func testScrollToIndexPlacesVerticalContentAtLeadingEdge() throws {
        let scrollView = makeScrollView(orientation: .vertical)
        scrollView.layout()

        scrollView.scroll(to: 10_000)

        let targetView = try XCTUnwrap(indexedView(for: 10_000, in: scrollView))
        XCTAssertEqual(targetView.frame.minY, scrollView.documentVisibleRect.minY, accuracy: 0.001)
    }

    func testScrollToIndexPlacesHorizontalContentAtLeadingEdge() throws {
        let scrollView = makeScrollView(orientation: .horizontal)
        scrollView.layout()

        scrollView.scroll(to: -10_000)

        let targetView = try XCTUnwrap(indexedView(for: -10_000, in: scrollView))
        XCTAssertEqual(targetView.frame.minX, scrollView.documentVisibleRect.minX, accuracy: 0.001)
    }

    func testScrollToIndexCentersVerticalContent() throws {
        let scrollView = makeScrollView(orientation: .vertical)
        scrollView.layout()

        scrollView.scroll(to: 100, anchor: .center)

        let targetView = try XCTUnwrap(indexedView(for: 100, in: scrollView))
        XCTAssertEqual(targetView.frame.midY, scrollView.documentVisibleRect.midY, accuracy: 0.001)
    }

    func testScrollToIndexPlacesVerticalContentAtTrailingEdge() throws {
        let scrollView = makeScrollView(orientation: .vertical)
        scrollView.layout()

        scrollView.scroll(to: 100, anchor: .trailing)

        let targetView = try XCTUnwrap(indexedView(for: 100, in: scrollView))
        XCTAssertEqual(targetView.frame.maxY, scrollView.documentVisibleRect.maxY, accuracy: 0.001)
    }

    func testScrollToIndexCentersHorizontalContent() throws {
        let scrollView = makeScrollView(orientation: .horizontal)
        scrollView.layout()

        scrollView.scroll(to: 100, anchor: .center)

        let targetView = try XCTUnwrap(indexedView(for: 100, in: scrollView))
        XCTAssertEqual(targetView.frame.midX, scrollView.documentVisibleRect.midX, accuracy: 0.001)
    }

    func testScrollToIndexPlacesHorizontalContentAtTrailingEdge() throws {
        let scrollView = makeScrollView(orientation: .horizontal)
        scrollView.layout()

        scrollView.scroll(to: 100, anchor: .trailing)

        let targetView = try XCTUnwrap(indexedView(for: 100, in: scrollView))
        XCTAssertEqual(targetView.frame.maxX, scrollView.documentVisibleRect.maxX, accuracy: 0.001)
    }

    func testScrollToIndexCanRepeatTheSameIndex() throws {
        let scrollView = makeScrollView(orientation: .vertical)
        scrollView.layout()
        scrollView.scroll(to: 42)
        let firstTargetView = try XCTUnwrap(indexedView(for: 42, in: scrollView))

        scrollView.scroll(to: 42)

        let secondTargetView = try XCTUnwrap(indexedView(for: 42, in: scrollView))
        XCTAssertTrue(firstTargetView === secondTargetView)
        XCTAssertEqual(secondTargetView.frame.minY, scrollView.documentVisibleRect.minY, accuracy: 0.001)
    }

    func testScrollToIndexRepositionsSameIndexForDifferentAnchor() throws {
        let scrollView = makeScrollView(orientation: .vertical)
        scrollView.layout()
        scrollView.scroll(to: 42)
        let leadingTargetView = try XCTUnwrap(indexedView(for: 42, in: scrollView))

        scrollView.scroll(to: 42, anchor: .center)

        let centeredTargetView = try XCTUnwrap(indexedView(for: 42, in: scrollView))
        XCTAssertFalse(leadingTargetView === centeredTargetView)
        XCTAssertEqual(centeredTargetView.frame.midY, scrollView.documentVisibleRect.midY, accuracy: 0.001)
    }

    func testNilAnchorDoesNotRepositionVisibleIndex() throws {
        let scrollView = makeScrollView(orientation: .vertical)
        scrollView.layout()
        scrollView.scroll(to: 42, anchor: .center)
        let centeredTargetView = try XCTUnwrap(indexedView(for: 42, in: scrollView))

        scrollView.scroll(to: 42)

        let unchangedTargetView = try XCTUnwrap(indexedView(for: 42, in: scrollView))
        XCTAssertTrue(centeredTargetView === unchangedTargetView)
        XCTAssertEqual(unchangedTargetView.frame.midY, scrollView.documentVisibleRect.midY, accuracy: 0.001)
    }

    func testNilAnchorScrollsPartiallyVisibleIndexFullyIntoView() throws {
        let scrollView = makeScrollView(orientation: .vertical)
        scrollView.layout()
        scrollView.scroll(to: 42)
        let targetView = try XCTUnwrap(indexedView(for: 42, in: scrollView))
        targetView.frame.origin.y = scrollView.documentVisibleRect.maxY - 1

        scrollView.scroll(to: 42)

        let fullyVisibleTargetView = try XCTUnwrap(indexedView(for: 42, in: scrollView))
        XCTAssertFalse(targetView === fullyVisibleTargetView)
        XCTAssertTrue(scrollView.documentVisibleRect.contains(fullyVisibleTargetView.frame))
    }

    func testScrollToIndexWaitsForAValidViewport() throws {
        let scrollView = makeScrollView(frame: .zero, orientation: .vertical)

        scrollView.scroll(to: 7)
        XCTAssertNil(indexedView(for: 7, in: scrollView))

        scrollView.translatesAutoresizingMaskIntoConstraints = true
        scrollView.frame = CGRect(x: 0, y: 0, width: 200, height: 100)
        scrollView.layout()

        let targetView = try XCTUnwrap(indexedView(for: 7, in: scrollView))
        XCTAssertEqual(targetView.frame.minY, scrollView.documentVisibleRect.minY, accuracy: 0.001)
    }

    private func makeScrollView(
        frame: CGRect = CGRect(x: 0, y: 0, width: 200, height: 100),
        orientation: NSInfiniteScrollView<Int>.Orientation
    ) -> NSInfiniteScrollView<Int> {
        NSInfiniteScrollView(
            frame: frame,
            content: { IndexedView(index: $0) },
            changeIndex: 0,
            changeIndexIncreaseAction: { $0 + 1 },
            changeIndexDecreaseAction: { $0 - 1 },
            indexesEqual: ==,
            orientation: orientation,
            refreshAction: nil,
            spacing: 8
        )
    }

    private func indexedView(
        for index: Int,
        in scrollView: NSInfiniteScrollView<Int>
    ) -> IndexedView? {
        scrollView.documentView?.subviews
            .compactMap { $0 as? IndexedView }
            .first { $0.index == index }
    }

    private func firstSubview<T: NSView>(of type: T.Type, in view: NSView) -> T? {
        if let matchingView = view as? T {
            return matchingView
        }
        for subview in view.subviews {
            if let matchingView = firstSubview(of: type, in: subview) {
                return matchingView
            }
        }
        return nil
    }
#endif
}

#if os(macOS)
private final class IndexedView: NSView {
    let index: Int

    override var fittingSize: NSSize {
        NSSize(width: 40, height: 30)
    }

    init(index: Int) {
        self.index = index
        super.init(frame: CGRect(x: 0, y: 0, width: 40, height: 30))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private struct TrackingContent: View {
    var body: some View {
        Color.clear.frame(width: 200, height: 30)
    }

    init(index: Int, onCreate: (Int) -> Void) {
        onCreate(index)
    }
}
#endif
