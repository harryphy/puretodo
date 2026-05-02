//  ContentView.swift
//  Pure To Do
//
//  Created by PHY on 2023/12/8.
//  Version 2.4

import SwiftUI
import Foundation
import Combine
import UserNotifications
import WidgetKit
import StoreKit
import MessageUI
import UIKit

// MARK: - 自定义按钮样式

struct CategoryNameButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - 简化的边缘手势识别器

struct SimpleEdgePanGesture: UIViewRepresentable {
    let onEdgePan: () -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear

        // 只使用一个简单的拖拽手势
        let panGesture = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        panGesture.delegate = context.coordinator
        view.addGestureRecognizer(panGesture)

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onEdgePan: onEdgePan)
    }

    class Coordinator: NSObject, UIGestureRecognizerDelegate {
        let onEdgePan: () -> Void
        private var hasTriggered = false

        init(onEdgePan: @escaping () -> Void) {
            self.onEdgePan = onEdgePan
        }

        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            let location = gesture.location(in: gesture.view)
            let translation = gesture.translation(in: gesture.view)

            switch gesture.state {
            case .began:
                hasTriggered = false


            case .changed:
                // 如果从边缘开始且向右滑动超过10像素，立即触发
                if location.x < 15 && translation.x > 5 && !hasTriggered {
                    hasTriggered = true
                    onEdgePan()
                }

            case .ended:
                // 最终确认：如果从边缘开始且滑动距离足够
                if location.x < 15 && translation.x > 5 && !hasTriggered {
                    hasTriggered = true
                    onEdgePan()
                }
                hasTriggered = false

            default:
                hasTriggered = false
                break
            }
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            return true
        }
    }
}

private struct PullToCreateObserver: UIViewRepresentable {
    let threshold: CGFloat
    let onPull: (CGFloat, Bool) -> Void
    let onScroll: (CGFloat) -> Void
    let onScrollRangeChange: (CGFloat) -> Void
    let onTrigger: () -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.threshold = threshold
        context.coordinator.onPull = onPull
        context.coordinator.onScroll = onScroll
        context.coordinator.onScrollRangeChange = onScrollRangeChange
        context.coordinator.onTrigger = onTrigger

        DispatchQueue.main.async {
            context.coordinator.attach(from: uiView)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(threshold: threshold, onPull: onPull, onScroll: onScroll, onScrollRangeChange: onScrollRangeChange, onTrigger: onTrigger)
    }

    final class Coordinator: NSObject {
        var threshold: CGFloat
        var onPull: (CGFloat, Bool) -> Void
        var onScroll: (CGFloat) -> Void
        var onScrollRangeChange: (CGFloat) -> Void
        var onTrigger: () -> Void

        private weak var scrollView: UIScrollView?
        private var contentOffsetObservation: NSKeyValueObservation?
        private var isArmed = false
        private var didTrigger = false
        private var isTrackingTopPull = false
        private var thresholdFeedbackGenerator: UIImpactFeedbackGenerator?

        init(threshold: CGFloat, onPull: @escaping (CGFloat, Bool) -> Void, onScroll: @escaping (CGFloat) -> Void, onScrollRangeChange: @escaping (CGFloat) -> Void, onTrigger: @escaping () -> Void) {
            self.threshold = threshold
            self.onPull = onPull
            self.onScroll = onScroll
            self.onScrollRangeChange = onScrollRangeChange
            self.onTrigger = onTrigger
        }

        deinit {
            contentOffsetObservation?.invalidate()
            scrollView?.panGestureRecognizer.removeTarget(self, action: #selector(handlePanGesture(_:)))
        }

        func attach(from view: UIView, attempt: Int = 0) {
            guard let scrollView = view.nearestScrollView else {
                guard attempt < 8 else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self, weak view] in
                    guard let view else { return }
                    self?.attach(from: view, attempt: attempt + 1)
                }
                return
            }
            guard scrollView !== self.scrollView else { return }

            contentOffsetObservation?.invalidate()
            self.scrollView?.panGestureRecognizer.removeTarget(self, action: #selector(handlePanGesture(_:)))
            self.scrollView = scrollView
            scrollView.alwaysBounceVertical = true
            scrollView.panGestureRecognizer.addTarget(self, action: #selector(handlePanGesture(_:)))
            contentOffsetObservation = scrollView.observe(\.contentOffset, options: [.new]) { [weak self] scrollView, _ in
                DispatchQueue.main.async {
                    self?.scrollViewDidScroll(scrollView)
                }
            }
            scrollViewDidScroll(scrollView)
        }

        @objc private func handlePanGesture(_ gesture: UIPanGestureRecognizer) {
            guard let scrollView else { return }
            scrollViewDidScroll(scrollView)
        }

        private func scrollViewDidScroll(_ scrollView: UIScrollView) {
            let normalizedOffset = scrollView.contentOffset.y + scrollView.adjustedContentInset.top
            let maxScrollableOffset = max(
                0,
                scrollView.contentSize.height + scrollView.adjustedContentInset.top + scrollView.adjustedContentInset.bottom - scrollView.bounds.height
            )
            onScrollRangeChange(maxScrollableOffset)
            let canCollapseHeader = maxScrollableOffset > 220
            let panState = scrollView.panGestureRecognizer.state
            let translation = scrollView.panGestureRecognizer.translation(in: scrollView)
            let isDragging = scrollView.isDragging || panState == .began || panState == .changed
            let isHorizontalSwipe = abs(translation.x) > abs(translation.y)

            if panState == .began {
                isArmed = false
                didTrigger = false
                isTrackingTopPull = normalizedOffset <= 1
                thresholdFeedbackGenerator = UIImpactFeedbackGenerator(style: .light)
                thresholdFeedbackGenerator?.prepare()
            }

            let isPullingFromTop = isTrackingTopPull && isDragging && translation.y > 0 && !isHorizontalSwipe
            let pullDistance = isPullingFromTop ? translation.y : 0

            if isPullingFromTop {
                let pinnedTopOffset = -scrollView.adjustedContentInset.top
                if abs(scrollView.contentOffset.y - pinnedTopOffset) > 0.5 {
                    scrollView.setContentOffset(CGPoint(x: scrollView.contentOffset.x, y: pinnedTopOffset), animated: false)
                }
                onScroll(0)
            } else {
                onScroll(canCollapseHeader ? min(max(0, normalizedOffset), maxScrollableOffset) : 0)
            }

            guard pullDistance > 0 || !isHorizontalSwipe else { return }

            if isDragging && pullDistance >= threshold {
                if !isArmed {
                    if thresholdFeedbackGenerator == nil {
                        thresholdFeedbackGenerator = UIImpactFeedbackGenerator(style: .light)
                    }
                    thresholdFeedbackGenerator?.impactOccurred(intensity: 0.55)
                    thresholdFeedbackGenerator = nil
                }
                isArmed = true
            }

            onPull(isDragging ? pullDistance : 0, isDragging)

            if isArmed && !didTrigger && (panState == .ended || panState == .cancelled || panState == .failed) {
                didTrigger = true
                isArmed = false
                isTrackingTopPull = false
                onPull(0, false)
                onTrigger()
            }

            if !isDragging && pullDistance < 1 {
                isArmed = false
                didTrigger = false
                isTrackingTopPull = false
                thresholdFeedbackGenerator = nil
                onPull(0, false)
            }
        }
    }
}

private struct MainSectionDivider: View {
    var body: some View {
        LinearGradient(
            colors: [Color.black.opacity(0.08), Color.black.opacity(0)],
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(height: 1)
    }
}

private struct HiddenScrollContentBackground: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content.scrollContentBackground(.hidden)
        } else {
            content
        }
    }
}

private struct MainListContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value += nextValue()
    }
}

private extension UIView {
    var nearestScrollView: UIScrollView? {
        let sourceRect = bounds.isEmpty ? nil : convert(bounds, to: nil)
        var bestScrollView: UIScrollView?
        var bestScore: CGFloat = 0
        var ancestor = superview

        while let root = ancestor {
            for scrollView in root.descendantScrollViews where scrollView.window != nil && !scrollView.isHidden && scrollView.alpha > 0.01 {
                guard let sourceRect else {
                    return scrollView
                }

                let scrollRect = scrollView.convert(scrollView.bounds, to: nil)
                let intersection = sourceRect.intersection(scrollRect)
                let score = intersection.isNull ? 0 : intersection.width * intersection.height

                if score > bestScore {
                    bestScore = score
                    bestScrollView = scrollView
                }
            }

            if bestScrollView != nil {
                return bestScrollView
            }

            ancestor = root.superview
        }

        return nil
    }

