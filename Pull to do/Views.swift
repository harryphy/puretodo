//  Views.swift
//  Pure To Do
//
//  Created by PHY on 2023/12/8.
//  Version 2.4

import SwiftUI
import MessageUI

struct RatingView: View {
    @State private var isMailViewPresented = false
    @State private var isRatingViewPresented = false

    var body: some View {
        VStack {
        Spacer()
        Spacer().frame(height:2)
        Text ("🥰 Leave a 5-star review for the hard-working developer!")
            .font(.system(size: 18))
            .lineSpacing(4) // 设置行间距
            .multilineTextAlignment(.center)
            .padding(.horizontal,24)
            .fontWeight(.medium)
        Spacer().frame(height:10)
        Text ("Your feedback and suggestions really matter~")
            .font(.system(size: 14))
            .foregroundColor(.gray)
            .multilineTextAlignment(.center)
            .padding(.horizontal,24)
        Spacer().frame(height: 28)
        HStack(spacing: 10) {
            ForEach(0..<5, id: \.self) { index in
                Image(systemName: "star")
                    .foregroundColor(.black.opacity(0.8))
                    .onTapGesture {
                        handleStarTap(index: index)
                    }
                    .font(.system(size: 24))
                    .frame(width: 40, height: 40)
            }
        }
        Spacer().frame(height:12)
        Spacer()
    }
    .frame(height: 280)
}

private func handleStarTap(index: Int) {
    if index < 3 {
        // 调起邮件应用
        let mailtoLink = "<mailto:phya9@me.com>?subject=\(NSLocalizedString("PURE TO DO FeedbacK", comment: ""))"
        if let url = URL(string: mailtoLink) {
            UIApplication.shared.open(url)
        }
    } else {
        // 点击第 4 和第 5 颗星星，跳转到 App Store 给 App 评分
        if let url = URL(string: "itms-apps://itunes.apple.com/app/6476076472?action=write-review") {
            UIApplication.shared.open(url)
        }
    }
}

}

struct PurchasePromptView: View {
    var onPurchase: () -> Void
    var onRestore: () -> Void
    var onCancel: () -> Void

    @Environment(\.colorScheme) var colorScheme // 获取当前颜色模式

    var body: some View {
        VStack {
        Spacer()
        Spacer().frame(height: 12)
        Text("You've reached the free version limit of 10 to-do items. Complete some to add more.")
            .font(.system(size: 18))
            .lineSpacing(6) // 设置行间距
            .multilineTextAlignment(.center)
            .padding(.horizontal,32)

        Spacer().frame(height: 28)

        Button(action: {
            onCancel()
        }) {
            Text("OK")
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 28)
                .padding()
                .background(Color.black.opacity(0.9))
                .foregroundColor(.white)
                .cornerRadius(10)
        }
        .padding(.horizontal, 28)

        Spacer().frame(height: 20)

        Button(action: {
            onPurchase()
        }) {
            HStack(spacing: 8) { // 设置图标和文字之间的间距
                Image(systemName: "lock.open.fill")
                    .foregroundColor(.primary)
                    .font(.system(size: 20))

                Text("Unlock the full version")
                    .font(.system(size: 18))
                    .foregroundColor(.black)
            }
            .frame(maxWidth: .infinity, minHeight: 28) // 让整个按钮内容水平居中
            .padding()
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.black, lineWidth: 1.6)
            )
        }
        .padding(.horizontal, 28)

        Spacer().frame(height: 56)

        Button(action: {
            onRestore()
        }) {
            Text("Restore Purchase")
                .font(.system(size: 18))
                .frame(maxWidth: .infinity)
                .foregroundColor(.black)
        }
        .padding(.horizontal, 28)
        .frame(height: 20)
        Spacer().frame(height: 36)
    }
    .frame(height: 436)
}

}

struct DonePage: View {
    @Binding var items: [TodoItem]
    @Binding var doneItems: [TodoItem]
    var saveData: () -> Void  // 保存数据的闭包
    @State private var showDetailView = false
    @State private var selectedDetailItem: TodoItem?
    @Environment(\.presentationMode) var presentationMode // 用于关闭视图

    private var groupedItems: [Date: [TodoItem]] {
        Dictionary(grouping: doneItems) { item in
            Calendar.current.startOfDay(for: item.doneDate ?? item.date) // 使用完成日期进行分组，如果没有则使用创建日期
        }
    }

    private var sortedDates: [Date] {
        groupedItems.keys.sorted().reversed() // 日期降序
    }

    private var doneCount: Int {
        doneItems.count
    }

