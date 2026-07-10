import SwiftData
import SwiftUI
import UniformTypeIdentifiers
import UIKit
import UserNotifications

struct DDayListView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("appLanguage") private var appLanguageRawValue = DaycoLanguage.korean.rawValue
    @Query(sort: \DDayItem.date)
    private var items: [DDayItem]

    @State private var isPresentingEditor = false
    @State private var isPresentingSettings = false
    @State private var isPresentingCalendar = false
    @State private var isPresentingNotifications = false
    @State private var isPresentingSearch = false
    @State private var editingItem: DDayItem?
    @State private var isReordering = false
    @State private var draggedItem: DDayItem?
    @State private var activeReorderItemID: UUID?
    @State private var reorderDragOffset: CGFloat = 0
    @State private var reorderStartIndex: Int?
    @State private var lastReorderTargetIndex: Int?
    @State private var reorderConsumedDragHeight: CGFloat = 0
    @State private var reorderRowHeights: [UUID: CGFloat] = [:]
    @State private var lastReorderAutoScrollAt = Date.distantPast
    @State private var itemPendingDeletion: DDayItem?
    @State private var isConfirmingDeletion = false

    private let calculator = DDayCalculator()

    var body: some View {
        ZStack(alignment: .bottom) {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                MainHeaderView(
                    isReordering: isReordering,
                    notificationAction: { isPresentingNotifications = true },
                    searchAction: { isPresentingSearch = true },
                    doneAction: { stopReordering() }
                )
                .padding(.horizontal, 18)
                .padding(.bottom, 12)
                .background(Color(.systemGroupedBackground))
                .zIndex(1)

                if isReordering {
                    reorderableContent
                } else {
                    listContent
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            BottomContentFade()
                .frame(height: 128)
                .allowsHitTesting(false)

            BottomActionBar(
                calendarAction: { if !isReordering { isPresentingCalendar = true } },
                addAction: { if !isReordering { isPresentingEditor = true } },
                profileAction: { if !isReordering { isPresentingSettings = true } }
            )
            .padding(.bottom, 16)

            TopSafeAreaSolidBackground()
                .allowsHitTesting(false)
                .zIndex(10)
        }
        .sheet(isPresented: $isPresentingEditor) {
            DDayEditorView()
        }
        .sheet(item: $editingItem) { item in
            DDayEditorView(item: item)
        }
        .sheet(isPresented: $isPresentingSettings) {
            SettingsView()
        }
        .sheet(isPresented: $isPresentingCalendar) {
            DDayCalendarView(items: sortedItems) { item in
                isPresentingCalendar = false
                editingItem = item
            }
        }
        .sheet(isPresented: $isPresentingSearch) {
            DDaySearchView(items: sortedItems) { item in
                isPresentingSearch = false
                editingItem = item
            }
        }
        .sheet(isPresented: $isPresentingNotifications) {
            NotificationInboxView(items: sortedItems) { item in
                isPresentingNotifications = false
                editingItem = item
            }
        }
        .alert(DaycoText.t("삭제하시겠습니까?"), isPresented: $isConfirmingDeletion) {
            Button(DaycoText.t("취소"), role: .cancel) {
                itemPendingDeletion = nil
            }
            Button(DaycoText.t("삭제"), role: .destructive) {
                if let item = itemPendingDeletion {
                    deleteItem(item)
                }
                itemPendingDeletion = nil
            }
        } message: {
            Text(DaycoText.t("이 디데이는 복구할 수 없습니다."))
        }
        .onAppear {
            WidgetSnapshotService.update(with: sortedItems)
            rescheduleAllNotifications()
            removeDeliveredNotifications()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            removeDeliveredNotifications()
        }
        .onChange(of: widgetSnapshotSignature) {
            WidgetSnapshotService.update(with: sortedItems)
        }
    }

    private var listContent: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if sortedItems.isEmpty {
                    EmptyDDayCard {
                        isPresentingEditor = true
                    }
                    .padding(.horizontal, 18)
                } else {
                    ForEach(sortedItems) { item in
                        SwipeableDDayCardRow(
                            item: item,
                            calculation: calculator.calculate(item: item),
                            language: appLanguage,
                            editAction: { editingItem = item },
                            reorderAction: { startReordering() },
                            pinAction: { togglePinned(item) },
                            deleteAction: {
                                itemPendingDeletion = item
                                isConfirmingDeletion = true
                            }
                        )
                        .padding(.horizontal, 18)
                        .padding(.vertical, 7)
                    }
                }
            }
            .padding(.bottom, 132)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .scrollIndicators(.hidden)
        .animation(.snappy(duration: 0.38, extraBounce: 0.08), value: sortedItemIDs)
    }

    private var reorderableContent: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(sortedItems.enumerated()), id: \.element.id) { index, item in
                        let isActive = activeReorderItemID == item.id

                        DDayCardView(item: item, calculation: calculator.calculate(item: item), language: appLanguage)
                            .wiggling(true, seed: wiggleSeed(for: item))
                            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .padding(.horizontal, 18)
                            .padding(.vertical, 7)
                            .background {
                                GeometryReader { rowProxy in
                                    Color.clear
                                        .preference(
                                            key: ReorderRowHeightPreferenceKey.self,
                                            value: [item.id: rowProxy.size.height]
                                        )
                                }
                            }
                            .id(item.id)
                            .scaleEffect(isActive ? 1.025 : 1)
                            .shadow(color: .black.opacity(isActive ? 0.16 : 0), radius: isActive ? 14 : 0, y: isActive ? 8 : 0)
                            .offset(y: isActive ? reorderDragOffset : 0)
                            .zIndex(isActive ? 1 : 0)
                            .onTapGesture {
                                stopReordering()
                            }
                            .overlay {
                                ReorderInteractionOverlay(
                                    onBegin: {
                                        beginReorderDrag(for: item, fallbackIndex: index)
                                    },
                                    onChange: { translation, location in
                                        updateReorderDrag(for: item, translationHeight: translation.height, locationY: location.y, scrollProxy: proxy)
                                    },
                                    onEnd: {
                                        endReorderDrag()
                                    }
                                )
                            }
                    }
                }
                .padding(.bottom, 132)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .scrollIndicators(.hidden)
            .animation(activeReorderItemID == nil ? .smooth(duration: 0.25) : nil, value: sortedItemIDs)
            .onPreferenceChange(ReorderRowHeightPreferenceKey.self) { heights in
                reorderRowHeights.merge(heights) { _, newValue in newValue }
            }
        }
    }

    private func deleteItem(_ item: DDayItem) {
        Task { @MainActor in
            await NotificationScheduler().removeNotifications(for: item)
        }
        modelContext.delete(item)
    }

    private func rescheduleAllNotifications() {
        Task { @MainActor in
            for item in sortedItems {
                await NotificationScheduler().rescheduleNotifications(for: item)
            }
        }
    }

    private func removeDeliveredNotifications() {
        Task { @MainActor in
            await NotificationScheduler().removeDeliveredDaycoNotifications(for: sortedItems)
        }
    }

    private func togglePinned(_ item: DDayItem) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.45)
        withAnimation(.snappy(duration: 0.42, extraBounce: 0.08)) {
            item.isPinned.toggle()
            item.updatedAt = .now
            movePinnedItemIntoPlace(item)
        }
    }

    private func startReordering() {
        guard !isReordering else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            isReordering = true
        }
    }

    private func stopReordering() {
        guard isReordering else { return }
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            isReordering = false
            draggedItem = nil
            activeReorderItemID = nil
            reorderDragOffset = 0
            reorderStartIndex = nil
            lastReorderTargetIndex = nil
            reorderConsumedDragHeight = 0
            reorderRowHeights = [:]
            lastReorderAutoScrollAt = .distantPast
        }
    }

    private func moveDraggedItem(_ draggedItem: DDayItem, to destination: Int) {
        var reorderedItems = sortedItems
        guard let sourceIndex = reorderedItems.firstIndex(where: { $0.id == draggedItem.id }) else {
            return
        }

        let adjustedDestination = sourceIndex < destination ? destination - 1 : destination
        let boundedInsertionIndex = max(0, min(adjustedDestination, reorderedItems.count - 1))
        guard boundedInsertionIndex != sourceIndex else { return }

        withAnimation(.smooth(duration: 0.25)) {
            let movingItem = reorderedItems.remove(at: sourceIndex)
            reorderedItems.insert(movingItem, at: boundedInsertionIndex)
            applySortIndexes(to: reorderedItems)
        }
    }

    private func moveDraggedItem(_ draggedItem: DDayItem, toFinalIndex finalIndex: Int) {
        var reorderedItems = sortedItems
        guard let sourceIndex = reorderedItems.firstIndex(where: { $0.id == draggedItem.id }) else {
            return
        }

        let boundedIndex = max(0, min(finalIndex, reorderedItems.count - 1))
        guard boundedIndex != sourceIndex else { return }

        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            let movingItem = reorderedItems.remove(at: sourceIndex)
            reorderedItems.insert(movingItem, at: boundedIndex)
            applySortIndexes(to: reorderedItems)
        }
    }

    private func beginReorderDrag(for item: DDayItem, fallbackIndex: Int) {
        guard activeReorderItemID == nil else { return }
        activeReorderItemID = item.id
        reorderStartIndex = sortedItems.firstIndex(where: { $0.id == item.id }) ?? fallbackIndex
        lastReorderTargetIndex = reorderStartIndex
        reorderConsumedDragHeight = 0
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func updateReorderDrag(for item: DDayItem, translationHeight: CGFloat, locationY: CGFloat, scrollProxy: ScrollViewProxy) {
        guard activeReorderItemID == item.id else { return }

        let activeRowHeight = measuredRowHeight(for: item)
        let swapThreshold = activeRowHeight * 0.58
        let relativeDrag = translationHeight - reorderConsumedDragHeight

        reorderDragOffset = relativeDrag

        guard let currentIndex = sortedItems.firstIndex(where: { $0.id == item.id }) else {
            return
        }

        if relativeDrag > swapThreshold, currentIndex < sortedItems.count - 1 {
            let nextIndex = currentIndex + 1
            let crossedItem = sortedItems[nextIndex]
            reorderConsumedDragHeight += measuredRowHeight(for: crossedItem)
            reorderDragOffset = translationHeight - reorderConsumedDragHeight
            lastReorderTargetIndex = nextIndex
            moveDraggedItem(item, toFinalIndex: nextIndex)
            UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.55)
        } else if relativeDrag < -swapThreshold, currentIndex > 0 {
            let previousIndex = currentIndex - 1
            let crossedItem = sortedItems[previousIndex]
            reorderConsumedDragHeight -= measuredRowHeight(for: crossedItem)
            reorderDragOffset = translationHeight - reorderConsumedDragHeight
            lastReorderTargetIndex = previousIndex
            moveDraggedItem(item, toFinalIndex: previousIndex)
            UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.55)
        }
    }

    private func endReorderDrag() {
        withAnimation(.smooth(duration: 0.18)) {
            reorderDragOffset = 0
            activeReorderItemID = nil
            reorderStartIndex = nil
            lastReorderTargetIndex = nil
            reorderConsumedDragHeight = 0
            lastReorderAutoScrollAt = .distantPast
        }
    }

    private func measuredRowHeight(for item: DDayItem) -> CGFloat {
        reorderRowHeights[item.id] ?? 118
    }

    private func handleReorderAutoScroll(for item: DDayItem, locationY: CGFloat, scrollProxy: ScrollViewProxy) {
        let now = Date()
        guard now.timeIntervalSince(lastReorderAutoScrollAt) > 0.2 else { return }
        guard let currentIndex = sortedItems.firstIndex(where: { $0.id == item.id }) else { return }

        let screenHeight = UIScreen.main.bounds.height
        let topTrigger: CGFloat = 170
        let bottomTrigger = screenHeight - 190

        if locationY < topTrigger, currentIndex > 0 {
            lastReorderAutoScrollAt = now
            let targetIndex = max(0, currentIndex - 1)
            withAnimation(.smooth(duration: 0.22)) {
                scrollProxy.scrollTo(sortedItems[targetIndex].id, anchor: .top)
            }
        } else if locationY > bottomTrigger, currentIndex < sortedItems.count - 1 {
            lastReorderAutoScrollAt = now
            let targetIndex = min(sortedItems.count - 1, currentIndex + 1)
            withAnimation(.smooth(duration: 0.22)) {
                scrollProxy.scrollTo(sortedItems[targetIndex].id, anchor: .bottom)
            }
        }
    }

    private func destinationForCardDrop(draggedItem: DDayItem, targetIndex: Int) -> Int {
        guard let sourceIndex = sortedItems.firstIndex(where: { $0.id == draggedItem.id }) else {
            return targetIndex
        }

        return sourceIndex < targetIndex ? targetIndex + 1 : targetIndex
    }

    private func wiggleSeed(for item: DDayItem) -> Double {
        Double(abs(item.id.uuidString.hashValue % 1000)) / 100.0
    }

    private func movePinnedItemIntoPlace(_ item: DDayItem) {
        var reorderedItems = sortedItems.filter { $0.id != item.id }
        let insertionIndex: Int

        if item.isPinned {
            insertionIndex = reorderedItems.firstIndex { !$0.isPinned } ?? reorderedItems.count
        } else {
            insertionIndex = reorderedItems.firstIndex { other in
                !other.isPinned && item.date < other.date
            } ?? reorderedItems.count
        }

        reorderedItems.insert(item, at: insertionIndex)
        applySortIndexes(to: reorderedItems)
    }

    private func applySortIndexes(to reorderedItems: [DDayItem]) {
        for (index, item) in reorderedItems.enumerated() {
            item.sortIndex = Double(index)
            item.updatedAt = .now
        }
    }

    private var sortedItemIDs: [UUID] {
        sortedItems.map(\.id)
    }

    private var sortedItems: [DDayItem] {
        items.sorted {
            if $0.isPinned != $1.isPinned {
                return $0.isPinned && !$1.isPinned
            }

            let leftIndex = $0.sortIndex ?? $0.date.timeIntervalSinceReferenceDate
            let rightIndex = $1.sortIndex ?? $1.date.timeIntervalSinceReferenceDate
            if leftIndex != rightIndex {
                return leftIndex < rightIndex
            }

            return $0.createdAt < $1.createdAt
        }
    }

    private var appLanguage: DaycoLanguage {
        DaycoLanguage(rawValue: appLanguageRawValue) ?? .korean
    }

    private var widgetSnapshotSignature: String {
        ([appLanguageRawValue] + sortedItems.map { item in
            [
                item.id.uuidString,
                item.title,
                "\(item.date.timeIntervalSinceReferenceDate)",
                item.typeRawValue,
                item.repeatRuleRawValue ?? "",
                "\(item.countStartAsDayOne)",
                item.displayUnitRawValue,
                "\(item.isPinned)",
                "\(item.isShared)",
                item.cardColorRawValue ?? "",
                "\(item.sortIndex ?? -1)",
                "\(item.updatedAt.timeIntervalSinceReferenceDate)"
            ].joined(separator: "|")
        })
        .joined(separator: "\n")
    }
}

