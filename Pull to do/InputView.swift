//  InputView.swift
//  Pure To Do
//
//  Created by PHY on 2023/12/8.
//  Version 2.4

import SwiftUI
import UserNotifications

// 输入视图，用于新增和编辑事项
struct InputView: View {
    @Binding var item: TodoItem
    var onSave: (TodoItem) -> Void
    var isReadOnly: Bool = false

    @State private var newSubItemTitle: String = ""
    @State private var editingSubItemTitle: String = ""

    @FocusState private var isInputActive: Bool
    @FocusState private var isSubItemInputActive: Bool
    @FocusState private var isNewSubItemInputActive: Bool

    @State private var showingSubItemInput = false
    @State private var showingNewSubItemInput = false
    @State private var editingIndex: Int? // 跟踪当前正在编辑的子待办事项
    @State private var isEditingTitle: Bool = false // 跟踪主事项标题是否正在编辑
    @State private var isEditingSubItem: Bool = false // 跟踪子事项是否处于编辑状态
    @State private var showReminderView = false // 显示提醒视图
    @Environment(\.presentationMode) var presentationMode

    private func sortSubItems() {
        item.subItems.sort { !$0.isDone && $1.isDone }
        onSave(item)
    }

    private func moveSubItem(from source: IndexSet, to destination: Int) {
        guard !isEditingSubItem else { return } // 禁用排序
        item.subItems.move(fromOffsets: source, toOffset: destination)
        onSave(item)
        let generator = UIImpactFeedbackGenerator(style: .light); generator.impactOccurred()
    }

    private func deleteSubItem(at offsets: IndexSet) {
        item.subItems.remove(atOffsets: offsets)
        onSave(item)
        let generator = UIImpactFeedbackGenerator(style: .light); generator.impactOccurred()
    }