    private var descendantScrollViews: [UIScrollView] {
        var scrollViews: [UIScrollView] = []

        for subview in subviews {
            if let scrollView = subview as? UIScrollView {
                scrollViews.append(scrollView)
            }
            scrollViews.append(contentsOf: subview.descendantScrollViews)
        }

        return scrollViews
    }
}

// MARK: - 辅助视图

// 提醒信息视图
struct ReminderInfoView: View {
    let item: TodoItem

    var body: some View {
        if let reminderType = item.reminderType {
            switch reminderType {
            case .single:
                if let reminderDate = item.reminderDate {
                    HStack {
                        if reminderDate > Date() {
                            Image(systemName: "clock")
                                .font(.system(size: 13))
                                .foregroundColor(Color(hex: "C0C0C0"))
                                .padding(.trailing, -5)
                        }
                        Text(formatDate(reminderDate))
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(Color(hex: "C0C0C0"))
                    }
                }
            case .daily:
                if let reminderTime = item.reminderTime {
                    HStack {
                        Image(systemName: "clock")
                            .font(.system(size: 13))
                            .foregroundColor(Color(hex: "C0C0C0"))
                            .padding(.trailing, -5)
                        Text("Daily at \(formatTime(reminderTime))")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(Color(hex: "C0C0C0"))
                    }
                }
            case .weekly:
                if let reminderTime = item.reminderTime, let weekdays = item.reminderWeekdays {
                    HStack {
                        Image(systemName: "clock")
                            .font(.system(size: 13))
                            .foregroundColor(Color(hex: "C0C0C0"))
                            .padding(.trailing, -5)
                        let weekdaysString = weekdays.sorted().map { weekdaySymbol(for: $0) }.joined(separator: ", ")
                        Text("\(weekdaysString) \(formatTime(reminderTime))")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(Color(hex: "C0C0C0"))
                            .lineLimit(1)
                    }
                }
            case .monthly:
                if let reminderTime = item.reminderTime, let daysOfMonth = item.reminderDaysOfMonth {
                    HStack {
                        Image(systemName: "clock")
                            .font(.system(size: 13))
                            .foregroundColor(Color(hex: "C0C0C0"))
                            .padding(.trailing, -5)
                        let daysString = daysOfMonth.sorted().map { "\($0)" }.joined(separator: ", ")
                        Text("Monthly on \(daysString) at \(formatTime(reminderTime))")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(Color(hex: "C0C0C0"))
                            .lineLimit(1)
                    }
                }
            }
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm"
        return formatter.string(from: date)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func weekdaySymbol(for weekday: Int) -> String {
        let symbols = Calendar.current.shortWeekdaySymbols
        let index = (weekday - 1) % 7
        return symbols[index]
    }
}

// 单个待办事项视图
struct TodoItemRowView: View {
    let item: TodoItem
    let isPinned: Bool
    let selectedItemId: UUID?
    let onTap: () -> Void
    let onDelete: () -> Void
    let onMarkDone: () -> Void
    let onPin: () -> Void
    let onUnpin: () -> Void
    let onMoveToCategory: () -> Void

    private var activeSubItemCount: Int {
        item.subItems.filter { !$0.isDone }.count
    }

    private let titleToCountSpacing: CGFloat = 28
    private let subItemCountColumnWidth: CGFloat = 32

    var body: some View {
        HStack(alignment: .top, spacing: titleToCountSpacing) {
            VStack(alignment: .leading, spacing: item.reminderType == nil ? 0 : 6) {
                Text(item.title)
                    .font(.system(size: 18, weight: isPinned ? .medium : (selectedItemId == item.id ? .bold : .regular)))
                    .foregroundColor(Color(hex: "2A2A2A"))
                    .lineSpacing(2)
                    .opacity(selectedItemId == item.id ? 0.6 : 1.0)
                    .fixedSize(horizontal: false, vertical: true)
                ReminderInfoView(item: item)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(activeSubItemCount > 0 ? "\(activeSubItemCount)" : " ")
                .foregroundColor(Color(hex: "C0C0C0"))
                .font(.system(size: 18, weight: .light))
                .frame(width: subItemCountColumnWidth, alignment: .trailing)
                .opacity(activeSubItemCount > 0 ? 1 : 0)
                .accessibilityHidden(activeSubItemCount == 0)
        }
        .padding(.vertical, 18)
        .listRowInsets(EdgeInsets(top: 0, leading: 28, bottom: 0, trailing: 28))
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .listRowBackground(Color(hex: "FAFAFA"))
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
                onDelete()
            } label: {
                Label("", systemImage: "trash.fill")
            }
            .tint(Color(hex: "F55447"))
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                // 第一次振动：重
                let heavyGenerator = UIImpactFeedbackGenerator(style: .heavy)
                heavyGenerator.impactOccurred()

                // 0.2秒后第二次振动：轻
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    let lightGenerator = UIImpactFeedbackGenerator(style: .light)
                    lightGenerator.impactOccurred()
                }

                onMarkDone()
            } label: {
                Image("purecheck")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 18, height: 18)
            }
            .tint(Color(hex: "3BBF5E"))
            if isPinned {
                Button {
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    onUnpin()
                } label: {
                    Label("", systemImage: "pin.slash.fill")
                }
                .tint(Color(hex: "F8B600"))
            } else {
                Button {
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    onPin()
                } label: {
                    Label("", systemImage: "pin.fill")
                }
                .tint(Color(hex: "F8B600"))
            }
            Button {
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
                onMoveToCategory()
            } label: {
                Label("", systemImage: "arrowshape.turn.up.right.fill")
            }
            .tint(Color(hex: "F78D41"))
        }
    }
}

// ContentView 结构
struct ContentView: View {
    @State private var isUnlocked: Bool = UserDefaults.standard.bool(forKey: "isAllFeaturesUnlocked")
    @State private var items: [TodoItem] = DataStore.shared.loadItems()
    @State private var pinnedItems: [TodoItem] = DataStore.shared.loadPinnedItems()
    @State private var doneItems: [TodoItem] = DataStore.shared.loadDoneItems()
    @State private var categories: [Category] = DataStore.shared.loadCategories()
    @State private var selectedCategory: Category?
    @State private var showCategoryDrawer = false
    @State private var isGestureActive = false
    @State private var showInputView = false
    @State private var showCategoryOptionsModal = false
    @State private var showCategoryRenameSheet = false
    @State private var newCategoryName = ""
    @State private var showDeleteCategoryAlert = false
    @State private var unfinishedItemsCount = 0
    @State private var categoryNameError = ""

    // 辅助方法：创建输入视图
    @ViewBuilder
    private func createInputView() -> some View {
        if isCreatingNewItem {
            createNewItemInputView()
        } else {
            createEditItemInputView()
        }
    }