private struct TopSafeAreaSolidBackground: View {
    var body: some View {
        GeometryReader { proxy in
            Color(.systemGroupedBackground)
                .frame(height: proxy.safeAreaInsets.top + 2)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .ignoresSafeArea(edges: .top)
        }
    }
}

private struct ReorderRowHeightPreferenceKey: PreferenceKey {
    static let defaultValue: [UUID: CGFloat] = [:]

    static func reduce(value: inout [UUID: CGFloat], nextValue: () -> [UUID: CGFloat]) {
        value.merge(nextValue()) { _, newValue in newValue }
    }
}

private struct ReorderDropZone: View {
    let index: Int
    @Binding var draggedItem: DDayItem?
    let moveAction: (DDayItem, Int) -> Void

    var body: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.001))
            .frame(height: 24)
            .contentShape(Rectangle())
            .onDrop(
                of: [UTType.text],
                delegate: ReorderDropDelegate(
                    index: index,
                    draggedItem: $draggedItem,
                    moveAction: moveAction
                )
            )
    }
}

private struct ReorderCardDropDelegate: DropDelegate {
    let targetIndex: Int
    @Binding var draggedItem: DDayItem?
    let destinationAction: (DDayItem, Int) -> Int
    let moveAction: (DDayItem, Int) -> Void