    // 新增：计算当前月份完成的事项数
    private var currentMonthDoneCount: Int {
        let calendar = Calendar.current
        let now = Date()
        let currentMonth = calendar.component(.month, from: now)
        let currentYear = calendar.component(.year, from: now)

        return doneItems.filter { item in
            guard let doneDate = item.doneDate else { return false }
            let itemMonth = calendar.component(.month, from: doneDate)
            let itemYear = calendar.component(.year, from: doneDate)
            return itemMonth == currentMonth && itemYear == currentYear
        }.count
    }

    var body: some View {
        List {
            VStack {
                Spacer().frame(height: 2)
                Image("backgroundbanner")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 28))
                    .clipped() // 防止图片溢出
                    .padding(6)
                Spacer()
            }

            .overlay(
                VStack {
                    Spacer().frame(height: 60)

                    // 显示当前月份完成的事项数
                    Image("checkDE")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 36)
                        .padding(.leading,0)

                    Spacer().frame(height: 10)
                    Text("\(currentMonthDoneCount) Items Finished in \(currentMonthName())")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(Color.white)

                    Spacer().frame(height: 6)

                    Text("\(doneCount) Done Items Recorded")
                        .font(.system(size: 13))
                        .foregroundColor(Color.white.opacity(0.45))

                    Spacer()
                }
            )
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 0, leading: 18, bottom: 0, trailing: 18))

            // 已完成的事项列表
            ForEach(sortedDates, id: \.self) { date in
                Section(header: Text(date, formatter: itemFormatter)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(Color.black.opacity(0.25))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .listRowBackground(Color.white)
                ) {
                    ForEach(groupedItems[date] ?? [], id: \.id) { item in
                        VStack() {
                            Spacer().frame(height: 10)
                            HStack(alignment: .top) {
                                Text(item.title)
                                    .strikethrough()
                                    .foregroundColor(Color.black.opacity(0.8))
                                    .fontWeight(.medium)
                                Spacer()  // 添加一个Spacer来填满整行
                                if item.subItems.count > 0 {
                                    Text("\(item.subItems.count)")
                                        .foregroundColor(Color.black.opacity(0.25))
                                        .font(.body)
                                        .padding(.trailing, 2)
                                }
                            }
                            Spacer().frame(height: 10)
                        }
                        .contentShape(Rectangle()) // 使整行都能响应点击事件
                        .onTapGesture {
                            self.selectedDetailItem = item
                            self.showDetailView = true // 准备显示详情视图
                        }
                        // 滑动删除的功能
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                deleteDoneItem(item, on: date)
                            } label: {
                                Label("", systemImage: "trash.fill")
                            }
                        }
                        // 滑动撤销的功能
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            Button {
                                withAnimation {
                                    undoDoneItem(item)
                                }
                            } label: {
                                Label("", systemImage: "arrow.uturn.backward")
                            }
                            .tint(.green)
                        }
                    }
                    .onDelete { offsets in
                        deleteDoneItems(at: offsets, on: date)
                    }
                }
                .frame(minHeight: 44) // 确保行有最小高度
                .listRowSeparator(.hidden)
                .padding(.top, 0)
                .overlay(
                    Divider()
                        .frame(height: 1)
                        .background(Color.black)
                        .opacity(0.06)
                        .padding(.bottom, 0)
                    , alignment: .bottom
                )
                .listRowInsets(EdgeInsets(top: 0, leading: 28, bottom: 0, trailing: 28))
            }
        }
        .listStyle(PlainListStyle())
        .navigationBarBackButtonHidden(true) // 隐藏默认的返回按钮
        .navigationBarItems(leading: Button(action: {
            presentationMode.wrappedValue.dismiss() // 点击自定义返回按钮时关闭视图
        }) {
            Image(systemName: "chevron.left") // 仅使用箭头作为自定义返回按钮
                .foregroundColor(.primary) // 匹配主题颜色
                .font(.system(size: 14, weight: .medium))
            Text("To Do")
                .foregroundColor(.primary)
                .font(.system(size: 18, weight: .medium))
        })
        .navigationBarTitleDisplayMode(.inline)
        .simultaneousGesture(
            DragGesture()
                .onChanged { value in
                    let isFromEdge = value.startLocation.x < 25
                    let hasEnoughTranslation = value.translation.width > 5
                    let isRightDirection = value.translation.width > 0
                    
                    if isFromEdge && hasEnoughTranslation && isRightDirection {
                        // 触发返回操作
                        presentationMode.wrappedValue.dismiss()
                    }
                }
        )
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("DismissDonePage"))) { _ in
            // 接收到返回通知时执行返回操作
            presentationMode.wrappedValue.dismiss()
        }
        .navigationTitle(Text(""))
        .sheet(isPresented: $showDetailView) {
            // 使用选中的事项显示详情视图
            if let detailItem = selectedDetailItem {
                if #available(iOS 16.4, *) {
                    InputView(item: Binding.constant(detailItem), onSave: { _ in }, isReadOnly: true)
                        .presentationCornerRadius(30)
                } else {
                    // Fallback on earlier versions
                    InputView(item: Binding.constant(detailItem), onSave: { _ in }, isReadOnly: true)
                }
            }
        }
        .onChange(of: showDetailView) { newValue in
            // 当 showDetailView 变化时执行的操作
            if newValue && selectedDetailItem == nil {
                // showDetailView 被设置为 true，但 selectedDetailItem 为 nil 时的处理
            }
        }
    }
    
    // MARK: - 私有方法
    
    private func deleteDoneItem(_ item: TodoItem, on date: Date) {
        doneItems.removeAll { $0.id == item.id }
        saveData()  // 确保变更保存到 UserDefaults
        let generator = UIImpactFeedbackGenerator(style: .light); generator.impactOccurred()
    }

    private func deleteDoneItems(at offsets: IndexSet, on date: Date) {
        if let dateGroup = groupedItems[date] {
            let idsToDelete = offsets.map { dateGroup[$0].id }
            doneItems.removeAll { idsToDelete.contains($0.id) }
            saveData()  // 确保变更保存到 UserDefaults
            let generator = UIImpactFeedbackGenerator(style: .light); generator.impactOccurred()
        }
    }

    private func undoDoneItem(_ item: TodoItem) {
        doneItems.removeAll { $0.id == item.id }
        var undoneItem = item
        undoneItem.isDone = false
        undoneItem.doneDate = nil
        items.insert(undoneItem, at: 0)
        saveData()
        let generator = UIImpactFeedbackGenerator(style: .light); generator.impactOccurred()
    }

    // 辅助函数：获取当前月份的名称
    private func currentMonthName() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        return formatter.string(from: Date())
    }

    // 日期格式化
    private var itemFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }
}