    private func saveOrCloseNewSubItem() {
        // 判断输入框是否有内容
        let trimmedTitle = newSubItemTitle.trimmingCharacters(in: .whitespacesAndNewlines)

        if !trimmedTitle.isEmpty {
            // 有内容时保存并打开新的输入框
            let newSubItem = TodoItem(title: trimmedTitle, isDone: false, date: Date())
            item.subItems.insert(newSubItem, at: 0)
            newSubItemTitle = ""
            onSave(item)
            let generator = UIImpactFeedbackGenerator(style: .light); generator.impactOccurred()

            // 打开新输入框
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.showingNewSubItemInput = true
                self.isNewSubItemInputActive = true
            }
        } else {
            // 无内容时，退出输入并关闭输入框
            newSubItemTitle = ""
            showingNewSubItemInput = false
            isNewSubItemInputActive = false
        }
    }

    private func addSubItem() {
        // 如果新子事项输入框中有内容，先保存它
        let trimmedTitle = newSubItemTitle.trimmingCharacters(in: .whitespacesAndNewlines)

        if !trimmedTitle.isEmpty {
            let newSubItem = TodoItem(title: trimmedTitle, isDone: false, date: Date())
            item.subItems.insert(newSubItem, at: 0)
            newSubItemTitle = ""
            onSave(item)
            let generator = UIImpactFeedbackGenerator(style: .light); generator.impactOccurred()
        }

        // 退出当前编辑的子事项
        if let index = editingIndex {
            // 保存当前编辑的子事项
            if !editingSubItemTitle.isEmpty {
                item.subItems[index].title = editingSubItemTitle
                onSave(item)
                let generator = UIImpactFeedbackGenerator(style: .light); generator.impactOccurred()
            }
            // 退出当前编辑状态
            self.editingIndex = nil
            self.isSubItemInputActive = false
        }

        // 显示新的子事项输入框
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.newSubItemTitle = ""
            self.showingNewSubItemInput = true
            // 激活新的子事项输入框
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.isNewSubItemInputActive = true
            }
        }
    }

    private func saveSubItem() {
        if let index = editingIndex {
            let trimmedTitle = editingSubItemTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedTitle.isEmpty {
                item.subItems[index].title = trimmedTitle
                onSave(item)
                let generator = UIImpactFeedbackGenerator(style: .light); generator.impactOccurred()
            }
            editingIndex = nil
            isSubItemInputActive = false
        }
    }

    private func cancelReminder() {
        // 移除与此事项相关的所有通知
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [item.id.uuidString])

        // 也移除所有标识符包含此事项 UUID 的通知
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let identifiers = requests
                .filter { $0.identifier.hasPrefix(item.id.uuidString) }
                .map { $0.identifier }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
        }

        // 清除提醒属性
        item.reminderType = nil
        item.reminderDate = nil
        item.reminderTime = nil
        item.reminderWeekdays = nil
        item.reminderDaysOfMonth = nil
    }

    var body: some View {
        VStack {
            Spacer().frame(height: 20)
            Image(systemName: "chevron.compact.down")
                .foregroundColor(.primary)
                .font(.system(size: 32))
            Spacer().frame(height: 20)
            if isEditingTitle && !isReadOnly {
                HStack {
                    TextField("Type in here", text: $item.title)
                        .font(.system(size: 20))
                        .focused($isInputActive)
                        .keyboardType(.default)
                        .submitLabel(.done)
                        .textFieldStyle(PlainTextFieldStyle())
                        .padding()
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                self.isInputActive = true
                            }
                        }
                        .onSubmit {
                            let trimmedTitle = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !trimmedTitle.isEmpty {
                                onSave(item)
                                let generator = UIImpactFeedbackGenerator(style: .heavy); generator.impactOccurred()
                                self.isEditingTitle = false
                                presentationMode.wrappedValue.dismiss()
                            }
                        }
                }
                .padding(.leading, 4)
                .padding(.trailing, 4)
            } else {
                HStack {
                    Text(item.title)
                        .font(.system(size: 21))
                        .fontWeight(.semibold)
                        .padding()
                    Spacer()
                }
                .padding(.trailing, 2)
                .padding(.leading, 4)
                .contentShape(Rectangle()) // 使整个行区域可点击
                .onTapGesture {
                    if !isReadOnly {
                        self.isEditingTitle = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            self.isInputActive = true
                        }
                    }
                }
            }

            // 子事项
            List {
                if showingNewSubItemInput {
                    TextField("New Subitem", text: $newSubItemTitle)
                        .focused($isNewSubItemInputActive) // 激活状态
                        .keyboardType(.default)
                        .submitLabel(.done)
                        .textFieldStyle(PlainTextFieldStyle())
                        .onSubmit {
                            saveOrCloseNewSubItem()
                        }
                        .onAppear {
                            isNewSubItemInputActive = true
                        }
                }

                ForEach(Array(item.subItems.enumerated()), id: \.element.id) { index, subItem in
                    // 标记为 done 的子事项
                    if item.subItems[index].isDone {
                        HStack(alignment: .top) {
                            Image(systemName: "checkmark")
                                .foregroundColor(.gray)
                                .font(.system(size: 11)) // 调整 checkmark 的大小
                                .offset(y: 6) // 调整 checkmark 的位置
                                .offset(x: -1)
                            Spacer().frame(width: 4)
                            Text(item.subItems[index].title)
                                .strikethrough()
                                .foregroundColor(.gray)
                                .lineLimit(nil)
                            // 标记子事项为未完成
                                .swipeActions(edge: .leading) {
                                    if !isReadOnly {
                                        Button {
                                            item.subItems[index].isDone.toggle()
                                            sortSubItems() // 重新排序，将未完成项移到前面
                                            let generator = UIImpactFeedbackGenerator(style: .heavy); generator.impactOccurred()
                                        } label: {
                                            Label("", systemImage: "arrow.uturn.backward")
                                        }
                                        .tint(.green)
                                    }
                                }
                            // 删除按钮
                                .swipeActions(edge: .trailing) {
                                    if !isReadOnly {
                                        Button(role: .destructive) {
                                            item.subItems.remove(at: index)
                                            onSave(item)
                                            let generator = UIImpactFeedbackGenerator(style: .light); generator.impactOccurred()
                                        } label: {
                                            Label("", systemImage: "trash")
                                        }
                                        .tint(.red)
                                    }
                                }
                        }
                    } else {
                        if editingIndex == index {
                            TextField("Subitem", text: $editingSubItemTitle, onEditingChanged: { isEditing in
                                self.isEditingSubItem = isEditing
                                if !isEditing {
                                    // 编辑结束，更新数组
                                    saveSubItem()
                                }
                            })
                            .lineLimit(nil)
                            .focused($isSubItemInputActive)
                            .keyboardType(.default)
                            .submitLabel(.done)
                            .onSubmit {
                                // 提交编辑，更新数组
                                saveSubItem()
                                let generator = UIImpactFeedbackGenerator(style: .light); generator.impactOccurred()
                            }
                            .frame(minHeight: 44)
                        } else {
                            HStack(alignment: .top) {
                                Image(systemName: "circle.fill")
                                    .foregroundColor(.primary)
                                    .font(.system(size: 6)) // 调整圆点的大小
                                    .offset(y: 7) // 调整圆点的位置
                                Text(item.subItems[index].title)
                                    .lineLimit(nil)
                                Spacer()
                            }
                            .contentShape(Rectangle()) // 使整个行区域可点击
                            .onTapGesture {
                                if !isReadOnly {
                                    isNewSubItemInputActive = false
                                    showingNewSubItemInput = false
                                    editingIndex = index
                                    // 初始化编辑文本
                                    editingSubItemTitle = item.subItems[index].title
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        isSubItemInputActive = true
                                    }
                                }
                            }
                            // 标记子事项为完成
                            .swipeActions(edge: .leading) {
                                if !isReadOnly {
                                    Button {
                                        item.subItems[index].isDone.toggle()
                                        sortSubItems()
                                        let generator = UIImpactFeedbackGenerator(style: .light); generator.impactOccurred()
                                    } label: {
                                        Label("", systemImage: "checkmark")
                                    }
                                    .tint(.green)
                                }
                            }
                            // 删除按钮
                            .swipeActions(edge: .trailing) {
                                if !isReadOnly {
                                    Button(role: .destructive) {
                                        item.subItems.remove(at: index)
                                        onSave(item)
                                        let generator = UIImpactFeedbackGenerator(style: .light); generator.impactOccurred()
                                    } label: {
                                        Label("", systemImage: "trash")
                                    }
                                    .tint(.red)
                                }
                            }
                        }
                    }
                }
                .onDelete(perform: isReadOnly ? nil : deleteSubItem)
                .onMove(perform: (isSubItemInputActive || isNewSubItemInputActive || isReadOnly) ? nil : moveSubItem)
            }
            .padding(.trailing, 8)
            .padding(.leading, 4)

            Spacer()
            HStack {
                if !isReadOnly {
                    Spacer()
                    HStack {
                        Button(action: {
                            addSubItem()
                        }) {
                            HStack {
                                Image(systemName: "plus")
                                Text("Subitem")
                            }
                        }
                        .foregroundColor(.primary)
                        .padding(.horizontal, 4)
                    }
                    .frame(maxWidth: .infinity)
                    Text("|")
                        .padding(.horizontal, 0)
                        .foregroundColor(.primary)
                        .font(.system(size: 16))
                    HStack {
                        Button(action: {
                            showReminderView = true
                        }) {
                            HStack {
                                if let reminderType = item.reminderType {
                                    switch reminderType {
                                    case .single:
                                        if let reminderDate = item.reminderDate {
                                            if reminderDate > Date() {
                                                Image(systemName: "clock.fill")
                                                    .foregroundColor(.black)
                                                Text(DateFormatterHelper.formattedDate(reminderDate))
                                                    .foregroundColor(.black)
                                                    .fontWeight(.medium)
                                            } else {
                                                Image(systemName: "clock")
                                                Text(DateFormatterHelper.formattedDate(reminderDate))
                                            }
                                        } else {
                                            // No reminder date set, show default
                                            Image(systemName: "clock")
                                            Text("Reminder")
                                        }
                                    case .daily:
                                        if let reminderTime = item.reminderTime {
                                            Image(systemName: "clock.fill")
                                                .foregroundColor(.black)
                                            Text("Daily at \(DateFormatterHelper.formattedTime(reminderTime))")
                                                .foregroundColor(.black)
                                                .fontWeight(.medium)
                                                .lineLimit(1) // 限制为一行
                                                .truncationMode(.tail) // 超出部分以省略号结尾
                                        } else {
                                            // No time set
                                            Image(systemName: "clock")
                                            Text("Reminder")
                                        }
                                    case .weekly:
                                        if let reminderTime = item.reminderTime, let weekdays = item.reminderWeekdays {
                                            Image(systemName: "clock.fill")
                                                .foregroundColor(.black)
                                            let weekdaysString = weekdays.sorted().map { DateFormatterHelper.weekdaySymbol(for: $0) }.joined(separator: ", ")
                                            Text("\(weekdaysString) \(DateFormatterHelper.formattedTime(reminderTime))")
                                                .foregroundColor(.black)
                                                .fontWeight(.medium)
                                                .lineLimit(1) // 限制为一行
                                        } else {
                                            // No time or weekdays set
                                            Image(systemName: "clock")
                                            Text("Reminder")
                                        }
                                    case .monthly:
                                        if let reminderTime = item.reminderTime, let daysOfMonth = item.reminderDaysOfMonth {
                                            Image(systemName: "clock.fill")
                                                .foregroundColor(.black)
                                            let daysString = daysOfMonth.sorted().map { "\($0)" }.joined(separator: ", ")
                                            Text("Monthly on \(daysString) at \(DateFormatterHelper.formattedTime(reminderTime))")
                                                .foregroundColor(.black)
                                                .fontWeight(.medium)
                                                .lineLimit(1) // 限制为一行
                                        } else {
                                            // No time or days set
                                            Image(systemName: "clock")
                                            Text("Reminder")
                                        }
                                    }
                                } else {
                                    // No reminder set
                                    Image(systemName: "clock")
                                    Text("Reminder")
                                }
                            }
                        }
                        .foregroundColor(.primary)
                        .padding(.horizontal, 4)
                    }
                    .frame(maxWidth: .infinity)
                    Spacer()
                }
            }
            .padding(.vertical, 20)
        }
        .sheet(isPresented: $showReminderView, onDismiss: {
            // 当 sheet 关闭时的处理
        }) {
            if #available(iOS 16.4, *) {
                ReminderView(item: $item, onSave: { updatedItem in
                    item = updatedItem
                    onSave(item)
                    NotificationHelper.scheduleNotification(for: item) // 调度更新后的提醒
                    showReminderView = false
                }, onCancel: {
                    cancelReminder()
                    onSave(item)
                    showReminderView = false
                })
                .presentationDetents([.fraction(0.56)])
                .presentationCornerRadius(30)
            } else {
                ReminderView(item: $item, onSave: { updatedItem in
                    item = updatedItem
                    onSave(item)
                    NotificationHelper.scheduleNotification(for: item) // 调度更新后的提醒
                    showReminderView = false
                }, onCancel: {
                    cancelReminder()
                    onSave(item)
                    showReminderView = false
                })
                .frame(height: UIScreen.main.bounds.height / 2) // 设置高度为屏幕的一半
                .background(
                    RoundedRectangle(cornerRadius: 30)
                        .fill(Material.bar)
                )
                .shadow(radius: 30)
            }
        }
        .onAppear {
            requestNotificationPermission()
        }
        .listStyle(PlainListStyle())
        .onAppear {
            if item.subItems.isEmpty && !isReadOnly {
                self.isEditingTitle = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.isInputActive = true
                }
            }
        }
    }
}