    func dropEntered(info: DropInfo) {
        moveIfNeeded()
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        moveIfNeeded()
        return DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        moveIfNeeded()
        draggedItem = nil
        return true
    }

    private func moveIfNeeded() {
        guard let draggedItem else { return }
        moveAction(draggedItem, destinationAction(draggedItem, targetIndex))
    }
}

private struct ReorderDropDelegate: DropDelegate {
    let index: Int
    @Binding var draggedItem: DDayItem?
    let moveAction: (DDayItem, Int) -> Void

    func dropEntered(info: DropInfo) {
        moveIfNeeded()
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        moveIfNeeded()
        return DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        moveIfNeeded()
        draggedItem = nil
        return true
    }

    private func moveIfNeeded() {
        guard let draggedItem else { return }
        moveAction(draggedItem, index)
    }
}

private struct ReorderInteractionOverlay: UIViewRepresentable {
    let onBegin: () -> Void
    let onChange: (CGSize, CGPoint) -> Void
    let onEnd: () -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = true

        let longPressGesture = UILongPressGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleLongPress(_:))
        )
        longPressGesture.minimumPressDuration = 0.36
        longPressGesture.allowableMovement = 12
        longPressGesture.cancelsTouchesInView = false
        longPressGesture.delaysTouchesBegan = false
        longPressGesture.delaysTouchesEnded = false
        longPressGesture.delegate = context.coordinator
        view.addGestureRecognizer(longPressGesture)

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.parent = self
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var parent: ReorderInteractionOverlay
        private var startLocation: CGPoint?
        private weak var lockedScrollView: UIScrollView?
        private var previousScrollEnabled = true
        private var initialScrollOffsetY: CGFloat = 0
        private var latestWindowLocation: CGPoint?
        private var displayLink: CADisplayLink?

        init(parent: ReorderInteractionOverlay) {
            self.parent = parent
        }

        @objc func handleLongPress(_ recognizer: UILongPressGestureRecognizer) {
            let location = recognizer.location(in: nil)

            switch recognizer.state {
            case .began:
                startLocation = location
                latestWindowLocation = location
                lockParentScrollView(from: recognizer.view)
                startAutoScrollTicker()
                parent.onBegin()
            case .changed:
                guard let startLocation else { return }
                latestWindowLocation = location
                updateDrag(using: location, startLocation: startLocation)
            case .ended, .cancelled, .failed:
                startLocation = nil
                latestWindowLocation = nil
                stopAutoScrollTicker()
                unlockParentScrollView()
                parent.onEnd()
            default:
                break
            }
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            true
        }

        private func lockParentScrollView(from view: UIView?) {
            guard lockedScrollView == nil,
                  let scrollView = view?.firstSuperview(of: UIScrollView.self) else {
                return
            }

            previousScrollEnabled = scrollView.isScrollEnabled
            initialScrollOffsetY = scrollView.contentOffset.y
            scrollView.isScrollEnabled = false
            lockedScrollView = scrollView
        }

        private func unlockParentScrollView() {
            lockedScrollView?.isScrollEnabled = previousScrollEnabled
            lockedScrollView = nil
            previousScrollEnabled = true
            initialScrollOffsetY = 0
        }

        private func startAutoScrollTicker() {
            stopAutoScrollTicker()
            let displayLink = CADisplayLink(target: self, selector: #selector(handleAutoScrollTick))
            displayLink.add(to: .main, forMode: .common)
            self.displayLink = displayLink
        }

        private func stopAutoScrollTicker() {
            displayLink?.invalidate()
            displayLink = nil
        }

        @objc private func handleAutoScrollTick() {
            guard let startLocation,
                  let latestWindowLocation else {
                return
            }
            autoScrollIfNeeded(at: latestWindowLocation)
            updateDrag(using: latestWindowLocation, startLocation: startLocation)
        }

        private func updateDrag(using location: CGPoint, startLocation: CGPoint) {
            let scrollDelta = (lockedScrollView?.contentOffset.y ?? initialScrollOffsetY) - initialScrollOffsetY
            let translation = CGSize(
                width: location.x - startLocation.x,
                height: location.y - startLocation.y + scrollDelta
            )
            parent.onChange(translation, location)
        }

        private func autoScrollIfNeeded(at windowLocation: CGPoint) {
            guard let scrollView = lockedScrollView else { return }

            let location = scrollView.convert(windowLocation, from: nil)
            let visibleY = location.y - scrollView.bounds.minY
            let topZone: CGFloat = 132
            let bottomZone = max(topZone + 1, scrollView.bounds.height - 164)
            let minOffsetY = -scrollView.adjustedContentInset.top
            let maxOffsetY = max(
                minOffsetY,
                scrollView.contentSize.height - scrollView.bounds.height + scrollView.adjustedContentInset.bottom
            )

            let delta: CGFloat
            if visibleY < topZone {
                delta = -min(12, max(2, (topZone - visibleY) / 8))
            } else if visibleY > bottomZone {
                delta = min(12, max(2, (visibleY - bottomZone) / 8))
            } else {
                return
            }

            let nextOffsetY = min(maxOffsetY, max(minOffsetY, scrollView.contentOffset.y + delta))
            guard nextOffsetY != scrollView.contentOffset.y else { return }
            scrollView.setContentOffset(CGPoint(x: scrollView.contentOffset.x, y: nextOffsetY), animated: false)
        }
    }
}