// 新增：分类抽屉视图
struct CategoryDrawerView: View {
    @Binding var isPresented: Bool
    @Binding var selectedCategory: Category?
    @Binding var categories: [Category]
    @State private var showAddCategorySheet = false
    @State private var newCategoryName = ""
    
    // 计算属性：分离"To Do"分类和其他分类
    private var todoCategory: Category? {
        categories.first { $0.name == "To Do" }
    }
    
    private var otherCategories: [Category] {
        categories.filter { $0.name != "To Do" }
    }
    
    var body: some View {
        GeometryReader { geometry in
            // 抽屉内容
            VStack(alignment: .leading, spacing: 0) {
                    // 标题
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Categories")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.black)
                            .padding(.top, 60)
                            .padding(.horizontal, 28)
                        
                        Capsule().fill(Color.black).frame(height: 1.6).padding(.horizontal, 28)
                        Capsule().fill(Color.black).frame(height: 1).frame(maxWidth: .infinity).opacity(0.12).padding(.horizontal, 28)
                    }
                    
                    // 分类列表 - To Do分类不可拖拽，其他分类支持拖拽排序
                    List {
                        // 显示"To Do"分类（不可拖拽）
                        if let todo = todoCategory {
                            CategoryRowView(
                                category: todo,
                                isSelected: selectedCategory?.id == todo.id
                            ) {
                                selectedCategory = todo
                                isPresented = false
                            }
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                        }
                        
                        // 显示其他分类（可拖拽）
                        ForEach(otherCategories) { category in
                            CategoryRowView(
                                category: category,
                                isSelected: selectedCategory?.id == category.id
                            ) {
                                selectedCategory = category
                                isPresented = false
                            }
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                        }
                        .onMove(perform: moveOtherCategories)
                    }
                    .listStyle(PlainListStyle())
                    .padding(.top, 20)
                    
                    Spacer()
                    
                    // 添加分类按钮
                    Button(action: {
                        showAddCategorySheet = true
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.blue)
                            Text("Add Category")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.blue)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 28)
                    .padding(.bottom, 40)
                }
                .frame(width: geometry.size.width * 0.8)
                .background(Color.white)
                .shadow(color: .black.opacity(0.1), radius: 10, x: 5, y: 0)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            // 检测从右到左的滑动
                            let isFromRight = value.startLocation.x > geometry.size.width * 0.1
                            let hasEnoughTranslation = value.translation.width < -10
                            let isLeftDirection = value.translation.width < 0
                            