    @ViewBuilder
    private func createNewItemInputView() -> some View {
        if #available(iOS 16.4, *) {
            InputView(item: $newItem, onSave: { newItem in
                if let index = self.items.firstIndex(where: { $0.id == newItem.id }) {
                    self.items[index] = newItem
                } else {
                    self.items.insert(newItem, at: 0)
                }
                self.saveData()
            }, isNewItem: true)
            .presentationCornerRadius(30)
        } else {
            InputView(item: $newItem, onSave: { newItem in
                if let index = self.items.firstIndex(where: { $0.id == newItem.id }) {
                    self.items[index] = newItem
                } else {
                    self.items.insert(newItem, at: 0)
                }
                self.saveData()
            }, isNewItem: true)
        }
    }

    @ViewBuilder
    private func createEditItemInputView() -> some View {
        if let editingIndex = self.items.firstIndex(where: { $0.id == self.editingItem?.id }) {
            if #available(iOS 16.4, *) {
                InputView(item: self.$items[editingIndex], onSave: { updatedItem in
                    self.items[editingIndex] = updatedItem
                    self.saveData()
                }, isNewItem: false)
                .presentationCornerRadius(30)
            } else {
                InputView(item: self.$items[editingIndex], onSave: { updatedItem in
                    self.items[editingIndex] = updatedItem
                    self.saveData()
                }, isNewItem: false)
            }
        } else if let pinnedIndex = self.pinnedItems.firstIndex(where: { $0.id == self.editingItem?.id }) {
            if #available(iOS 16.4, *) {
                InputView(item: self.$pinnedItems[pinnedIndex], onSave: { updatedItem in
                    self.pinnedItems[pinnedIndex] = updatedItem
                    self.saveData()
                }, isNewItem: false)
                .presentationCornerRadius(30)
            } else {
                InputView(item: self.$pinnedItems[pinnedIndex], onSave: { updatedItem in
                    self.pinnedItems[pinnedIndex] = updatedItem
                    self.saveData()
                }, isNewItem: false)
            }
        }
    }
    @State private var inputText = ""
    @State private var editingItem: TodoItem?
    @State private var selectedItemId: UUID?
    @State private var selectedPinnedItemId: UUID?
    @State private var todoItems: [TodoItem] = []
    @State private var isCreatingNewItem = true
    @State private var newItem = TodoItem(title: "", isDone: false, date: Date(), subItems: [])
    @EnvironmentObject var todoDataStore: TodoDataStore
    @State private var showReminderView = false
    @State private var reminderItem: TodoItem?

    @State private var pinnedItemPosition: CGFloat = 0
    @State private var firstItemPosition: CGFloat = 0
    @State private var pullToCreateDistance: CGFloat = 0
    @State private var listScrollOffset: CGFloat = 0
    @State private var isHeaderCollapsed = false
    @State private var isHandlingPullToCreate = false
    @State private var pinFadingOutItemIds: Set<UUID> = []
    @State private var pinFadingInItemIds: Set<UUID> = []
    @State private var mainListContentHeight: CGFloat = 0
    @State private var mainListViewportHeight: CGFloat = 0
    @State private var showDonePage = false
    @State private var showPurchaseSheet = false
    @State private var featuresUnlockedObserver: NSObjectProtocol?

    @State private var showRating = false // 控制弹窗显示
    @State private var isInDonePage = false // 跟踪是否在 Done 页面
    @State private var showCategorySelector = false // 控制分类选择器显示
    @State private var itemToMove: TodoItem? // 要移动的事项

    private let pullToCreateThreshold: CGFloat = 48
    private let completedItemsBottomLinkHeight: CGFloat = 69
    private let mainBackgroundColor = Color(hex: "FAFAFA")

    private var shouldPinCompletedItemsLink: Bool {
        guard mainListViewportHeight > 0 else { return true }
        return mainListContentHeight + completedItemsBottomLinkHeight <= mainListViewportHeight
    }

    private var headerCollapseProgress: CGFloat {
        isHeaderCollapsed ? 1 : 0
    }

    private var headerTopSpacing: CGFloat {
        42 - (22 * headerCollapseProgress)
    }

    private var headerTitleSize: CGFloat {
        54 - (20 * headerCollapseProgress)
    }

    private var pullPromptHeight: CGFloat {
        let baseHeight: CGFloat = 16.5
        let pullExpansion = min(pullToCreateDistance, pullToCreateThreshold + 18)
        return (baseHeight + pullExpansion) * (1 - headerCollapseProgress)
    }

    private var pullPromptOpacity: Double {
        Double(max(0, 1 - headerCollapseProgress))
    }

    // 计算当前分类的事项
    private var currentCategoryItems: [TodoItem] {
        guard let selectedCategory = selectedCategory else {
            // 如果没有选择分类，返回所有没有分类ID的事项（兼容旧数据）
            return items.filter { $0.categoryId == nil }
        }

        // 如果当前分类是默认分类，同时显示没有categoryId的旧数据和属于该分类的数据
        if selectedCategory.name == "To Do" {
            return items.filter { $0.categoryId == nil || $0.categoryId == selectedCategory.id }
        }

        return items.filter { $0.categoryId == selectedCategory.id }
    }

    // 计算当前分类的置顶事项
    private var currentCategoryPinnedItems: [TodoItem] {
        guard let selectedCategory = selectedCategory else {
            // 如果没有选择分类，返回所有没有分类ID的置顶事项（兼容旧数据）
            return pinnedItems.filter { $0.categoryId == nil }
        }

        // 如果当前分类是默认分类，同时显示没有categoryId的旧数据和属于该分类的数据
        if selectedCategory.name == "To Do" {
            return pinnedItems.filter { $0.categoryId == nil || $0.categoryId == selectedCategory.id }
        }

        return pinnedItems.filter { $0.categoryId == selectedCategory.id }
    }

    private func openInputView(for todoId: UUID) {
        if let item = currentCategoryItems.first(where: { $0.id == todoId }) {
            editingItem = item
            isCreatingNewItem = false
            newItem = item
            showInputView = true
        } else if let pinnedItem = currentCategoryPinnedItems.first(where: { $0.id == todoId }) {
            editingItem = pinnedItem
            isCreatingNewItem = false
            newItem = pinnedItem
            showInputView = true
        } else {
            print("未找到对应的事项")
        }
    }

    func showPurchasePrompt() {
        showPurchaseSheet = true
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm"
        return formatter.string(from: date)
    }

    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func weekdaySymbol(for weekday: Int) -> String {
        let symbols = Calendar.current.shortWeekdaySymbols // ["Sun", "Mon", ..., "Sat"]
        let index = (weekday - 1) % 7
        return symbols[index]
    }

    init() {
        let storedItems = DataStore.shared.loadItems()
        let storedDoneItems = DataStore.shared.loadDoneItems()
        let storedCategories = DataStore.shared.loadCategories()

        // 确保有默认分类
        var categories = storedCategories
        if categories.isEmpty {
            let defaultCategory = Category(name: "To Do")
            categories = [defaultCategory]
            DataStore.shared.saveCategories(categories)
        }

        // 设置默认选中的分类
        let defaultCategory = categories.first!

        if ContentView.isFirstLaunch() {
            let defaultItems = [
                TodoItem(title: NSLocalizedString("↓ Pull to add", comment: "Create new item"), isDone: false, date: Date(), categoryId: defaultCategory.id),
                TodoItem(title: NSLocalizedString("→ Swipe an item right to mark done", comment: "Mark as done"), isDone: false, date: Date(), categoryId: defaultCategory.id),
                TodoItem(title: NSLocalizedString("← Swipe an item left to delete", comment: "Delete"), isDone: false, date: Date(), categoryId: defaultCategory.id)
            ]
            _items = State(initialValue: defaultItems + storedItems)
            _doneItems = State(initialValue: storedDoneItems)
        } else {
            _items = State(initialValue: storedItems)
            _doneItems = State(initialValue: storedDoneItems)
        }

        _categories = State(initialValue: categories)
        _selectedCategory = State(initialValue: defaultCategory)
    }

    private static func isFirstLaunch() -> Bool {
        let keyValueStore = NSUbiquitousKeyValueStore.default
        let hasLaunchedOnce = keyValueStore.bool(forKey: "HasLaunchedOnce")
        if !hasLaunchedOnce {
            keyValueStore.set(true, forKey: "HasLaunchedOnce")
            keyValueStore.synchronize()
        }
        return !hasLaunchedOnce
    }

    private var addButtonView: some View {
        VStack {
            Spacer()
            Button(action: {
                // 获取未完成事项的数量
                let incompleteItemsCount = currentCategoryItems.count + currentCategoryPinnedItems.count

                if !isUnlocked && incompleteItemsCount >= 11 {
                    // 提示用户购买完整版
                    showPurchasePrompt()
                } else {
                    // 允许创建新事项
                    isCreatingNewItem = true
                    newItem = TodoItem(title: "", isDone: false, date: Date(), subItems: [], categoryId: selectedCategory?.id)
                    showInputView = true  // 打开弹窗
                }

                let generator = UIImpactFeedbackGenerator(style: .light); generator.impactOccurred()
            }) {
                Image(systemName: "plus")
                    .font(.largeTitle)
                    .foregroundColor(.primary)
            }
            .flatButtonStyle()
            .padding()
            Spacer()
        }
    }

    // MARK: - 视图组件

    // 主头部视图
    @ViewBuilder
    private var mainHeaderView: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer().frame(height: headerTopSpacing)

            HStack(alignment: .center, spacing: 0) {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showCategoryDrawer = true
                    }
                }) {
                    HStack(alignment: .center, spacing: 15) {
                        Text(selectedCategory?.name ?? "To Do")
                            .foregroundColor(Color(hex: "2A2A2A"))
                            .font(.system(size: headerTitleSize, weight: .regular))
                            .lineLimit(1)
                            .minimumScaleFactor(min(1, 36 / headerTitleSize))
                            .layoutPriority(1)

                        Image(systemName: "chevron.right")
                            .font(.system(size: 17, weight: .regular))
                            .foregroundColor(Color(hex: "C0C0C0"))
                            .frame(width: 7, height: 14)
                            .accessibilityHidden(true)
                    }
                    .frame(height: headerTitleSize, alignment: .center)
                }
                .buttonStyle(CategoryNameButtonStyle())

                Spacer(minLength: 4)
                navigationBarTrailingButton
            }
            .frame(height: headerTitleSize, alignment: .center)
            .padding(.horizontal, 28)

            Spacer().frame(height: 38 * (1 - headerCollapseProgress))

            Text(NSLocalizedString("↓ Pull to add", comment: "Create new item"))
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(.black.opacity(0.15))
                .tracking(0.39)
                .lineLimit(1)
                .frame(height: pullPromptHeight, alignment: .leading)
                .opacity(pullPromptOpacity)
                .padding(.horizontal, 28)
                .clipped()

            Spacer().frame(height: 26 * (1 - headerCollapseProgress))

            MainSectionDivider()
                .padding(.horizontal, 28)
        }
        .background(mainBackgroundColor)
        .animation(.easeInOut(duration: 0.28), value: headerCollapseProgress)
        .animation(.easeOut(duration: 0.12), value: pullToCreateDistance)
    }

    // 主内容视图
    @ViewBuilder
    private var mainContentView: some View {
        if currentCategoryItems.isEmpty && currentCategoryPinnedItems.isEmpty {
            if #available(iOS 16, *) {
                pullToCreateContainer {
                    GeometryReader { geometry in
                        ScrollView {
                            VStack(spacing: 0) {
                                Spacer(minLength: 0)
                                completedItemsPlainLink
                                    .padding(.horizontal, 28)
                                    .padding(.bottom, 24)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: geometry.size.height)
                        }
                        .background(mainBackgroundColor)
                    }
                }
            } else {
                addButtonView
                    .background(mainBackgroundColor)
            }
        } else {
            pullToCreateContainer {
                GeometryReader { geometry in
                    ZStack(alignment: .bottom) {
                        List {
                        // 置顶事项部分
                        if !currentCategoryPinnedItems.isEmpty {
                            ForEach(currentCategoryPinnedItems, id: \.id) { pinnedItem in
                                TodoItemRowView(
                                    item: pinnedItem,
                                    isPinned: true,
                                    selectedItemId: selectedPinnedItemId,
                                    onTap: {
                                        self.selectedPinnedItemId = pinnedItem.id
                                        self.editingItem = pinnedItem
                                        self.inputText = pinnedItem.title
                                        self.showInputView = true
                                        self.isCreatingNewItem = false
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                            self.selectedPinnedItemId = nil
                                        }
                                    },
                                    onDelete: {
                                        withAnimation {
                                            deletePinnedItem(item: pinnedItem)
                                        }
                                    },
                                    onMarkDone: {
                                        withAnimation {
                                            markAsDone(item: pinnedItem)
                                        }
                                    },
                                    onPin: {},
                                    onUnpin: {
                                        transitionPinState(for: pinnedItem, pin: false)
                                    },
                                onMoveToCategory: {
                                    showCategorySelector(for: pinnedItem)
                                }
                            )
                            .opacity(pinTransitionOpacity(for: pinnedItem.id))
                            .animation(.easeInOut(duration: 0.24), value: pinFadingOutItemIds)
                            .animation(.easeInOut(duration: 0.24), value: pinFadingInItemIds)
                        }
                            .onMove(perform: movePinnedItem)
                            .listRowSeparator(.hidden)
                        }

                        // 分割线
                            if !currentCategoryItems.isEmpty && !currentCategoryPinnedItems.isEmpty {
                            VStack(spacing: 0) {
                                Spacer().frame(height: 24)
                                MainSectionDivider()
                            }
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 0, leading: 28, bottom: 0, trailing: 28))
                            .listRowBackground(mainBackgroundColor)
                        }

                        // 普通事项部分
                        ForEach(currentCategoryItems.filter { !$0.isDone }, id: \.id) { item in
                            TodoItemRowView(
                                item: item,
                                isPinned: false,
                                selectedItemId: selectedItemId,
                                onTap: {
                                    self.selectedItemId = item.id
                                    self.editingItem = item
                                    self.inputText = item.title
                                    self.showInputView = true
                                    self.isCreatingNewItem = false
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                        self.selectedItemId = nil
                                    }
                                },
                                onDelete: {
                                    withAnimation {
                                        deleteItem(item: item)
                                    }
                                },
                                onMarkDone: {
                                    withAnimation {
                                        markAsDone(item: item)
                                    }
                                },
                                onPin: {
                                    transitionPinState(for: item, pin: true)
                                },
                                onUnpin: {},
                                onMoveToCategory: {
                                    showCategorySelector(for: item)
                                }
                            )
                            .opacity(pinTransitionOpacity(for: item.id))
                            .animation(.easeInOut(duration: 0.24), value: pinFadingOutItemIds)
                            .animation(.easeInOut(duration: 0.24), value: pinFadingInItemIds)
                        }
                        .onMove(perform: move)
                        .onDelete { offsets in
                            withAnimation {
                                deleteItems(at: offsets, from: currentCategoryItems)
                            }
                        }
                        .listRowSeparator(.hidden)

                        if !shouldPinCompletedItemsLink {
                            completedItemsListRow
                        }
                    }
                    .listStyle(PlainListStyle())
                    .listRowSpacing(0)
                    .environment(\.defaultMinListRowHeight, 1)
                    .modifier(HiddenScrollContentBackground())
                        .background(mainBackgroundColor)

                        if shouldPinCompletedItemsLink {
                            completedItemsPlainLink
                                .padding(.horizontal, 28)
                                .padding(.bottom, 24)
                                .background(mainBackgroundColor)
                        }
                    }
                    .background(alignment: .top) {
                        mainListContentMeasurement
                            .frame(width: geometry.size.width, alignment: .top)
                            .opacity(0)
                            .allowsHitTesting(false)
                    }
                    .onPreferenceChange(MainListContentHeightKey.self) { height in
                        if abs(mainListContentHeight - height) > 0.5 {
                            mainListContentHeight = height
                        }
                    }
                    .onAppear {
                        mainListViewportHeight = geometry.size.height
                    }
                    .onChange(of: geometry.size.height) { newHeight in
                        mainListViewportHeight = newHeight
                    }
                }
                .sheet(isPresented: $showRating) {
                    if #available(iOS 16.4, *) {
                        RatingView()
                            .presentationDetents([.fraction(0.3)])
                            .presentationCornerRadius(30)
                    } else {
                        RatingView()
                            .presentationDetents([.fraction(0.3)])
                    }
                }
            }
        }
    }

    private func pullToCreateContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .background(
                PullToCreateObserver(
                    threshold: pullToCreateThreshold,
                    onPull: { distance, isDragging in
                        if abs(pullToCreateDistance - distance) > 0.5 {
                            if isDragging {
                                pullToCreateDistance = distance
                            } else {
                                withAnimation(.interactiveSpring(response: 0.28, dampingFraction: 0.86)) {
                                    pullToCreateDistance = distance
                                }
                            }
                        }
                    },
                    onScroll: { offset in
                        listScrollOffset = offset

                        if offset <= 1 && isHeaderCollapsed {
                            withAnimation(.easeInOut(duration: 0.28)) {
                                isHeaderCollapsed = false
                            }
                        } else if offset > 18 && !isHeaderCollapsed {
                            withAnimation(.easeInOut(duration: 0.28)) {
                                isHeaderCollapsed = true
                            }
                        }
                    },
                    onScrollRangeChange: { _ in },
                    onTrigger: {
                        triggerPullToCreate()
                    }
                )
            )
    }

    private var mainListContentMeasurement: some View {
        VStack(spacing: 0) {
            ForEach(currentCategoryPinnedItems, id: \.id) { item in
                measuredTodoItemRow(item, isPinned: true)
            }

            if !currentCategoryItems.isEmpty && !currentCategoryPinnedItems.isEmpty {
                VStack(spacing: 0) {
                    Spacer().frame(height: 24)
                    MainSectionDivider()
                }
                .padding(.horizontal, 28)
            }

            ForEach(currentCategoryItems.filter { !$0.isDone }, id: \.id) { item in
                measuredTodoItemRow(item, isPinned: false)
            }
        }
        .background(
            GeometryReader { proxy in
                Color.clear.preference(key: MainListContentHeightKey.self, value: proxy.size.height)
            }
        )
    }

    private func measuredTodoItemRow(_ item: TodoItem, isPinned: Bool) -> some View {
        let activeSubItemCount = item.subItems.filter { !$0.isDone }.count

        return HStack(alignment: .top, spacing: 28) {
            VStack(alignment: .leading, spacing: item.reminderType == nil ? 0 : 6) {
                Text(item.title)
                    .font(.system(size: 18, weight: isPinned ? .medium : .regular))
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)

                ReminderInfoView(item: item)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(activeSubItemCount > 0 ? "\(activeSubItemCount)" : " ")
                .font(.system(size: 18, weight: .light))
                .frame(width: 32, alignment: .trailing)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 18)
    }

    // 导航栏右侧按钮
    @ViewBuilder
    private var navigationBarTrailingButton: some View {
        HStack(spacing: 18) {
            // 如果不是"To Do"分类，显示三个点的more图标
            if let selectedCategory = selectedCategory, selectedCategory.name != "To Do" {
                Button(action: {
                    showCategoryOptionsModal = true
                }) {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(width: 28, height: 28)
                        .rotationEffect(.degrees(90))
                }
                .flatButtonStyle()
                .frame(width: 28, height: 28, alignment: .center)
            }
        }
        .frame(height: headerTitleSize, alignment: .center)
    }

    private var completedItemsListRow: some View {
        completedItemsNavigationLink
            .padding(.top, 24)
            .padding(.bottom, 24)
            .listRowInsets(EdgeInsets(top: 0, leading: 28, bottom: 0, trailing: 28))
            .listRowSeparator(.hidden)
            .listRowBackground(mainBackgroundColor)
    }

    private var completedItemsPlainLink: some View {
        completedItemsNavigationLink
    }

    private var completedItemsNavigationLink: some View {
        Button {
            showDonePage = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "tray")
                    .font(.system(size: 16, weight: .regular))
                    .frame(width: 16, height: 16)

                Text(NSLocalizedString("Completed", comment: "Completed items"))
                    .font(.system(size: 14, weight: .medium))
                    .tracking(0.13)
            }
            .foregroundColor(Color(hex: "C0C0C0"))
            .frame(height: 21, alignment: .center)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .flatButtonStyle()
    }

    private var donePageNavigationLink: some View {
        NavigationLink(
            destination: DonePage(items: $items, doneItems: $doneItems, saveData: saveData, categories: categories)
                .onAppear {
                    isInDonePage = true
                }
                .onDisappear {
                    isInDonePage = false
                },
            isActive: $showDonePage
        ) {
            EmptyView()
        }
    }

    // 分类抽屉遮罩
    @ViewBuilder
    private var categoryDrawerOverlay: some View {
        if showCategoryDrawer {
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showCategoryDrawer = false
                    }
                }
                .zIndex(1)
        }
    }

    // 分类抽屉视图
    @ViewBuilder
    private var categoryDrawerView: some View {
        if showCategoryDrawer {
            CategoryDrawerView(
                isPresented: $showCategoryDrawer,
                selectedCategory: $selectedCategory,
                categories: $categories,
                items: $items,
                pinnedItems: $pinnedItems
            )
            .ignoresSafeArea(edges: [.top, .bottom])
            .transition(.move(edge: .leading))
            .zIndex(2)
        }
    }

    @ViewBuilder
    private var deleteCategoryConfirmationOverlay: some View {
        if showDeleteCategoryAlert {
            ZStack {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .onTapGesture {
                        showDeleteCategoryAlert = false
                    }

                FlatConfirmDialog(
                    title: "Delete Category",
                    message: deleteCategoryConfirmationMessage,
                    destructiveTitle: "Delete",
                    onCancel: {
                        showDeleteCategoryAlert = false
                    },
                    onConfirm: {
                        showDeleteCategoryAlert = false
                        deleteCategoryWithItems()
                    }
                )
            }
            .zIndex(3)
            .transition(.opacity)
        }
    }

    private var deleteCategoryConfirmationMessage: String {
        if unfinishedItemsCount > 0 {
            return "This category contains \(unfinishedItemsCount) to-do item\(unfinishedItemsCount == 1 ? "" : "s"). Deleting the category will also delete all the to-do items. Are you sure you want to continue?"
        }

        return "Are you sure you want to delete this category?"
    }

    // 边缘手势视图 - 可靠的手势检测
    @ViewBuilder
    private var edgeGestureView: some View {
        if !showCategoryDrawer && !isInDonePage {
                    // 主要边缘手势区域
        Rectangle()
            .fill(Color.clear)
            .frame(width: 18, height: .infinity)
            .contentShape(Rectangle())
            .allowsHitTesting(true)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let isFromEdge = value.startLocation.x < 18
                        let hasEnoughTranslation = value.translation.width > 4
                        let isRightDirection = value.translation.width > 0

                        if isFromEdge && hasEnoughTranslation && isRightDirection && !isGestureActive {
                            isGestureActive = true
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showCategoryDrawer = true
                            }
                        }
                    }
                    .onEnded { value in
                        let isFromEdge = value.startLocation.x < 18
                        let hasEnoughTranslation = value.translation.width > 4
                        let isRightDirection = value.translation.width > 0

                        if isFromEdge && hasEnoughTranslation && isRightDirection && !isGestureActive {
                            isGestureActive = true
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showCategoryDrawer = true
                            }
                        }
                        // 重置手势状态
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            isGestureActive = false
                        }
                    }
            )
                .zIndex(100)
        }
    }


    var body: some View {
        ZStack {
            NavigationView {
                VStack(alignment: .leading, spacing: 0) {
                    mainHeaderView
                    mainContentView
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .background(mainBackgroundColor.ignoresSafeArea())
                .navigationBarTitleDisplayMode(.inline)
                .navigationBarHidden(true)
                .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowTodoDetail")), perform: { notification in
                    if let todoId = notification.object as? UUID {
                        openInputView(for: todoId)
                    }
                })
                .onAppear(perform: setupObservers)
                .onDisappear(perform: cleanupObservers)
                .background(donePageNavigationLink.hidden())
            }

            categoryDrawerOverlay
            categoryDrawerView
            deleteCategoryConfirmationOverlay
            HStack(spacing: 0) {
                edgeGestureView
                Spacer()
            }
        }
        .sheet(isPresented: $showInputView, onDismiss: {}) {
            createInputView()
        }
        .sheet(isPresented: $showPurchaseSheet) {
            createPurchasePromptView()
        }
        .sheet(isPresented: $showCategorySelector) {
            if !categories.isEmpty {
                CategorySelectorView(
                    categories: categories,
                    currentCategoryId: getCurrentCategoryIdForItem(itemToMove),
                    onSelectCategory: { targetCategory in
                        if let item = itemToMove {
                            moveItemToCategory(item, targetCategory: targetCategory)
                        }
                        showCategorySelector = false
                        itemToMove = nil
                    },
                    onCancel: {
                        showCategorySelector = false
                        itemToMove = nil
                    }
                )
            }
        }
        .sheet(isPresented: $showCategoryOptionsModal) {
            categoryOptionsModalView()
        }
        .sheet(isPresented: $showCategoryRenameSheet) {
            categoryRenameView()
        }
        .onChange(of: categories) { _ in
            DataStore.shared.saveCategories(categories)
        }
    }

    // MARK: - 手势和事件处理方法

    // 处理下拉创建事件
    private func triggerPullToCreate() {
        guard !isHandlingPullToCreate else { return }
        isHandlingPullToCreate = true

        withAnimation(.interactiveSpring(response: 0.28, dampingFraction: 0.86)) {
            pullToCreateDistance = 0
        }

        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            let incompleteItemsCount = currentCategoryItems.count + currentCategoryPinnedItems.count

            if !isUnlocked && incompleteItemsCount >= 11 {
                showPurchasePrompt()
            } else {
                isCreatingNewItem = true
                newItem = TodoItem(title: "", isDone: false, date: Date(), subItems: [], categoryId: selectedCategory?.id)
                showInputView = true
            }

            isHandlingPullToCreate = false
        }
    }

    // 设置观察者
    private func setupObservers() {
        // 添加通知观察者
        featuresUnlockedObserver = NotificationCenter.default.addObserver(forName: NSNotification.Name("FeaturesUnlocked"), object: nil, queue: .main) { _ in
            self.isUnlocked = true
        }

        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == nil {
            todoDataStore.loadAllItems()
            // 额外清理一次，使用 ContentView 自己的数据（确保覆盖所有情况）
            NotificationHelper.cleanupOrphanedNotifications(
                items: items,
                pinnedItems: pinnedItems,
                doneItems: doneItems
            )
        }
        NotificationCenter.default.addObserver(forName: NSNotification.Name("ShowTodoDetail"), object: nil, queue: .main) { notification in
            if let todoId = notification.object as? UUID {
                showItemDetail(for: todoId)
            }
        }
        NotificationCenter.default.addObserver(forName: NSNotification.Name("FeaturesUnlocked"), object: nil, queue: .main) { _ in
            self.isUnlocked = UserDefaults.standard.bool(forKey: "isAllFeaturesUnlocked")
        }
    }

    // 清理观察者
    private func cleanupObservers() {
        // 移除通知观察者
        if let observer = featuresUnlockedObserver {
            NotificationCenter.default.removeObserver(observer)
            featuresUnlockedObserver = nil
        }
    }

    // 辅助方法：创建购买提示视图
    @ViewBuilder
    private func createPurchasePromptView() -> some View {
        if #available(iOS 16.4, *) {
            PurchasePromptView(
                onPurchase: {
                    // 开始购买流程
                    PurchaseManager.shared.startPurchase()
                    showPurchaseSheet = false
                },
                onRestore: {
                    // 恢复购买
                    PurchaseManager.shared.restorePurchases()
                    showPurchaseSheet = false
                },
                onCancel: {
                    showPurchaseSheet = false
                }
            )
            .presentationDetents([.fraction(0.5)])
            .presentationCornerRadius(30)
        } else {
            // Fallback on earlier versions
            PurchasePromptView(
                onPurchase: {
                    // 开始购买流程
                    PurchaseManager.shared.startPurchase()
                    showPurchaseSheet = false
                },
                onRestore: {
                    // 恢复购买
                    PurchaseManager.shared.restorePurchases()
                    showPurchaseSheet = false
                },
                onCancel: {
                    showPurchaseSheet = false
                }
            )
        }
    }

    // MARK: - 分类选项模态窗口
    @ViewBuilder
    private func categoryOptionsModalView() -> some View {
        if #available(iOS 16.4, *) {
            VStack(spacing: 0) {
                // 顶部拖拽指示器
                VStack(spacing: 0) {
                    Spacer().frame(height: 20)
                    Image(systemName: "chevron.compact.down")
                        .foregroundColor(.primary)
                        .font(.system(size: 32))
                    Spacer().frame(height: 20)
                }

                // 选项列表
                VStack(spacing: 0) {
                    // Change Category Name 选项
                    Button(action: {
                        showCategoryOptionsModal = false
                        newCategoryName = selectedCategory?.name ?? ""
                        categoryNameError = ""
                        showCategoryRenameSheet = true
                    }) {
                        HStack {
                            Image(systemName: "square.and.pencil")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.primary)
                                .frame(width: 24, height: 24)

                            Text("Change Category Name")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.primary)

                            Spacer()
                        }
	                        .padding(.horizontal, 20)
	                        .padding(.vertical, 16)
	                    }
	                    .flatButtonStyle()

	                    Divider()
                        .padding(.horizontal, 22)

                    // Delete Category 选项
                    Button(action: {
                        showCategoryOptionsModal = false
                        checkAndDeleteCategory()
                    }) {
                        HStack {
                            Image(systemName: "trash")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.primary)
                                .frame(width: 24, height: 24)

                            Text("Delete Category")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.primary)

                            Spacer()
                        }

	                        .padding(.horizontal, 20)
	                        .padding(.vertical, 16)
	                    }
	                    .flatButtonStyle()
	                    Divider()
                        .padding(.horizontal, 22)
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(mainBackgroundColor.ignoresSafeArea())
            .presentationDetents([.fraction(0.3)])
            .presentationCornerRadius(30)
            .edgeAttachedSheetStyle()
        } else {
            // Fallback for earlier iOS versions
            VStack(spacing: 0) {
                // 顶部拖拽指示器
                VStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 2.5)
                        .fill(Color.gray.opacity(0.4))
                        .frame(width: 36, height: 5)
                        .padding(.top, 8)
                        .padding(.bottom, 16)

                    // 向下箭头图标
                    Image(systemName: "chevron.down")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.gray)
                        .padding(.bottom, 20)
                }

                // 选项列表
                VStack(spacing: 0) {
                    // Change Category Name 选项
                    Button(action: {
                        showCategoryOptionsModal = false
                        newCategoryName = selectedCategory?.name ?? ""
                        categoryNameError = ""
                        showCategoryRenameSheet = true
                    }) {
                        HStack {
                            Image(systemName: "pencil")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.primary)
                                .frame(width: 24, height: 24)

                            Text("Change Category Name")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.primary)

                            Spacer()
	                        }
	                        .padding(.horizontal, 20)
	                        .padding(.vertical, 16)
	                    }
	                    .flatButtonStyle()

	                    Divider()
                        .padding(.horizontal, 20)

                    // Delete Category 选项
                    Button(action: {
                        showCategoryOptionsModal = false
                        checkAndDeleteCategory()
                    }) {
                        HStack {
                            Image(systemName: "trash")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.primary)
                                .frame(width: 24, height: 24)

                            Text("Delete Category")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.primary)

                            Spacer()
	                        }
	                        .padding(.horizontal, 20)
	                        .padding(.vertical, 16)
	                    }
	                    .flatButtonStyle()
	                }

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(mainBackgroundColor.ignoresSafeArea())
            .edgeAttachedSheetStyle()
        }
    }

    // 分类重命名视图
    @ViewBuilder
    private func categoryRenameView() -> some View {
        VStack(spacing: 0) {
            FlatModalHeader(title: "Change Category Name", showsSeparator: false) {
                Button("Cancel") {
                    newCategoryName = ""
                    categoryNameError = ""
                    showCategoryRenameSheet = false
                }
                .foregroundColor(.black)
                .flatButtonStyle()
            } trailing: {
                Button("Save") {
                    renameCategory()
                    showCategoryRenameSheet = false
                }
                .foregroundColor(.black)
                .disabled(newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !categoryNameError.isEmpty)
                .flatButtonStyle()
            }

            VStack(spacing: 28) {
                VStack(alignment: .leading, spacing: 6) {
                    TextField("Enter category name", text: $newCategoryName)
                        .frame(height: 36)
                        .font(.system(size: 18))
                        .textFieldStyle(PlainTextFieldStyle())
                        .onChange(of: newCategoryName) { _ in
                            validateCategoryName()
                        }
                        .overlay(
                            Divider()
                                .frame(height: 0.6)
                                .background(Color.black)
                                .opacity(0.1)
                                .padding(.bottom, 0)
                            , alignment: .bottom
                        )

                    if !categoryNameError.isEmpty {
                        Text(categoryNameError)
                            .font(.system(size: 14))
                            .foregroundColor(.red)
                            .padding(.top, 4)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 26)

                Spacer()
            }
        }
        .padding(.top, 8)
        .modifier(PresentationCornerRadiusModifier())
    }

    // MARK: - 数据操作方法

    private func saveData() {
        DataStore.shared.saveItems(items, doneItems, pinnedItems)
        refreshWidget()
    }

    private func refreshWidget() {
        WidgetCenter.shared.reloadTimelines(ofKind: "TodoWidget")
    }

    // MARK: - 分类管理方法

    private func validateCategoryName() {
        let trimmedName = newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedName.isEmpty {
            categoryNameError = ""
            return
        }

        // 调试信息：打印所有分类名称
        print("Debug: All categories: \(categories.map { $0.name })")
        print("Debug: Current selected category: \(selectedCategory?.name ?? "nil")")
        print("Debug: Checking name: '\(trimmedName)'")

        // 检查是否已存在同名分类（排除当前正在编辑的分类，不区分大小写）
        let existingCategory = categories.first(where: { $0.name.lowercased() == trimmedName.lowercased() && $0.id != selectedCategory?.id })
        if existingCategory != nil {
            print("Debug: Found duplicate category: \(existingCategory!.name)")
            categoryNameError = "Category name already exists"
        } else {
            print("Debug: No duplicate found")
            categoryNameError = ""
        }
    }

    private func renameCategory() {
        guard let selectedCategory = selectedCategory,
              !newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        let trimmedName = newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)

        // 检查是否已存在同名分类
        print("Debug renameCategory: All categories: \(categories.map { $0.name })")
        print("Debug renameCategory: Current selected category: \(selectedCategory.name)")
        print("Debug renameCategory: Checking name: '\(trimmedName)'")

        let existingCategory = categories.first(where: { $0.name.lowercased() == trimmedName.lowercased() && $0.id != selectedCategory.id })
        if existingCategory != nil {
            print("Debug renameCategory: Found duplicate category: \(existingCategory!.name)")
            categoryNameError = "Category name already exists"
            return
        } else {
            print("Debug renameCategory: No duplicate found")
        }

        // 更新分类名称
        if let index = categories.firstIndex(where: { $0.id == selectedCategory.id }) {
            categories[index].name = trimmedName
            self.selectedCategory = categories[index]

            // 添加振动反馈
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        }

        newCategoryName = ""
        categoryNameError = ""
    }

    private func checkAndDeleteCategory() {
        guard let selectedCategory = selectedCategory,
              selectedCategory.name != "To Do" else {
            return
        }

        // 检查该分类中是否有未完成的事项
        let unfinishedCount = items.filter { $0.categoryId == selectedCategory.id }.count +
                             pinnedItems.filter { $0.categoryId == selectedCategory.id }.count

        unfinishedItemsCount = unfinishedCount

        if unfinishedCount > 0 {
            // 有未完成事项，显示确认对话框
            showDeleteCategoryAlert = true
        } else {
            // 没有未完成事项，直接删除分类
            deleteCategoryOnly()
        }
    }

    private func deleteCategoryWithItems() {
        guard let selectedCategory = selectedCategory,
              selectedCategory.name != "To Do" else {
            return
        }

        // 取消要删除事项的所有通知
        let itemsToDelete = items.filter { $0.categoryId == selectedCategory.id }
        let pinnedItemsToDelete = pinnedItems.filter { $0.categoryId == selectedCategory.id }
        for item in itemsToDelete {
            NotificationHelper.cancelReminder(for: item)
        }
        for item in pinnedItemsToDelete {
            NotificationHelper.cancelReminder(for: item)
        }

        // 删除该分类下的所有未完成事项
        items.removeAll { $0.categoryId == selectedCategory.id }
        pinnedItems.removeAll { $0.categoryId == selectedCategory.id }

        // 将已完成事项移动到"To Do"分类
        let toDoCategory = categories.first { $0.name == "To Do" }
        for i in 0..<doneItems.count {
            if doneItems[i].categoryId == selectedCategory.id {
                doneItems[i].categoryId = toDoCategory?.id
            }
        }

        // 删除分类
        categories.removeAll { $0.id == selectedCategory.id }

        // 切换到"To Do"分类
        self.selectedCategory = toDoCategory

        // 添加振动反馈
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()

        // 保存数据
        saveData()
    }

    private func deleteCategoryOnly() {
        guard let selectedCategory = selectedCategory,
              selectedCategory.name != "To Do" else {
            return
        }

        // 将分类中的所有事项移动到"To Do"分类
        let toDoCategory = categories.first { $0.name == "To Do" }

        // 更新所有属于该分类的事项
        for i in 0..<items.count {
            if items[i].categoryId == selectedCategory.id {
                items[i].categoryId = toDoCategory?.id
            }
        }

        for i in 0..<pinnedItems.count {
            if pinnedItems[i].categoryId == selectedCategory.id {
                pinnedItems[i].categoryId = toDoCategory?.id
            }
        }

        for i in 0..<doneItems.count {
            if doneItems[i].categoryId == selectedCategory.id {
                doneItems[i].categoryId = toDoCategory?.id
            }
        }

        // 删除分类
        categories.removeAll { $0.id == selectedCategory.id }

        // 切换到"To Do"分类
        self.selectedCategory = toDoCategory

        // 添加振动反馈
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()

        // 保存数据
        saveData()
    }

    private func deleteCategory() {
        guard let selectedCategory = selectedCategory,
              selectedCategory.name != "To Do" else {
            return
        }

        // 将分类中的事项移动到"To Do"分类
        let toDoCategory = categories.first { $0.name == "To Do" }

        // 更新所有属于该分类的事项
        for i in 0..<items.count {
            if items[i].categoryId == selectedCategory.id {
                items[i].categoryId = toDoCategory?.id
            }
        }

        for i in 0..<pinnedItems.count {
            if pinnedItems[i].categoryId == selectedCategory.id {
                pinnedItems[i].categoryId = toDoCategory?.id
            }
        }

        for i in 0..<doneItems.count {
            if doneItems[i].categoryId == selectedCategory.id {
                doneItems[i].categoryId = toDoCategory?.id
            }
        }

        // 删除分类
        categories.removeAll { $0.id == selectedCategory.id }

        // 切换到"To Do"分类
        self.selectedCategory = toDoCategory

        // 保存数据
        saveData()
    }

    private func deleteItem(item: TodoItem) {
        // 取消与此事项相关的所有通知
        NotificationHelper.cancelReminder(for: item)

        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items.remove(at: index)
            saveData()
        }
    }

    private func deletePinnedItem(item: TodoItem) {
        // 取消与此事项相关的所有通知
        NotificationHelper.cancelReminder(for: item)

        if let index = pinnedItems.firstIndex(where: { $0.id == item.id }) {
            pinnedItems.remove(at: index)
            saveData()
        }
    }

    private func markAsDone(item: TodoItem) {
        // 取消与此事项相关的所有通知（完成的事项不应该继续提醒）
        NotificationHelper.cancelReminder(for: item)

        var updatedItem = item
        updatedItem.isDone = true
        updatedItem.doneDate = Date()

        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items.remove(at: index)
            doneItems.insert(updatedItem, at: 0)
        } else if let index = pinnedItems.firstIndex(where: { $0.id == item.id }) {
            pinnedItems.remove(at: index)
            doneItems.insert(updatedItem, at: 0)
        }
        saveData()
    }

    private func pinTransitionOpacity(for id: UUID) -> Double {
        (pinFadingOutItemIds.contains(id) || pinFadingInItemIds.contains(id)) ? 0 : 1
    }

    private func transitionPinState(for item: TodoItem, pin: Bool) {
        guard !pinFadingOutItemIds.contains(item.id), !pinFadingInItemIds.contains(item.id) else { return }

        withAnimation(.easeOut(duration: 0.24)) {
            _ = pinFadingOutItemIds.insert(item.id)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
            var transaction = Transaction()
            transaction.disablesAnimations = true

            withTransaction(transaction) {
                _ = pinFadingOutItemIds.remove(item.id)
                _ = pinFadingInItemIds.insert(item.id)

                if pin {
                    pinItem(item: item)
                } else {
                    unpinItem(item: item)
                }
            }

            DispatchQueue.main.async {
                withAnimation(.easeIn(duration: 0.24)) {
                    _ = pinFadingInItemIds.remove(item.id)
                }
            }
        }
    }

    private func pinItem(item: TodoItem) {
        var updatedItem = item
        updatedItem.isPinned = true

        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items.remove(at: index)
            pinnedItems.insert(updatedItem, at: 0)
        }
            saveData()
    }

    private func unpinItem(item: TodoItem) {
        var updatedItem = item
        updatedItem.isPinned = false

        if let index = pinnedItems.firstIndex(where: { $0.id == item.id }) {
            pinnedItems.remove(at: index)
            items.insert(updatedItem, at: 0)
        }
            saveData()
    }

    private func move(from source: IndexSet, to destination: Int) {
        // 获取当前分类的普通事项（非置顶、未完成）
        let currentItems = currentCategoryItems.filter { !$0.isPinned && !$0.isDone }

        // 验证索引是否有效
        guard !source.isEmpty, source.max()! < currentItems.count else { return }

        // 收集要移动的事项及其在全局数组中的原始索引
        var itemsToMove: [(item: TodoItem, originalIndex: Int)] = []
        for index in source {
            let item = currentItems[index]
            if let originalIndex = items.firstIndex(where: { $0.id == item.id }) {
                itemsToMove.append((item: item, originalIndex: originalIndex))
            }
        }

        // 按原始索引降序排列，避免移除时索引变化
        itemsToMove.sort { $0.originalIndex > $1.originalIndex }

        // 从全局数组中移除这些事项
        for (_, originalIndex) in itemsToMove {
            items.remove(at: originalIndex)
        }

        // 计算目标位置在全局数组中的索引
        // destination 参数已经考虑了拖拽方向，直接使用即可
        let finalTargetIndex: Int

        if destination >= currentItems.count {
            // 拖拽到最后一个位置：插入到全局数组的末尾
            finalTargetIndex = items.count
        } else {
            // 拖拽到中间位置：找到目标项在全局数组中的位置
            let targetItem = currentItems[destination]
            finalTargetIndex = items.firstIndex(where: { $0.id == targetItem.id }) ?? items.count
        }

        // 将移动的事项插入到新位置
        for (offset, (item, _)) in itemsToMove.enumerated() {
            let insertIndex = finalTargetIndex + offset
            let safeInsertIndex = min(max(insertIndex, 0), items.count)
            items.insert(item, at: safeInsertIndex)
        }

        saveData()
    }
    private func movePinnedItem(from source: IndexSet, to destination: Int) {
        // 获取当前分类的置顶事项
        let currentPinnedItems = currentCategoryPinnedItems

        // 验证索引是否有效
        guard !source.isEmpty, source.max()! < currentPinnedItems.count else { return }

        // 收集要移动的置顶事项及其在全局数组中的原始索引
        var itemsToMove: [(item: TodoItem, originalIndex: Int)] = []
        for index in source {
            let item = currentPinnedItems[index]
            if let originalIndex = pinnedItems.firstIndex(where: { $0.id == item.id }) {
                itemsToMove.append((item: item, originalIndex: originalIndex))
            }
        }

        // 按原始索引降序排列，避免移除时索引变化
        itemsToMove.sort { $0.originalIndex > $1.originalIndex }

        // 从全局pinnedItems中移除这些事项
        for (_, originalIndex) in itemsToMove {
            pinnedItems.remove(at: originalIndex)
        }

        // 计算目标位置在全局数组中的索引
        // destination 参数已经考虑了拖拽方向，直接使用即可
        let finalTargetIndex: Int

        if destination >= currentPinnedItems.count {
            // 拖拽到最后一个位置：插入到全局pinnedItems数组的末尾
            finalTargetIndex = pinnedItems.count
        } else {
            // 拖拽到中间位置：找到目标项在全局数组中的位置
            let targetItem = currentPinnedItems[destination]
            finalTargetIndex = pinnedItems.firstIndex(where: { $0.id == targetItem.id }) ?? pinnedItems.count
        }

        // 将移动的置顶事项插入到新位置
        for (offset, (item, _)) in itemsToMove.enumerated() {
            let insertIndex = finalTargetIndex + offset
            let safeInsertIndex = min(max(insertIndex, 0), pinnedItems.count)
            pinnedItems.insert(item, at: safeInsertIndex)
        }

        saveData()
    }


    private func deleteItems(at offsets: IndexSet, from categoryItems: [TodoItem]) {
        for offset in offsets {
            let itemToDelete = categoryItems[offset]
            // 取消与此事项相关的所有通知
            NotificationHelper.cancelReminder(for: itemToDelete)

            if let index = items.firstIndex(where: { $0.id == itemToDelete.id }) {
                items.remove(at: index)
            }
        }
        saveData()
    }


    private func showItemDetail(for id: UUID) {
        var targetItem: TodoItem?

        // 查找事项
        if let item = items.first(where: { $0.id == id }) {
            targetItem = item
        } else if let pinnedItem = pinnedItems.first(where: { $0.id == id }) {
            targetItem = pinnedItem
        }

        guard let item = targetItem else { return }

        // 如果事项有分类ID，先切换到对应分类
        if let categoryId = item.categoryId {
            if let targetCategory = categories.first(where: { $0.id == categoryId }) {
                // 切换到目标分类
                selectedCategory = targetCategory
            }
        } else {
            // 如果事项没有分类ID，切换到"To Do"分类（默认分类）
            if let toDoCategory = categories.first(where: { $0.name == "To Do" }) {
                selectedCategory = toDoCategory
            }
        }

        // 显示事项详情
        self.editingItem = item
        self.isCreatingNewItem = false
        self.showInputView = true
    }

    // 移动事项到其他分类
    private func moveItemToCategory(_ item: TodoItem, targetCategory: Category) {
        var updatedItem = item
        updatedItem.categoryId = targetCategory.id

        // 从当前分类中移除
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items.remove(at: index)
        } else if let index = pinnedItems.firstIndex(where: { $0.id == item.id }) {
            pinnedItems.remove(at: index)
        }

        // 添加到目标分类
        if item.isPinned {
            pinnedItems.insert(updatedItem, at: 0)
        } else {
            items.insert(updatedItem, at: 0)
        }

        // 添加振动反馈
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        saveData()
    }


    // 获取事项当前所属的分类ID（处理老数据兼容性）
    private func getCurrentCategoryIdForItem(_ item: TodoItem?) -> UUID? {
        guard let item = item else { return nil }

        // 如果事项有明确的分类ID，直接返回
        if let categoryId = item.categoryId {
            return categoryId
        }

        // 对于老数据（categoryId为nil），根据当前选中的分类来推断
        // 如果当前选中的是"To Do"分类，那么老数据应该属于"To Do"分类
        if let selectedCategory = selectedCategory, selectedCategory.name == "To Do" {
            return selectedCategory.id
        }

        // 如果当前没有选中分类，或者选中的不是"To Do"分类，返回nil
        return nil
    }

    // 显示分类选择器
    private func showCategorySelector(for item: TodoItem) {
        // 确保categories数组不为空
        if categories.isEmpty {
            // 如果categories为空，重新加载并确保有默认分类
            let reloadedCategories = DataStore.shared.loadCategories()
            if reloadedCategories.isEmpty {
                // 创建默认分类
                let defaultCategory = Category(name: "To Do")
                DataStore.shared.saveCategories([defaultCategory])
                categories = [defaultCategory]
            } else {
                categories = reloadedCategories
            }
        }

        itemToMove = item
        showCategorySelector = true
    }
}

