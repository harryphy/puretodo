//
//  ContentView.swift
//  Pure To Do
//
//  Created by PHY on 2023/12/8.
//  Version 0.998

import SwiftUI

// 定义 TodoItem 结构体
struct TodoItem: Identifiable, Codable {
    var id = UUID()
    var title: String
    var isDone: Bool
    var isPinned: Bool = false
    var date: Date
    var doneDate: Date? // 记录标记完成的日期
}

// 日期格式化
private let itemFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .none
    return formatter
}()

// 数据存储类
class DataStore {
    static let shared = DataStore()
    
    private let itemsKey = "todoItems"
    private let doneItemsKey = "doneTodoItems"
    
    func saveItems(_ items: [TodoItem], _ doneItems: [TodoItem], _ pinnedItems: [TodoItem]) {
        // 保存方法更新，增加了保存置顶事项的逻辑
        if let encodedItems = try? JSONEncoder().encode(items),
           let encodedDoneItems = try? JSONEncoder().encode(doneItems),
           let encodedPinnedItems = try? JSONEncoder().encode(pinnedItems) {
            UserDefaults.standard.set(encodedItems, forKey: itemsKey)
            UserDefaults.standard.set(encodedDoneItems, forKey: doneItemsKey)
            UserDefaults.standard.set(encodedPinnedItems, forKey: "pinnedTodoItems")
        }
    }
    
    
    func loadItems() -> [TodoItem] {
        if let itemsData = UserDefaults.standard.data(forKey: itemsKey),
           let items = try? JSONDecoder().decode([TodoItem].self, from: itemsData) {
            return items
        }
        return []
    }
    
    func loadDoneItems() -> [TodoItem] {
        if let doneItemsData = UserDefaults.standard.data(forKey: doneItemsKey),
           let doneItems = try? JSONDecoder().decode([TodoItem].self, from: doneItemsData) {
            return doneItems
        }
        return []
    }
    
    func loadPinnedItems() -> [TodoItem] {
        // 加载置顶事项的方法
        if let pinnedItemsData = UserDefaults.standard.data(forKey: "pinnedTodoItems"),
           let pinnedItems = try? JSONDecoder().decode([TodoItem].self, from: pinnedItemsData) {
            return pinnedItems
        }
        return []
    }
}


// 输入视图，用于新增和编辑事项
struct InputView: View {
    @Binding var text: String
    var onSave: (String) -> Void
    @FocusState private var isInputActive: Bool
    
    var body: some View {
        VStack {
            TextField("Type in here", text: $text, onCommit: {
                if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    onSave(text)
                }
            })
            .font(.system(size: 20))
            .focused($isInputActive)
            .keyboardType(.default) // 或者选择适合的键盘类型
            .submitLabel(.done) // 设置键盘上确认键的标签为 'Done'
            .textFieldStyle(PlainTextFieldStyle())
            .padding()
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    self.isInputActive = true
                }
            }
        }
    }
}

// ContentView 结构
struct ContentView: View {
    @State private var items: [TodoItem] = DataStore.shared.loadItems()
    @State private var pinnedItems: [TodoItem] = DataStore.shared.loadPinnedItems()
    @State private var doneItems: [TodoItem] = DataStore.shared.loadDoneItems()
    @State private var showInputView = false
    @State private var inputText = ""
    @State private var editingItem: TodoItem?
    @State private var selectedItemId: UUID? // 添加用于存储被选中事项 ID 的状态
    @State private var selectedPinnedItemId: UUID?
    
    init() {
        // 加载已存储的事项
        let storedItems = DataStore.shared.loadItems()
        let storedDoneItems = DataStore.shared.loadDoneItems()
        
        // 检查是否是第一次启动应用
        if ContentView.isFirstLaunch() {
            // 添加默认事项
            let defaultItems = [
                TodoItem(title: "↓ Pull down to create a new", isDone: false, date: Date()),
                TodoItem(title: "→ Swipe right to mark done", isDone: false, date: Date()),
                TodoItem(title: "← Swipe left to delete", isDone: false, date: Date())
            ]
            _items = State(initialValue: defaultItems + storedItems)
            _doneItems = State(initialValue: storedDoneItems) // 确保加载已完成事项
            UserDefaults.standard.set(true, forKey: "HasLaunchedOnce")
        } else {
            _items = State(initialValue: storedItems)
            _doneItems = State(initialValue: storedDoneItems) // 确保加载已完成事项
        }
    }
    
    private static func isFirstLaunch() -> Bool {
        return !UserDefaults.standard.bool(forKey: "HasLaunchedOnce")
    }
    