private extension UIView {
    func firstSuperview<T: UIView>(of type: T.Type) -> T? {
        var currentSuperview = superview
        while let view = currentSuperview {
            if let typedView = view as? T {
                return typedView
            }
            currentSuperview = view.superview
        }
        return nil
    }
}

private struct StatusBarBackgroundInstaller: UIViewRepresentable {
    func makeUIView(context: Context) -> StatusBarBackgroundView {
        StatusBarBackgroundView()
    }

    func updateUIView(_ uiView: StatusBarBackgroundView, context: Context) {
        uiView.updateStatusBarCover()
    }
}

private final class StatusBarBackgroundView: UIView {
    private static let coverTag = 620_709

    override func didMoveToWindow() {
        super.didMoveToWindow()
        updateStatusBarCover()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateStatusBarCover()
    }

    func updateStatusBarCover() {
        guard let window else { return }

        let cover: UIView
        if let existingCover = window.viewWithTag(Self.coverTag) {
            cover = existingCover
        } else {
            let newCover = UIView()
            newCover.tag = Self.coverTag
            newCover.isUserInteractionEnabled = false
            newCover.autoresizingMask = [.flexibleWidth, .flexibleBottomMargin]
            window.addSubview(newCover)
            cover = newCover
        }

        let statusBarHeight = max(
            window.safeAreaInsets.top,
            window.windowScene?.statusBarManager?.statusBarFrame.height ?? 0
        )
        cover.backgroundColor = .systemGroupedBackground
        cover.frame = CGRect(x: 0, y: 0, width: window.bounds.width, height: statusBarHeight)
        window.bringSubviewToFront(cover)
    }
}

private struct SwipeableDDayCardRow: View {
    let item: DDayItem
    let calculation: DDayCalculation
    let language: DaycoLanguage
    let editAction: () -> Void
    let reorderAction: () -> Void
    let pinAction: () -> Void
    let deleteAction: () -> Void

    @State private var offset: CGFloat = 0
    @State private var dragStartOffset: CGFloat = 0
    @State private var didPassSwipeDetent = false
    @State private var isPressing = false

    private let actionWidth: CGFloat = 78
    private let actionGap: CGFloat = 18
    private let swipeActivationDistance: CGFloat = 42
    private let swipeResistance: CGFloat = 0.74

    private var revealOffset: CGFloat {
        actionWidth + actionGap
    }

    private var halfRevealOffset: CGFloat {
        revealOffset * 0.52
    }

    var body: some View {
        let leftProgress = max(0, min(1, offset / revealOffset))
        let rightProgress = max(0, min(1, -offset / revealOffset))

        ZStack {
            HStack(spacing: 8) {
                actionButton(
                    title: item.isPinned ? DaycoText.t("해제") : DaycoText.t("고정"),
                    systemName: item.isPinned ? "pin.slash.fill" : "pin.fill",
                    tint: .orange,
                    progress: leftProgress,
                    action: {
                        close()
                        pinAction()
                    }
                )

                Spacer(minLength: 0)

                actionButton(
                    title: DaycoText.t("삭제"),
                    systemName: "trash.fill",
                    tint: .red,
                    progress: rightProgress,
                    action: {
                        close()
                        deleteAction()
                    }
                )
            }
            .zIndex(0)

            DDayCardView(item: item, calculation: calculation, language: language)
                .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .scaleEffect(isPressing ? 0.975 : 1)
                .offset(x: offset)
                .zIndex(1)
                .overlay {
                    CardInteractionOverlay(
                        onTap: {
                            if abs(offset) < 1 {
                                editAction()
                            } else {
                                close()
                            }
                        },
                        onLongPressBegan: {
                            if abs(offset) < 1 {
                                isPressing = true
                                reorderAction()
                            }
                        },
                        onLongPressEnded: {
                            isPressing = false
                        },
                        onPanBegan: {
                            dragStartOffset = offset
                        },
                        onPanChanged: { translation in
                            updateSwipeOffset(with: translation)
                        },
                        onPanEnded: { translation, velocity in
                            finishSwipe(translation: translation, velocity: velocity)
                        }
                    )
                }

            HStack(spacing: 0) {
                actionHitArea(progress: leftProgress) {
                    close()
                    pinAction()
                }

                Spacer(minLength: 0)

                actionHitArea(progress: rightProgress) {
                    close()
                    deleteAction()
                }
            }
            .zIndex(2)
        }
        .animation(.interactiveSpring(response: 0.28, dampingFraction: 0.72, blendDuration: 0.05), value: offset)
        .animation(.smooth(duration: 0.12), value: isPressing)
    }