// 分类选择器视图
struct CategorySelectorView: View {
    let categories: [Category]
    let currentCategoryId: UUID?
    let onSelectCategory: (Category) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Text(NSLocalizedString("Move to Category", comment: "Move item to category sheet title"))
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .center)

                HStack {
                    Button("Cancel") {
                        onCancel()
                    }
                    .foregroundColor(.primary)
                    .flatButtonStyle()

                    Spacer()
                }
            }
            .frame(height: 52)
            .padding(.horizontal, 20)
            .background(Color.white)
            .overlay(
                Divider()
                    .background(Color.black.opacity(0.08)),
                alignment: .bottom
            )

            Group {
                if categories.isEmpty {
                    VStack {
                        Spacer()
                        Text("No categories available")
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(categories) { category in
                                CategorySelectorRowView(
                                    category: category,
                                    isSelected: category.id == currentCategoryId,
                                    onTap: {
                                        onSelectCategory(category)
                                    }
                                )
                            }
                        }
                        .padding(.top, 20)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.top, 8)
        .modifier(PresentationCornerRadiusModifier())
    }
}

// 分类选择器行视图
struct CategorySelectorRowView: View {
    let category: Category
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 0) {
                // 选中指示器 - 放在最左侧，固定宽度
                HStack {
                    if isSelected {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 4))
                            .foregroundColor(.primary)
                    } else {
                        // 占位符，保持对齐
                        Image(systemName: "circle.fill")
                            .font(.system(size: 4))
                            .foregroundColor(.clear)
                    }
                }
                .frame(width: 16) // 固定宽度，确保对齐

                // 主要内容区域
                HStack(spacing: 16) {
                    // 分类名称
                    Text(category.name)
                        .font(.system(size: 18, weight: isSelected ? .bold : .regular))
                        .foregroundColor(.primary)

                    Spacer()
                }
            }
            .padding(.leading, 14)
            .padding(.trailing, 28)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .frame(maxWidth: .infinity)
    }
}

// 自定义修饰符：条件性应用 presentationCornerRadius
struct PresentationCornerRadiusModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.4, *) {
            content.presentationCornerRadius(30)
        } else {
            content
        }
    }
}

struct EdgeAttachedSheetModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.presentationSizing(.page)
        } else {
            content
        }
    }
}

// View 扩展：条件修饰符
extension View {
    func edgeAttachedSheetStyle() -> some View {
        modifier(EdgeAttachedSheetModifier())
    }

    @ViewBuilder func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }

    @ViewBuilder func `if`<Content: View>(_ condition: @autoclosure () -> Bool, transform: (Self) -> Content) -> some View {
        if condition() {
            transform(self)
        } else {
            self
        }
    }
}

// 预览提供者
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

extension Color {
    init(hex: String) {
        let hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)
        self.init(
            .sRGB,
            red: Double((rgb >> 16) & 0xFF) / 255.0,
            green: Double((rgb >> 8) & 0xFF) / 255.0,
            blue: Double(rgb & 0xFF) / 255.0,
            opacity: 1.0
        )
    }
}