    var body: some View {
        // To Do View
        NavigationView {
            Group {
                if items.isEmpty && pinnedItems.isEmpty {
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
                    // 事项列表
                    List {
                        // 显示置顶区域
                        if !pinnedItems.isEmpty {
                            Section(header: HStack {
                            })  {
                                ForEach($pinnedItems) { $pinnedItem in
                                    HStack {
                                        Text($pinnedItem.title.wrappedValue)
                                            .fontWeight(.bold)
                                            .opacity(selectedPinnedItemId == $pinnedItem.id.wrappedValue ? 0.6 : 1.0)
                                        Spacer()  // 添加一个Spacer来填满整行
                                    }
                                    .frame(minHeight: 38) // 确保行有最小高度
                                    .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                                    .contentShape(Rectangle())  // 使整个行区域可点击
                                    .onTapGesture {
                                        self.selectedPinnedItemId = $pinnedItem.id.wrappedValue
                                        self.editingItem = $pinnedItem.wrappedValue
                                        self.inputText = $pinnedItem.title.wrappedValue
                                        self.showInputView = true
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                            self.selectedPinnedItemId = nil // 延时后重置选中项
                                        }
                                    }
                                    
                                    // 滑动删除的功能
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            withAnimation {
                                                deletePinnedItem(item: $pinnedItem.wrappedValue)
                                            }
                                        } label: {
                                            Label("Delete", systemImage: "trash.fill")
                                        }
                                    }
                                    // 滑动标记完成的功能
                                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                        Button {
                                            withAnimation {
                                                markAsDone(item:$pinnedItem.wrappedValue)
                                            }
                                        } label: {
                                            Label("Done", systemImage: "checkmark")
                                        }
                                        .tint(.green)
                                    }
                                    // 滑动取消置顶的功能
                                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                        Button {
                                            withAnimation {
                                                unpinItem(item: $pinnedItem.wrappedValue)
                                            }
                                        } label: {
                                            Label("Unpin", systemImage: "pin.slash.fill")
                                        }
                                        .tint(.orange)
                                    }
                                }
                                .onMove(perform: movePinnedItem)
                            }
                            
                        }
                        