    private func updateSwipeOffset(with translation: CGPoint) {
        let horizontalAmount = abs(translation.x)
        let direction: CGFloat = translation.x >= 0 ? 1 : -1
        let activationDistance = abs(dragStartOffset) > 0 ? CGFloat(0) : swipeActivationDistance
        let activatedTranslation = max(0, horizontalAmount - activationDistance)
        let weightedTranslation = direction * activatedTranslation * swipeResistance
        let proposedOffset = dragStartOffset + weightedTranslation
        let clampedOffset: CGFloat

        if dragStartOffset > 0 {
            clampedOffset = min(revealOffset, max(0, proposedOffset))
        } else if dragStartOffset < 0 {
            clampedOffset = max(-revealOffset, min(0, proposedOffset))
        } else {
            clampedOffset = min(revealOffset, max(-revealOffset, proposedOffset))
        }

        let detentedOffset = detentedSwipeOffset(clampedOffset)
        offset = detentedOffset

        if abs(detentedOffset) >= halfRevealOffset, !didPassSwipeDetent {
            UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.45)
            didPassSwipeDetent = true
        } else if abs(detentedOffset) < halfRevealOffset * 0.7 {
            didPassSwipeDetent = false
        }
    }

    private func finishSwipe(translation: CGPoint, velocity: CGPoint) {
        let direction: CGFloat = (translation.x + velocity.x * 0.12) >= 0 ? 1 : -1
        let startOffset = dragStartOffset
        let activationDistance = abs(startOffset) > 0 ? CGFloat(0) : swipeActivationDistance
        let projectedTranslation = max(0, abs(translation.x + velocity.x * 0.12) - activationDistance)
        let projectedOffset = startOffset + direction * projectedTranslation * swipeResistance
        dragStartOffset = 0
        didPassSwipeDetent = false

        withAnimation(.interactiveSpring(response: 0.22, dampingFraction: 0.58, blendDuration: 0.03)) {
            if startOffset > 0, projectedOffset < revealOffset * 0.72 {
                offset = 0
            } else if startOffset < 0, projectedOffset > -revealOffset * 0.72 {
                offset = 0
            } else if projectedOffset > revealOffset * 0.64 {
                offset = revealOffset
                UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.55)
            } else if projectedOffset < -revealOffset * 0.64 {
                offset = -revealOffset
                UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.55)
            } else {
                offset = 0
            }
        }
    }

    private func detentedSwipeOffset(_ proposedOffset: CGFloat) -> CGFloat {
        let sign: CGFloat = proposedOffset >= 0 ? 1 : -1
        let absoluteOffset = abs(proposedOffset)
        let detentRange: CGFloat = 14
        let distanceFromDetent = abs(absoluteOffset - halfRevealOffset)

        guard distanceFromDetent < detentRange else {
            return proposedOffset
        }

        let pullThrough = (absoluteOffset - halfRevealOffset) * 0.22
        return sign * (halfRevealOffset + pullThrough)
    }

    private func actionButton(
        title: String,
        systemName: String,
        tint: Color,
        progress: CGFloat,
        action: @escaping () -> Void
    ) -> some View {
        let easedProgress = smoothProgress(progress)
        let isDelete = systemName.contains("trash")
        let iconLift = (1 - easedProgress) * 10
        let iconRotation = Angle.degrees(Double((1 - easedProgress) * (isDelete ? 10 : -10)))

        return Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(tint.gradient)
                    .shadow(color: tint.opacity(0.24 * easedProgress), radius: 10 * easedProgress, y: 4 * easedProgress)

                VStack(spacing: 6) {
                    Image(systemName: systemName)
                        .font(.system(size: 18 + easedProgress * 2, weight: .bold))
                        .rotationEffect(iconRotation)
                        .offset(y: iconLift)

                    Text(title)
                        .font(.caption2.weight(.bold))
                        .offset(y: (1 - easedProgress) * 8)
                        .opacity(max(0, (easedProgress - 0.25) / 0.75))
                }
                .foregroundStyle(.white)
            }
            .frame(width: actionWidth, height: 74)
            .opacity(easedProgress)
            .scaleEffect(x: 0.74 + easedProgress * 0.26, y: 0.86 + easedProgress * 0.14)
            .offset(x: (1 - easedProgress) * (isDelete ? 26 : -26))
        }
        .buttonStyle(.plain)
        .allowsHitTesting(progress > 0.25)
    }

    private func actionHitArea(progress: CGFloat, action: @escaping () -> Void) -> some View {
        Color.clear
            .frame(width: revealOffset, height: 92)
            .contentShape(Rectangle())
            .allowsHitTesting(progress > 0.86)
            .onTapGesture(perform: action)
    }

    private func smoothProgress(_ progress: CGFloat) -> CGFloat {
        let clamped = max(0, min(1, (progress - 0.05) / 0.95))
        return clamped * clamped * (3 - 2 * clamped)
    }

    private func close() {
        withAnimation(.interactiveSpring(response: 0.24, dampingFraction: 0.78, blendDuration: 0.05)) {
            offset = 0
            dragStartOffset = 0
            didPassSwipeDetent = false
        }
    }
}

private struct CardInteractionOverlay: UIViewRepresentable {
    let onTap: () -> Void
    let onLongPressBegan: () -> Void
    let onLongPressEnded: () -> Void
    let onPanBegan: () -> Void
    let onPanChanged: (CGPoint) -> Void
    let onPanEnded: (CGPoint, CGPoint) -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear

        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        tapGesture.cancelsTouchesInView = false
        view.addGestureRecognizer(tapGesture)

        let longPressGesture = UILongPressGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleLongPress(_:)))
        longPressGesture.minimumPressDuration = 0.42
        longPressGesture.cancelsTouchesInView = false
        view.addGestureRecognizer(longPressGesture)

        let panGesture = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        panGesture.minimumNumberOfTouches = 1
        panGesture.maximumNumberOfTouches = 1
        panGesture.cancelsTouchesInView = false
        panGesture.delegate = context.coordinator
        view.addGestureRecognizer(panGesture)

        tapGesture.require(toFail: longPressGesture)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.parent = self
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var parent: CardInteractionOverlay

        init(parent: CardInteractionOverlay) {
            self.parent = parent
        }

        @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard recognizer.state == .ended else { return }
            parent.onTap()
        }

        @objc func handleLongPress(_ recognizer: UILongPressGestureRecognizer) {
            switch recognizer.state {
            case .began:
                parent.onLongPressBegan()
            case .ended:
                parent.onLongPressEnded()
            case .cancelled, .failed:
                parent.onLongPressEnded()
            default:
                break
            }
        }

        @objc func handlePan(_ recognizer: UIPanGestureRecognizer) {
            let translation = recognizer.translation(in: recognizer.view)
            let velocity = recognizer.velocity(in: recognizer.view)
            let translationPoint = CGPoint(x: translation.x, y: translation.y)
            let velocityPoint = CGPoint(x: velocity.x, y: velocity.y)

            switch recognizer.state {
            case .began:
                parent.onPanBegan()
            case .changed:
                parent.onPanChanged(translationPoint)
            case .ended, .cancelled, .failed:
                parent.onPanEnded(translationPoint, velocityPoint)
            default:
                break
            }
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let panGesture = gestureRecognizer as? UIPanGestureRecognizer else {
                return true
            }

            let velocity = panGesture.velocity(in: panGesture.view)
            return abs(velocity.x) > abs(velocity.y) * 1.35
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            false
        }
    }
}