                            if isFromRight && hasEnoughTranslation && isLeftDirection {
                                // 触发关闭抽屉
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    isPresented = false
                                }
                            }
                        }
                        .onEnded { value in
                            // 最终确认：如果从右侧开始且滑动距离足够
                            let isFromRight = value.startLocation.x > geometry.size.width * 0.4
                            let hasEnoughTranslation = value.translation.width < -5
                            let isLeftDirection = value.translation.width < 0
                            
                            if isFromRight && hasEnoughTranslation && isLeftDirection {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    isPresented = false
                                }
                            }
                        }
                )
        .sheet(isPresented: $showAddCategorySheet) {
            AddCategoryView(
                categoryName: $newCategoryName,
                categories: categories,
                onSave: {
                    let newCategory = Category(name: newCategoryName)
                    categories.append(newCategory)
                    newCategoryName = ""
                    showAddCategorySheet = false
                    saveCategories()
                },
                onCancel: {
                    newCategoryName = ""
                    showAddCategorySheet = false
                }
            )
        }
        }
    }
    
    // 分类移动处理函数（仅处理非"To Do"分类）
    private func moveOtherCategories(from source: IndexSet, to destination: Int) {
        withAnimation {
            // 创建临时的可变数组
            var tempOtherCategories = otherCategories
            tempOtherCategories.move(fromOffsets: source, toOffset: destination)
            
            // 重建完整的分类列表：保持"To Do"在第一位，其他分类按新顺序排列
            var newCategories: [Category] = []
            if let todo = todoCategory {
                newCategories.append(todo)
            }
            newCategories.append(contentsOf: tempOtherCategories)
            
            categories = newCategories
            saveCategories()
        }
    }
    
    // 保存分类数据
    private func saveCategories() {
        DataStore.shared.saveCategories(categories)
    }
}

// 分类行视图
struct CategoryRowView: View {
    let category: Category
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // 分类名称
                Text(category.name)
                    .font(.system(size: 18, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(.black)
                
                Spacer()
                
                // 选中指示器
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 16)
            .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .frame(maxWidth: .infinity)
    }
}

// 添加分类视图
// 添加分类视图
struct AddCategoryView: View {
    @Binding var categoryName: String
    let categories: [Category]  // 添加现有分类列表参数
    let onSave: () -> Void
    let onCancel: () -> Void
    
    @FocusState private var isTextFieldFocused: Bool
    @State private var showError = false  // 添加错误状态
    @State private var errorMessage = ""  // 添加错误信息
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // 分类名称输入
                VStack(alignment: .leading, spacing: 8) {
                    Text("Category Name")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.black)
                    
                    TextField("Enter category name", text: $categoryName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .focused($isTextFieldFocused)
                        .onChange(of: categoryName) { _ in
                            // 当用户输入时清除错误状态
                            if showError {
                                showError = false
                                errorMessage = ""
                            }
                        }
                    
                    // 错误信息显示
                    if showError {
                        Text(errorMessage)
                            .font(.system(size: 14))
                            .foregroundColor(.red)
                            .padding(.top, 4)
                    }
                }
                
                Spacer()
            }
            .padding(24)
            .navigationTitle("New Category")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    onCancel()
                },
                trailing: Button("Save") {
                    validateAndSave()
                }
                .disabled(categoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            )
        }
        .onAppear {
            isTextFieldFocused = true
        }
    }
    
    // 添加校验和保存方法
    private func validateAndSave() {
        let trimmedName = categoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 检查是否为空
        guard !trimmedName.isEmpty else {
            showError = true
            errorMessage = "Category name cannot be empty"
            return
        }
        
        // 检查是否重复
        let isDuplicate = categories.contains { category in
            category.name.lowercased() == trimmedName.lowercased()
        }
        
        if isDuplicate {
            showError = true
            errorMessage = "Category name already exists"
            return
        }
        
        // 校验通过，执行保存
        onSave()
    }
}

// MARK: - 分类管理组件

// 分类更多操作菜单
struct CategoryMoreActionsView: View {
    let category: Category
    let onRenameTap: () -> Void
    let onDeleteTap: () -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 分类名称标题
                VStack(spacing: 16) {
                    Text("Category: \(category.name)")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.black)
                        .padding(.top, 20)
                    
