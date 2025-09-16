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
                if location.x < 25 && translation.x > 10 && !hasTriggered {
                    hasTriggered = true
                    onEdgePan()
                }
                
            case .ended:
                // 最终确认：如果从边缘开始且滑动距离足够
                if location.x < 25 && translation.x > 5 && !hasTriggered {
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
                                .font(.system(size: 12))
                                .foregroundColor(Color.black.opacity(0.3))
                                .padding(.trailing, -5)
                        }
                        Text(formatDate(reminderDate))
                            .font(.system(size: 12))
                            .foregroundColor(Color.black.opacity(0.3))
                    }
                }
            case .daily:
                if let reminderTime = item.reminderTime {
                    HStack {
                        Image(systemName: "clock")
                            .font(.system(size: 12))
                            .foregroundColor(Color.black.opacity(0.3))
                            .padding(.trailing, -5)
                        Text("Daily at \(formatTime(reminderTime))")
                            .font(.system(size: 12))
                            .foregroundColor(Color.black.opacity(0.3))
                    }
                }
            case .weekly:
                if let reminderTime = item.reminderTime, let weekdays = item.reminderWeekdays {
                    HStack {
                        Image(systemName: "clock")
                            .font(.system(size: 12))
                            .foregroundColor(Color.black.opacity(0.3))
                            .padding(.trailing, -5)
                        let weekdaysString = weekdays.sorted().map { weekdaySymbol(for: $0) }.joined(separator: ", ")
                        Text("\(weekdaysString) \(formatTime(reminderTime))")
                            .font(.system(size: 12))
                            .foregroundColor(Color.black.opacity(0.3))
                            .lineLimit(1)
                    }
                }
            case .monthly:
                if let reminderTime = item.reminderTime, let daysOfMonth = item.reminderDaysOfMonth {
                    HStack {
                        Image(systemName: "clock")
                            .font(.system(size: 12))
                            .foregroundColor(Color.black.opacity(0.3))
                            .padding(.trailing, -5)
                        let daysString = daysOfMonth.sorted().map { "\($0)" }.joined(separator: ", ")
                        Text("Monthly on \(daysString) at \(formatTime(reminderTime))")
                            .font(.system(size: 12))
                            .foregroundColor(Color.black.opacity(0.3))
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
    
    var body: some View {
        VStack(alignment: .leading) {
            Spacer().frame(height: 15)
            HStack(alignment: .top) {
                Text(item.title)
                    .font(.system(size: 18))
                    .fontWeight(isPinned ? .semibold : (selectedItemId == item.id ? .bold : .regular))
                    .opacity(selectedItemId == item.id ? 0.6 : 1.0)
                Spacer()
                if !item.subItems.filter({ !$0.isDone }).isEmpty {
                    Text("\(item.subItems.filter({ !$0.isDone }).count)")
                        .foregroundColor(Color.black.opacity(0.25))
                        .font(.system(size: 18))
                        .padding(.trailing, 2)
                }
            }
            Spacer().frame(height: 4)
            ReminderInfoView(item: item)
            Spacer().frame(height: 11)
        }
        .frame(minHeight: 48)
        .listRowInsets(EdgeInsets(top: 0, leading: 28, bottom: 0, trailing: 28))
        .overlay(
            Divider()
                .frame(height: 1)
                .background(Color.black)
                .opacity(0.05)
                .padding(.bottom, 0)
            , alignment: .bottom
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .background(Color.white)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
                onDelete()
            } label: {
                Label("", systemImage: "trash.fill")
            }
            .tint(.red)
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
                    .frame(width: 20, height: 20)
            }
            .tint(.green)
            if isPinned {
                Button {
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    onUnpin()
                } label: {
                    Label("", systemImage: "pin.slash.fill")
                }
                .tint(.orange)
            } else {
                Button {
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    onPin()
                } label: {
                    Label("", systemImage: "pin.fill")
                }
                .tint(.orange)
            }
            Button {
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
                onMoveToCategory()
            } label: {
                Label("", systemImage: "arrowshape.turn.up.right.fill")
            }
            .tint(.blue)
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
    @State private var showCategoryRenameAlert = false
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
    @State private var isRefreshing = false
    @State private var showPurchaseSheet = false
    @State private var featuresUnlockedObserver: NSObjectProtocol?
    
    @State private var showRating = false // 控制弹窗显示
    @State private var isInDonePage = false // 跟踪是否在 Done 页面
    @State private var showCategorySelector = false // 控制分类选择器显示
    @State private var itemToMove: TodoItem? // 要移动的事项
    
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
                TodoItem(title: NSLocalizedString("↓ Pull down the page to create a new", comment: "Create new item"), isDone: false, date: Date(), categoryId: defaultCategory.id),
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
            .padding()
            Spacer()
        }
    }
    
    // MARK: - 视图组件
    
    // 主头部视图
    @ViewBuilder
    private var mainHeaderView: some View {
        VStack(spacing: 0) {
            // 加高的导航栏
            Rectangle()
                .fill(Color.white)
                .frame(height: 40)
                .overlay(
                    HStack(alignment: .center, spacing: 0) {
                        
                        // 分类标题（可点击）
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showCategoryDrawer = true
                            }
                        }) {
                            Text(selectedCategory?.name ?? "To Do")
                                .foregroundColor(.black)
                                .font(.system(size: 38, weight: .bold))
                        }
                        .buttonStyle(CategoryNameButtonStyle())
                        .padding(.leading, 27)
                        Spacer()
                    }
                    .padding(.top, 16)
                )
            
            Spacer().frame(height: 30)
            Capsule().fill(Color.black).frame(height: 1.6).padding(.horizontal, 28)
            Spacer().frame(height: 3)
            Capsule().fill(Color.black).frame(height: 1).frame(maxWidth: .infinity).opacity(0.12).padding(.horizontal, 28)
            Spacer().frame(height: 0)
        }
    }
    
    // 主内容视图
    @ViewBuilder
    private var mainContentView: some View {
        if currentCategoryItems.isEmpty && currentCategoryPinnedItems.isEmpty {
            if #available(iOS 16, *) {
                ScrollView {
                    VStack {
                        Spacer().frame(height: 230)
                        HStack {
                            Spacer()
                            Text("Pull down to add a to-do")
                                .foregroundColor(.gray)
                            Spacer()
                        }
                        Spacer()
                    }
                }
            } else {
                addButtonView
            }
        } else {
            List {
                // 置顶事项部分
                if !currentCategoryPinnedItems.isEmpty {
                    Section(header: EmptyView()) {
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
                                    withAnimation {
                                        unpinItem(item: pinnedItem)
                                    }
                                },
                                onMoveToCategory: {
                                    showCategorySelector(for: pinnedItem)
                                }
                            )
                        }
                        .onMove(perform: movePinnedItem)
                    }
                    .listRowSeparator(.hidden)
                }
                
                // 分割线
                if !currentCategoryItems.isEmpty && !currentCategoryPinnedItems.isEmpty {
                    VStack {
                        Spacer().frame(height: 44)
                        Capsule().fill(Color.black).frame(height: 1.6).frame(maxWidth: .infinity)
                        Spacer().frame(height: 3)
                        Capsule().fill(Color.black).frame(height: 1).frame(maxWidth: .infinity).opacity(0.12)
                        Spacer().frame(height: 0)
                    }
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 0, leading: 28, bottom: 0, trailing: 28))
                }
                
                // 普通事项部分
                Section(header: EmptyView()) {
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
                                withAnimation {
                                    pinItem(item: item)
                                }
                            },
                            onUnpin: {},
                            onMoveToCategory: {
                                showCategorySelector(for: item)
                            }
                        )
                    }
                    .onMove(perform: move)
                    .onDelete { offsets in
                        withAnimation {
                            deleteItems(at: offsets, from: currentCategoryItems)
                        }
                    }
                }
                .listRowSeparator(.hidden)
                .padding(.top, 0)
            }
            .listStyle(PlainListStyle())
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
    
    // 导航栏右侧按钮
    @ViewBuilder
    private var navigationBarTrailingButton: some View {
        HStack(spacing: 6) {
            // 如果不是"To Do"分类，显示三个点的more图标
            if let selectedCategory = selectedCategory, selectedCategory.name != "To Do" {
                Button(action: {
                    showCategoryOptionsModal = true
                }) {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(width: 20, height: 20)
                        .rotationEffect(.degrees(90))
                        .padding(.top, 8)
                }
            }
            
            // Done页面图标
            NavigationLink(destination: DonePage(items: $items, doneItems: $doneItems, saveData: saveData, categories: categories)
                .onAppear {
                    isInDonePage = true
                }
                .onDisappear {
                    isInDonePage = false
                }
            ) {
                Image("logoshape")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 28)
                    .padding(.top, 10)
            }
        }
        .padding(.trailing, 10)
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
            .transition(.move(edge: .leading))
            .zIndex(2)
        }
    }
    
    // 边缘手势视图 - 可靠的手势检测
    @ViewBuilder
    private var edgeGestureView: some View {
        if !showCategoryDrawer && !isInDonePage {
                    // 主要边缘手势区域
        Rectangle()
            .fill(Color.clear)
            .frame(width: 20, height: .infinity)
            .contentShape(Rectangle())
            .allowsHitTesting(true)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let isFromEdge = value.startLocation.x < 20
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
                        let isFromEdge = value.startLocation.x < 20
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
            
            // 备用方案：UIKit 手势识别器
            SimpleEdgePanGesture {
                if !isGestureActive {
                    isGestureActive = true
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showCategoryDrawer = true
                    }
                    // 重置手势状态
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        isGestureActive = false
                    }
                }
            }
            .frame(maxWidth: 20, maxHeight: .infinity)
            .allowsHitTesting(true)
            .zIndex(101)
        }
    }
    
    
    var body: some View {
        ZStack {
            NavigationView {
                VStack(alignment: .leading) {
                    mainHeaderView
                    mainContentView
                }
                .simultaneousGesture(edgePanGesture)
                .refreshable {
                    handleRefresh()
                }
                .navigationBarTitleDisplayMode(.inline)
                .navigationBarItems(trailing: navigationBarTrailingButton)
                .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowTodoDetail")), perform: { notification in
                    if let todoId = notification.object as? UUID {
                        openInputView(for: todoId)
                    }
                })
                .onAppear(perform: setupObservers)
                .onDisappear(perform: cleanupObservers)
            }
            
            categoryDrawerOverlay
            categoryDrawerView
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
        .alert("Change Category Name", isPresented: $showCategoryRenameAlert) {
            TextField("Category Name", text: $newCategoryName)
            Button("Cancel", role: .cancel) {
                newCategoryName = ""
            }
            Button("Save") {
                renameCategory()
            }
        }
        .alert("Delete Category", isPresented: $showDeleteCategoryAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteCategoryWithItems()
            }
        } message: {
            if unfinishedItemsCount > 0 {
                Text("This category contains \(unfinishedItemsCount) to-do item\(unfinishedItemsCount == 1 ? "" : "s"). Deleting the category will also delete all the to-do items. Are you sure you want to continue?")
            } else {
                Text("Are you sure you want to delete this category?")
            }
        }
        .onChange(of: categories) { _ in
            DataStore.shared.saveCategories(categories)
        }
    }
    
    // MARK: - 手势和事件处理方法
    
    // 边缘滑动手势
    private var edgePanGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if isInDonePage {
                    // 在 Done 页面时，只处理从最左边缘开始的滑动，避免干扰列表项手势
                    let isFromVeryEdge = value.startLocation.x < 18
                    let hasEnoughTranslation = value.translation.width > 4
                    let isRightDirection = value.translation.width > 0
                    
                    if isFromVeryEdge && hasEnoughTranslation && isRightDirection {
                        // 触发返回操作
                        DispatchQueue.main.async {
                            // 发送通知给 Done 页面执行返回操作
                            NotificationCenter.default.post(name: NSNotification.Name("DismissDonePage"), object: nil)
                        }
                    }
                } else {
                    // 在主页面时，支持打开分类抽屉
                    let isFromEdge = value.startLocation.x < 20
                                            let hasEnoughTranslation = value.translation.width > 5
                    let isRightDirection = value.translation.width > 0
                    
                    if isFromEdge && hasEnoughTranslation && isRightDirection && !showCategoryDrawer && !isGestureActive {
                        isGestureActive = true
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showCategoryDrawer = true
                        }
                    }
                }
            }
            .onEnded { value in
                // 重置手势状态
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isGestureActive = false
                }
            }
    }
    
    // 处理刷新事件
    private func handleRefresh() {
        // 标记开始刷新
        isRefreshing = true
        
        // 处理你希望在刷新时做的事，比如打开弹窗
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            // 模拟延迟以模拟刷新完成
            isRefreshing = false // 标记刷新完成，关闭 spinner
            
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
                    Divider()
                        .padding(.horizontal, 22)
                }
                
                Spacer()
            }
            .presentationDetents([.fraction(0.3)])
            .presentationCornerRadius(30)
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
                }
                
                Spacer()
            }
        }
    }
    
    // 分类重命名视图
    @ViewBuilder
    private func categoryRenameView() -> some View {
        if #available(iOS 16.4, *) {
            NavigationView {
                VStack(spacing: 0) {
                    // 顶部间距，向下移动8
                    Spacer().frame(height: 8)
                    
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
                        .padding(.top, 18)
                        
                        Spacer()
                    }
                }
                .navigationTitle("Change Category Name")
                .navigationBarTitleDisplayMode(.inline)
                .navigationBarItems(
                    leading: Button("Cancel") {
                        newCategoryName = ""
                        categoryNameError = ""
                        showCategoryRenameSheet = false
                    }
                    .foregroundColor(.black)
                    .padding(.leading, 8),
                    trailing: Button("Save") {
                        renameCategory()
                        showCategoryRenameSheet = false
                    }
                    .foregroundColor(.black)
                    .disabled(newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !categoryNameError.isEmpty)
                    .padding(.trailing, 8)
                )
            }
            .padding(.top, 8)
            .presentationCornerRadius(30)
        } else {
            // Fallback for earlier iOS versions
            NavigationView {
                VStack(spacing: 0) {
                    // 顶部间距，向下移动8
                    Spacer().frame(height: 8)
                    
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
                        .padding(.top, 18)
                        
                        Spacer()
                    }
                }
                .navigationTitle("Change Category Name")
                .navigationBarTitleDisplayMode(.inline)
                .navigationBarItems(
                    leading: Button("Cancel") {
                        newCategoryName = ""
                        categoryNameError = ""
                        showCategoryRenameSheet = false
                    }
                    .foregroundColor(.black)
                    .padding(.leading, 8),
                    trailing: Button("Save") {
                        renameCategory()
                        showCategoryRenameSheet = false
                    }
                    .foregroundColor(.black)
                    .disabled(newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !categoryNameError.isEmpty)
                    .padding(.trailing, 8)
                )
            }
            .padding(.top, 8)
        }
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
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items.remove(at: index)
            saveData()
        }
    }
    
    private func deletePinnedItem(item: TodoItem) {
        if let index = pinnedItems.firstIndex(where: { $0.id == item.id }) {
            pinnedItems.remove(at: index)
            saveData()
        }
    }
    
    private func markAsDone(item: TodoItem) {
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
        NavigationView {
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
            .navigationTitle("Move to Category")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    onCancel()
                }
                .foregroundColor(.primary)
                .padding(.leading, 12)
            )
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

// View 扩展：条件修饰符
extension View {
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