private struct MainHeaderView: View {
    let isReordering: Bool
    let notificationAction: () -> Void
    let searchAction: () -> Void
    let doneAction: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Dayco")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                Text(formattedToday)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isReordering {
                Button(DaycoText.t("완료"), action: doneAction)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 16)
                    .frame(height: 44)
                    .background(Color(.secondarySystemGroupedBackground), in: Capsule())
                    .padding(.top, 4)
            } else {
                HStack(spacing: 10) {
                    HeaderIconButton(systemName: "magnifyingglass", accessibilityLabel: DaycoText.t("검색"), action: searchAction)
                    HeaderIconButton(systemName: "bell", accessibilityLabel: DaycoText.t("알림"), action: notificationAction)
                }
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 10)
    }

    private var formattedToday: String {
        DaycoText.t("오늘 날짜") + " " + Self.dateFormatter.string(from: .now)
    }

    private static var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: DaycoText.language.localeIdentifier)
        formatter.dateFormat = DaycoText.language == .english ? "EEEE, MMM d, yyyy" : "yyyy년 M월 d일 EEEE"
        return formatter
    }
}

private struct HeaderIconButton: View {
    let systemName: String
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 23, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 34, height: 34)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

private struct BottomActionBar: View {
    let calendarAction: () -> Void
    let addAction: () -> Void
    let profileAction: () -> Void

    var body: some View {
        HStack(spacing: 28) {
            BottomCircleButton(systemName: "calendar", size: 58, background: Color(.secondarySystemGroupedBackground), action: calendarAction)
                .accessibilityLabel(DaycoText.t("달력"))

            BottomCircleButton(systemName: "plus", size: 70, background: .tint, action: addAction)
                .accessibilityLabel(DaycoText.t("디데이 추가"))

            BottomCircleButton(systemName: "person", size: 58, background: Color(.secondarySystemGroupedBackground), action: profileAction)
                .accessibilityLabel(DaycoText.t("개인 설정"))
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 8)
    }
}

private struct BottomContentFade: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(.systemGroupedBackground).opacity(0),
                Color(.systemGroupedBackground).opacity(0.82),
                Color(.systemGroupedBackground)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea(edges: .bottom)
    }
}

private struct BottomCircleButton: View {
    let systemName: String
    let size: CGFloat
    let background: AnyShapeStyle
    let action: () -> Void

    init<S: ShapeStyle>(systemName: String, size: CGFloat, background: S, action: @escaping () -> Void) {
        self.systemName = systemName
        self.size = size
        self.background = AnyShapeStyle(background)
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size == 70 ? 30 : 24, weight: .semibold))
                .foregroundStyle(size == 70 ? .white : .primary)
                .frame(width: size, height: size)
                .background(background, in: Circle())
                .shadow(color: .black.opacity(0.14), radius: 12, y: 5)
        }
        .buttonStyle(.plain)
    }
}

private struct EmptyDDayCard: View {
    let addAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(.tint)

            VStack(alignment: .leading, spacing: 6) {
                Text(DaycoText.t("아직 등록된 디데이가 없어요"))
                    .font(.system(size: 22, weight: .bold, design: .rounded))

                Text(DaycoText.t("중요한 날짜를 추가하고 오늘부터 바로 확인해보세요."))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Button(DaycoText.t("첫 디데이 추가"), action: addAction)
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct DDayCardView: View {
    let item: DDayItem
    let calculation: DDayCalculation
    let language: DaycoLanguage

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    if item.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.caption)
                            .foregroundStyle(item.cardSecondaryColor)
                    }

                    if !item.notificationRules.isEmpty {
                        Image(systemName: "bell.fill")
                            .font(.caption)
                            .foregroundStyle(item.cardSecondaryColor)
                    }
                }

                Text(item.title)
                    .font(.headline)
                    .foregroundStyle(item.cardForegroundColor)
                    .lineLimit(2)

                Text(calculation.valueText)
                    .font(.system(size: 34, weight: .black))
                    .foregroundStyle(item.cardForegroundColor)
                    .monospacedDigit()
                    .minimumScaleFactor(0.75)
                    .lineLimit(1)

                HStack(alignment: .firstTextBaseline) {
                    Text(calculation.caption)
                        .font(.subheadline)
                        .foregroundStyle(item.cardSecondaryColor)
                        .lineLimit(1)

                    Spacer()

                    DDayTypeBadge(type: item.type, language: language)
                        .font(.caption)
                        .foregroundStyle(item.cardSecondaryColor)
                        .lineLimit(1)
                }
            }
            .padding(18)

            if calculation.dayDelta == 0 {
                Text("🎉")
                    .font(.system(size: 30))
                    .padding(.top, 14)
                    .padding(.trailing, 16)
            }
        }
        .background(item.cardBackgroundColor, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        }
    }
}

private struct DDayTypeBadge: View {
    let type: DDayType
    let language: DaycoLanguage

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: type.symbolName)
            Text(type.title)
        }
        .id("\(type.rawValue)-\(language.rawValue)")
    }
}

private struct WiggleModifier: ViewModifier {
    let active: Bool
    let seed: Double

    func body(content: Content) -> some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let phase = timeline.date.timeIntervalSinceReferenceDate * 12.0 + seed
            let rotation = active ? sin(phase) * 0.75 : 0
            let horizontalOffset = active ? cos(phase * 0.72) * 0.55 : 0
            let verticalOffset = active ? sin(phase * 0.84) * 0.45 : 0

            content
                .rotationEffect(.degrees(rotation))
                .offset(x: horizontalOffset, y: verticalOffset)
                .animation(active ? nil : .smooth(duration: 0.15), value: active)
        }
    }
}

private extension View {
    func wiggling(_ active: Bool, seed: Double = 0) -> some View {
        modifier(WiggleModifier(active: active, seed: seed))
    }
}