                    Divider()
                }
                .padding(.horizontal, 24)
                
                // 操作选项列表
                VStack(spacing: 0) {
                    // 重命名分类
                    Button(action: {
                        onDismiss()
                        onRenameTap()
                    }) {
                        HStack(spacing: 16) {
                            Image(systemName: "pencil")
                                .font(.system(size: 18))
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            
                            Text("Change Category Name")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.primary)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 18)
                        .background(Color.clear)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Divider()
                        .padding(.leading, 24)
                    
                    // 删除分类
                    Button(action: {
                        onDismiss()
                        onDeleteTap()
                    }) {
                        HStack(spacing: 16) {
                            Image(systemName: "trash")
                                .font(.system(size: 18))
                                .foregroundColor(.red)
                                .frame(width: 24)
                            
                            Text("Delete Category")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.red)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 18)
                        .background(Color.clear)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .padding(.horizontal, 24)
                .padding(.top, 8)
                
                Spacer()
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                trailing: Button("Cancel") {
                    onDismiss()
                }
                .foregroundColor(.blue)
            )
        }
    }
}

// 重命名分类视图
struct RenameCategoryView: View {
    @Binding var categoryName: String
    let originalName: String
    let categories: [Category]
    let onSave: () -> Void
    let onCancel: () -> Void
    
    @FocusState private var isTextFieldFocused: Bool
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // 自定义导航栏
            HStack {
                Button("Cancel") {
                    onCancel()
                }
                .foregroundColor(.blue)
                
                Spacer()
                
                Text("Rename Category")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.black)
                
                Spacer()
                
                Button("Save") {
                    validateAndSave()
                }
                .foregroundColor(canSave ? .blue : .gray)
                .disabled(!canSave)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemGray6))
            
            Divider()
            
            // 主要内容
            VStack(spacing: 24) {
                // 分类名称输入
                VStack(alignment: .leading, spacing: 8) {
                    Text("Category Name")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.black)
                    
                    TextField("Enter category name", text: $categoryName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .focused($isTextFieldFocused)
                        .onChange(of: categoryName) { _ in
                            if showError {
                                showError = false
                                errorMessage = ""
                            }
                        }
                    
                    // 错误信息显示
                    if showError {
                        Text(errorMessage)
                            .font(.system(size: 14))
                            .foregroundColor(.red)
                            .padding(.top, 4)
                    }
                }
                
                Spacer()
            }
            .padding(24)
        }
        .background(Color(.systemBackground))
        .onAppear {
            isTextFieldFocused = true
        }
    }
    
    private var canSave: Bool {
        let trimmedName = categoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmedName.isEmpty && trimmedName != originalName
    }
    
    private func validateAndSave() {
        let trimmedName = categoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 检查是否为空
        guard !trimmedName.isEmpty else {
            showError = true
            errorMessage = "Category name cannot be empty"
            return
        }
        
        // 检查是否与原名称相同
        guard trimmedName != originalName else {
            showError = true
            errorMessage = "Please enter a different name"
            return
        }
        
        // 检查是否重复
        let isDuplicate = categories.contains { category in
            category.name.lowercased() == trimmedName.lowercased()
        }
        
        if isDuplicate {
            showError = true
            errorMessage = "Category name already exists"
            return
        }
        
        // 校验通过，执行保存
        onSave()
    }
}

// 删除分类确认视图
struct DeleteCategoryConfirmationView: View {
    let category: Category
    let itemCount: Int
    let onConfirm: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // 自定义导航栏
            HStack {
                Spacer()
                
                Text("Delete Category")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.black)
                
                Spacer()
                
                Button("Cancel") {
                    onCancel()
                }
                .foregroundColor(.blue)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemGray6))
            
            Divider()
            
            // 主要内容
            VStack(spacing: 24) {
                // 警告图标
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 48))
                    .foregroundColor(.orange)
                    .padding(.top, 40)
                
                // 警告文本
                VStack(spacing: 12) {
                    Text("Delete Category")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.black)
                    
                    Text("Are you sure you want to delete \"\(category.name)\"?")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    if itemCount > 0 {
                        Text("This will also delete \(itemCount) items in this category.")
                            .font(.system(size: 14))
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.top, 8)
                    }
                }
                
                Spacer()
                
                // 确认按钮
                VStack(spacing: 12) {
                    Button(action: onConfirm) {
                        Text("Delete")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.red)
                            .cornerRadius(8)
                    }
                    
                    Button(action: onCancel) {
                        Text("Cancel")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                }
                .padding(.bottom, 40)
            }
            .padding(.horizontal, 24)
        }
        .background(Color(.systemBackground))
    }
}