                        // 原有的事项展示逻辑
                        ForEach($items) { $item in
                            if !$item.isDone.wrappedValue {
                                HStack {
                                    Text($item.title.wrappedValue)
                                        .fontWeight(selectedItemId == $item.id.wrappedValue ? .bold : .regular)
                                        .opacity(selectedItemId == $item.id.wrappedValue ? 0.6 : 1.0)
                                    Spacer()  // 添加一个Spacer来填满整行
                                }
                                .frame(minHeight: 38) // 确保行有最小高度
                                .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                                .contentShape(Rectangle())  // 使整个行区域可点击
                                .onTapGesture {
                                    self.selectedItemId = $item.id.wrappedValue // 更新选中事项的 ID
                                    self.editingItem = $item.wrappedValue
                                    self.inputText = $item.title.wrappedValue
                                    self.showInputView = true
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                        self.selectedItemId = nil // 延时后重置选中项
                                    }
                                }
                                // 滑动删除的功能
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        withAnimation {
                                            deleteItem(item: $item.wrappedValue)
                                        }
                                    } label: {
                                        Label("Delete", systemImage: "trash.fill")
                                    }
                                }
                                // 滑动标记完成的功能
                                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                    Button {
                                        withAnimation {
                                            markAsDone(item: $item.wrappedValue)
                                        }
                                    } label: {
                                        Label("Done", systemImage: "checkmark")
                                    }
                                    .tint(.green)
                                }
                                // 滑动置顶的功能
                                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                    Button {
                                        withAnimation {
                                            pinItem(item: $item.wrappedValue)
                                        }
                                    } label: {
                                        Label("Pin", systemImage: "pin.fill")
                                    }
                                    .tint(.orange)
                                }
                            }
                        }
                        .onMove(perform: move)
                        .onDelete { offsets in
                            withAnimation {
                                deleteItems(at: offsets)
                            }
                        }
                    }
                }
            }
            .navigationTitle("To Do")
            .navigationBarItems(trailing: NavigationLink(destination: DonePage(doneItems: $doneItems, saveData: saveData)) {
                Image(systemName: "checkmark.rectangle.stack.fill")
                    .foregroundColor(.primary)
            })
            .refreshable {
                showInputView = true
                inputText = ""
                editingItem = nil
            }
        }
        
        .sheet(isPresented: $showInputView) {
            ZStack {
                Color.black.opacity(0.1)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        showInputView = false
                    }
                
                InputView(text: $inputText) { input in
                    if !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        if let editingItem = editingItem {
                            updateItem(item: editingItem, with: input)
                        } else {
                            addItem(title: input)
                        }
                    }
                    showInputView = false
                    editingItem = nil
                }
                .frame(width: 380)
            }
        }
    }
    
    // Done 页面的视图
    struct DonePage: View {
        @Binding var doneItems: [TodoItem]
        var saveData: () -> Void  // 保存数据的闭包
        
        private var groupedItems: [Date: [TodoItem]] {
            Dictionary(grouping: doneItems) { item in
                Calendar.current.startOfDay(for: item.doneDate ?? item.date) // 使用完成日期进行分组，如果没有则使用创建日期
            }
        }
        
        private var sortedDates: [Date] {
            groupedItems.keys.sorted().reversed() // 日期降序
        }
        
        var body: some View {
            List {
                ForEach(sortedDates, id: \.self) { date in
                    Section(header: Text(date, formatter: itemFormatter)
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading) // 确保文本对齐
                        .padding(.leading, -16) // 添加与标题相同的左边距
                    ) {
                        ForEach(groupedItems[date] ?? [], id: \.id) { item in
                            Text(item.title)
                                .strikethrough()
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        deleteDoneItem(item, on: date)
                                    } label: {
                                        Label("Delete", systemImage: "trash.fill")
                                    }
                                }
                        }
                        .onDelete { offsets in
                            deleteDoneItems(at: offsets, on: date)
                        }
                    }
                }
            }
            .navigationTitle("Done")
        }
        
        private func deleteDoneItem(_ item: TodoItem, on date: Date) {
            doneItems.removeAll { $0.id == item.id }
            saveData()  // 确保变更保存到 UserDefaults
            HapticFeedbackGenerator.triggerLightFeedback()
        }
        
        private func deleteDoneItems(at offsets: IndexSet, on date: Date) {
            if let dateGroup = groupedItems[date] {
                let idsToDelete = offsets.map { dateGroup[$0].id }
                doneItems.removeAll { idsToDelete.contains($0.id) }
                saveData()  // 确保变更保存到 UserDefaults
                HapticFeedbackGenerator.triggerLightFeedback()
            }
        }
    }
    
    // 函数定义
    struct HapticFeedbackGenerator {
        static func triggerLightFeedback() {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        }
    }
    
    func triggerFeedback() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    func triggerLightFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
    
    private func deletePinnedItem(item: TodoItem) {
        pinnedItems.removeAll { $0.id == item.id }
        saveData()  // 保存数据
        triggerLightFeedback()
    }
    
    private func pinItem(item: TodoItem) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            var pinnedItem = items.remove(at: index)
            pinnedItem.isPinned = true
            pinnedItems.insert(pinnedItem, at: 0)
            saveData()
            triggerLightFeedback()
        }
    }
    
    private func unpinItem(item: TodoItem) {
        if let index = pinnedItems.firstIndex(where: { $0.id == item.id }) {
            var unpinnedItem = pinnedItems.remove(at: index)
            unpinnedItem.isPinned = false
            items.insert(unpinnedItem, at: 0)
            saveData()
            triggerLightFeedback()
        }
    }
    
    private func movePinnedItem(from source: IndexSet, to destination: Int) {
        pinnedItems.move(fromOffsets: source, toOffset: destination)
        saveData()
    }
    
    private func saveData() {
        DataStore.shared.saveItems(items, doneItems, pinnedItems)
    }
    
    private func updateItem(item: TodoItem, with newTitle: String) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index].title = newTitle
            saveData()
        } else if let pinnedIndex = pinnedItems.firstIndex(where: { $0.id == item.id }) {
            pinnedItems[pinnedIndex].title = newTitle
            saveData()
        }
        triggerLightFeedback() // 触发震动反馈
    }
    
    func move(from source: IndexSet, to destination: Int) {
        items.move(fromOffsets: source, toOffset: destination)
        saveData()  // 保存数据
    }
    
    private func addItem(title: String) {
        let newItem = TodoItem(title: title, isDone: false, date: Date())
        items.insert(newItem, at: 0)
        saveData()  // 保存数据
        triggerLightFeedback() // 触发震动反馈
    }
    
    private func deleteItem(item: TodoItem) {
        items.removeAll { $0.id == item.id }
        saveData()  // 保存数据
        triggerLightFeedback()
    }
    
    private func deleteItems(at offsets: IndexSet) {
        items.remove(atOffsets: offsets)
        saveData()  // 保存数据
        triggerLightFeedback()
    }
    
    private func markAsDone(item: TodoItem) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            var doneItem = items.remove(at: index)
            doneItem.isDone = true
            doneItem.doneDate = Date() // 设置完成日期为当前日期
            doneItems.insert(doneItem, at: 0)
            saveData()
        } else if let pinnedIndex = pinnedItems.firstIndex(where: { $0.id == item.id }) {
            var doneItem = pinnedItems.remove(at: pinnedIndex)
            doneItem.isDone = true
            doneItem.doneDate = Date() // 设置完成日期为当前日期
            doneItems.insert(doneItem, at: 0)
            saveData()
        }
        triggerFeedback() // 触发震动反馈
    }
}
// 预览提供者
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