private struct DDaySearchView: View {
    let items: [DDayItem]
    let selectItem: (DDayItem) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    var body: some View {
        NavigationStack {
            List(filteredItems) { item in
                Button {
                    selectItem(item)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title)
                            .foregroundStyle(.primary)
                        Text(item.date.formatted(.dateTime.year().month().day().locale(Locale(identifier: DaycoText.language.localeIdentifier))))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .overlay {
                if filteredItems.isEmpty {
                    ContentUnavailableView(DaycoText.t("검색 결과 없음"), systemImage: "magnifyingglass")
                }
            }
            .navigationTitle(DaycoText.t("검색"))
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, prompt: DaycoText.t("디데이 이름 검색"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(DaycoText.t("닫기")) {
                        dismiss()
                    }
                }
            }
        }
    }

    private var filteredItems: [DDayItem] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return items }
        return items.filter { $0.title.localizedStandardContains(trimmedQuery) }
    }
}

private struct NotificationInboxView: View {
    let items: [DDayItem]
    let selectItem: (DDayItem) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var pendingRequests: [UNNotificationRequest] = []

    var body: some View {
        NavigationStack {
            List {
                if notificationRows.isEmpty {
                    ContentUnavailableView(DaycoText.t("확인할 알림 없음"), systemImage: "bell")
                } else {
                    ForEach(notificationRows) { row in
                        Button {
                            selectItem(row.item)
                        } label: {
                            HStack(alignment: .top, spacing: 10) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(row.item.title)
                                        .foregroundStyle(.primary)
                                    Text(row.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(DaycoText.t("알림"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(DaycoText.t("닫기")) {
                        dismiss()
                    }
                }
            }
            .task {
                await refreshNotifications()
            }
        }
    }

    private var notificationRows: [NotificationRow] {
        let pendingIdentifiers = Set(pendingRequests.map(\.identifier))

        return items.flatMap { item in
            item.notificationRules.map { rule in
                let identifier = NotificationScheduler.notificationIdentifier(for: item, rule: rule)
                let status = pendingIdentifiers.contains(identifier) ? DaycoText.t("예약됨") : DaycoText.t("알림 규칙")
                return NotificationRow(
                    item: item,
                    subtitle: "\(item.notificationTitle(for: rule)) · \(status)"
                )
            }
        }
        .sorted {
            return $0.subtitle < $1.subtitle
        }
    }

    private func refreshNotifications() async {
        pendingRequests = await UNUserNotificationCenter.current().pendingNotificationRequests()
    }
}

private struct NotificationRow: Identifiable {
    let id = UUID()
    let item: DDayItem
    let subtitle: String
}

private struct DDayCalendarView: View {
    let items: [DDayItem]
    let selectItem: (DDayItem) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var displayedMonth = Calendar.current.startOfMonth(for: .now)
    @State private var selectedDate = Calendar.current.startOfDay(for: .now)
    @State private var focusedEventIndex = 0

    private let calculator = DDayCalculator()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                calendarPanel
                    .padding(.horizontal, 18)
                    .padding(.top, 12)
                    .padding(.bottom, 10)
                    .background(Color(.systemGroupedBackground))

                Divider()

                selectedDateItemsView
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Color(.systemGroupedBackground))
            .navigationTitle(DaycoText.t("디데이 달력"))
            .navigationBarTitleDisplayMode(.inline)
            .transaction { transaction in
                transaction.disablesAnimations = true
            }
            .onAppear {
                focusNearestEvent()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(DaycoText.t("닫기")) {
                        dismiss()
                    }
                }
            }
        }
    }

    private var calendarPanel: some View {
        VStack(spacing: 16) {
            HStack {
                Button {
                    moveMonth(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)

                Spacer()

                Text(monthTitle)
                    .font(.headline)
                    .frame(width: 132)
                    .monospacedDigit()

                Spacer()

                Button(DaycoText.t("오늘")) {
                    goToToday()
                }
                .font(.caption.weight(.semibold))
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button {
                    moveMonth(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
            }
            .frame(height: 38)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                ForEach(Self.weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(height: 16)
                }

                ForEach(calendarDays, id: \.self) { date in
                    let dateItems = items(on: date)
                    CalendarDayCell(
                        date: date,
                        displayedMonth: displayedMonth,
                        isSelected: Calendar.current.isDate(date, inSameDayAs: selectedDate),
                        items: dateItems
                    ) {
                        selectedDate = date
                    }
                    .frame(height: 43)
                }
            }
            .frame(height: 322)

            if !eventNavigationItems.isEmpty {
                EventJumpControl(
                    item: eventNavigationItems[focusedEventIndex],
                    date: itemDisplayDate(eventNavigationItems[focusedEventIndex]),
                    previousAction: { moveFocusedEvent(by: -1) },
                    nextAction: { moveFocusedEvent(by: 1) }
                )
            } else {
                Color.clear
                    .frame(height: 54)
            }
        }
        .frame(height: 446)
    }

    private var selectedDateItemsView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                Text(selectedDate.formatted(.dateTime.month().day().locale(Locale(identifier: DaycoText.language.localeIdentifier))))
                    .font(.headline)
                    .padding(.horizontal, 18)
                    .padding(.top, 16)

                if selectedDateItems.isEmpty {
                    Text(DaycoText.t("등록된 디데이 없음"))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ForEach(selectedDateItems) { item in
                        Button {
                            selectItem(item)
                        } label: {
                            HStack(spacing: 12) {
                                RoundedRectangle(cornerRadius: 3, style: .continuous)
                                    .fill(item.cardBackgroundColor)
                                    .frame(width: 5, height: 34)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.title)
                                        .foregroundStyle(.primary)
                                    Text(calculator.calculate(item: item).valueText)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 18)
                    }
                }
            }
            .padding(.bottom, 24)
        }
    }

    private var monthTitle: String {
        displayedMonth.formatted(.dateTime.year().month(.wide).locale(Locale(identifier: DaycoText.language.localeIdentifier)))
    }

    private var calendarDays: [Date] {
        let calendar = Calendar.current
        let firstWeekday = calendar.component(.weekday, from: displayedMonth)
        let leadingDays = firstWeekday - calendar.firstWeekday
        let normalizedLeadingDays = leadingDays >= 0 ? leadingDays : leadingDays + 7
        let gridStart = calendar.date(byAdding: .day, value: -normalizedLeadingDays, to: displayedMonth) ?? displayedMonth
        return (0..<42).compactMap { calendar.date(byAdding: .day, value: $0, to: gridStart) }
    }

    private func moveMonth(by value: Int) {
        let calendar = Calendar.current
        let nextMonth = calendar.date(byAdding: .month, value: value, to: displayedMonth) ?? displayedMonth
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            displayedMonth = calendar.startOfMonth(for: nextMonth)
            selectedDate = displayedMonth
        }
    }

    private func goToToday() {
        let today = Calendar.current.startOfDay(for: .now)
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            displayedMonth = Calendar.current.startOfMonth(for: today)
            selectedDate = today
        }
    }

    private var eventNavigationItems: [DDayItem] {
        items.sorted { itemDisplayDate($0) < itemDisplayDate($1) }
    }

    private func focusNearestEvent() {
        guard !eventNavigationItems.isEmpty else { return }
        let startOfToday = Calendar.current.startOfDay(for: .now)
        focusedEventIndex = eventNavigationItems
            .indices
            .min {
                abs(Calendar.current.dateComponents([.day], from: startOfToday, to: itemDisplayDate(eventNavigationItems[$0])).day ?? 0)
                    < abs(Calendar.current.dateComponents([.day], from: startOfToday, to: itemDisplayDate(eventNavigationItems[$1])).day ?? 0)
            } ?? 0
        jumpToFocusedEvent()
    }

    private func moveFocusedEvent(by value: Int) {
        guard !eventNavigationItems.isEmpty else { return }
        let count = eventNavigationItems.count
        focusedEventIndex = (focusedEventIndex + value + count) % count
        jumpToFocusedEvent()
    }

    private func jumpToFocusedEvent() {
        guard eventNavigationItems.indices.contains(focusedEventIndex) else { return }
        let date = itemDisplayDate(eventNavigationItems[focusedEventIndex])
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            displayedMonth = Calendar.current.startOfMonth(for: date)
            selectedDate = Calendar.current.startOfDay(for: date)
        }
    }

    private func items(on date: Date) -> [DDayItem] {
        let calendar = Calendar.current
        return items.filter { item in
            return calendar.isDate(itemDisplayDate(item), inSameDayAs: date)
        }
    }

    private var selectedDateItems: [DDayItem] {
        items(on: selectedDate)
    }

    private func itemDisplayDate(_ item: DDayItem) -> Date {
        calculator.resolvedTargetDate(for: item)
    }

    private static var weekdaySymbols: [String] {
        var calendar = Calendar.current
        calendar.locale = Locale(identifier: DaycoText.language.localeIdentifier)
        return calendar.shortStandaloneWeekdaySymbols
    }
}

private struct EventJumpControl: View {
    let item: DDayItem
    let date: Date
    let previousAction: () -> Void
    let nextAction: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: previousAction) {
                Image(systemName: "chevron.left")
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)

            VStack(spacing: 3) {
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .frame(height: 18)

                Text(date.formatted(.dateTime.year().month().day().locale(Locale(identifier: DaycoText.language.localeIdentifier))))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .frame(height: 16)
            }
            .frame(maxWidth: .infinity)

            Button(action: nextAction) {
                Image(systemName: "chevron.right")
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
        }
        .frame(height: 54)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(.tertiarySystemGroupedBackground), in: Capsule())
    }
}

private struct CalendarDayCell: View {
    let date: Date
    let displayedMonth: Date
    let isSelected: Bool
    let items: [DDayItem]
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text("\(Calendar.current.component(.day, from: date))")
                    .font(.system(.subheadline, design: .rounded, weight: isSelected ? .bold : .medium))
                    .frame(width: 34, height: 34)
                    .background(isSelected ? Color.accentColor : Color.clear, in: Circle())
                    .foregroundStyle(isSelected ? .white : dayTextColor)

                HStack(spacing: 2) {
                    if items.isEmpty {
                        Circle()
                            .fill(Color.clear)
                            .frame(width: 5, height: 5)
                    } else {
                        ForEach(Array(items.prefix(3).enumerated()), id: \.element.id) { _, item in
                            Circle()
                                .fill(item.cardBackgroundColor)
                                .frame(width: 5, height: 5)
                        }
                    }
                }
                .frame(height: 5)
            }
        }
        .buttonStyle(.plain)
    }

    private var dayTextColor: Color {
        let isCurrentMonth = Calendar.current.isDate(date, equalTo: displayedMonth, toGranularity: .month)
        let isSunday = Calendar.current.component(.weekday, from: date) == 1

        if isSunday {
            return isCurrentMonth ? .red : .red.opacity(0.35)
        }

        return isCurrentMonth ? .primary : .secondary.opacity(0.45)
    }
}

private extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let components = dateComponents([.year, .month], from: date)
        return self.date(from: components) ?? startOfDay(for: date)
    }
}

private extension DDayItem {
    var cardBackgroundColor: Color {
        switch cardColor {
        case .typeDefault:
            return type.defaultCardColor
        case .blue:
            return DaycoPalette.deepGreen
        case .green:
            return DaycoPalette.deepGreen
        case .yellow:
            return DaycoPalette.calendarOrange
        case .pink:
            return DaycoPalette.paleYellow
        case .purple:
            return DaycoPalette.magenta
        case .darkYellow:
            return DaycoPalette.paleYellow
        case .darkBlue:
            return DaycoPalette.vividBlue
        case .red:
            return DaycoPalette.red
        case .cyan:
            return DaycoPalette.cyan
        case .beige:
            return DaycoPalette.paleYellow
        case .lightGreen:
            return DaycoPalette.lightGreen
        case .gray:
            return Color(.secondarySystemGroupedBackground)
        }
    }

    var cardForegroundColor: Color {
        switch effectiveCardColor {
        case .pink, .darkYellow, .cyan, .beige, .lightGreen:
            return DaycoPalette.deepGreen
        case .gray:
            return .primary
        default:
            return .white
        }
    }

    var cardSecondaryColor: Color {
        switch effectiveCardColor {
        case .pink, .darkYellow, .cyan, .beige, .lightGreen:
            return DaycoPalette.deepGreen.opacity(0.62)
        case .gray:
            return .secondary
        default:
            return .white.opacity(0.76)
        }
    }

    private var effectiveCardColor: DDayCardColor {
        if cardColor != .typeDefault {
            return cardColor
        }

        switch type {
        case .countUp:
            return .blue
        case .countDown:
            return .yellow
        case .recurring:
            return .darkBlue
        case .milestone:
            return .purple
        }
    }
}

private extension DDayType {
    var defaultCardColor: Color {
        switch self {
        case .countUp:
            return DaycoPalette.deepGreen
        case .countDown:
            return DaycoPalette.calendarOrange
        case .recurring:
            return DaycoPalette.vividBlue
        case .milestone:
            return DaycoPalette.magenta
        }
    }
}
