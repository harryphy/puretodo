//  InputView.swift
//  Pure To Do
//
//  Created by PHY on 2023/12/8.
//  Version 2.4

import SwiftUI
import UserNotifications
import PhotosUI
import AVFoundation

private extension View {
    func subItemListRowStyle() -> some View {
        self
            .padding(.vertical, 10)
            .contentShape(Rectangle())
            .listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 0))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.white)
    }
}

private struct HiddenListBackground: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content.scrollContentBackground(.hidden)
        } else {
            content
        }
    }
}

private struct ImageSourceSheet: View {
    let onCamera: () -> Void
    let onLibrary: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onCamera) {
                Label("Take Photo", systemImage: "camera")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 52)
                    .contentShape(Rectangle())
            }

            Divider()

            Button(action: onLibrary) {
                HStack(spacing: 8) {
                    Image("imageIcon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 18, height: 18)
                    Text("Choose from Library")
                }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 52)
                    .contentShape(Rectangle())
            }
        }
        .padding(.top, 24)
        .font(.system(size: 17, weight: .regular))
        .foregroundColor(Color(hex: "0A0A0A"))
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.white.ignoresSafeArea())
    }
}

// 输入视图，用于新增和编辑事项
struct InputView: View {
    @Binding var item: TodoItem
    var onSave: (TodoItem) -> Void
    var isReadOnly: Bool = false
    var isNewItem: Bool = false

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
    @State private var showShareSheet = false // 显示分享界面
    @State private var shareImage: UIImage? // 要分享的图片
    @State private var shareFileURL: URL? // 要分享的文件URL
    @State private var showPhotoLibrary = false
    @State private var showCamera = false
    @State private var showImageSourceDialog = false
    @State private var imageImportError: TodoImageImportError?
    @State private var editingImageID: UUID?
    @State private var imagePendingDeletion: TodoImageAttachment?
    @Environment(\.presentationMode) var presentation
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

    private func saveSubItem(ifEditing expectedIndex: Int? = nil) {
        if let index = editingIndex {
            guard expectedIndex == nil || expectedIndex == index else { return }
            let trimmedTitle = editingSubItemTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedTitle.isEmpty {
                item.subItems[index].title = trimmedTitle
                onSave(item)
                let generator = UIImpactFeedbackGenerator(style: .light); generator.impactOccurred()
            }
            editingIndex = nil
            isSubItemInputActive = false
            isEditingSubItem = false
        }
    }

    private func beginEditingSubItem(at index: Int) {
        guard !isReadOnly, item.subItems.indices.contains(index) else { return }

        if editingIndex != nil {
            saveSubItem()
        }
        isInputActive = false
        isNewSubItemInputActive = false
        showingNewSubItemInput = false
        editingSubItemTitle = item.subItems[index].title
        editingIndex = index
        isEditingSubItem = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            guard editingIndex == index else { return }
            isSubItemInputActive = true
        }
    }

    private func submitTitle() {
        let trimmedTitle = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedTitle.isEmpty {
            item.title = trimmedTitle
            onSave(item)
            let generator = UIImpactFeedbackGenerator(style: .heavy)
            generator.impactOccurred()
            isEditingTitle = false
            isInputActive = false
            if isNewItem {
                presentation.wrappedValue.dismiss()
            }
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

    @ViewBuilder
    private func titleView() -> some View {
        if isEditingTitle && !isReadOnly {
            TextField("Type in here", text: $item.title, axis: .vertical)
                .font(.system(size: 22, weight: .medium))
                .foregroundColor(Color(hex: "0A0A0A").opacity(0.9))
                .lineSpacing(4)
                .lineLimit(1...4)
                .focused($isInputActive)
                .keyboardType(.default)
                .submitLabel(.done)
                .textFieldStyle(PlainTextFieldStyle())
                .frame(minHeight: 40, alignment: .leading)
                .padding(.horizontal, 24)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        self.isInputActive = true
                    }
                }
                .onSubmit {
                    submitTitle()
                }
                .onChange(of: item.title) { newValue in
                    guard newValue.contains(where: { $0.isNewline }) else { return }
                    item.title = newValue.filter { !$0.isNewline }
                    submitTitle()
                }
        } else {
            HStack {
                Text(item.title)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(Color(hex: "0A0A0A").opacity(0.9))
                    .lineSpacing(4)
                    .lineLimit(nil)
                Spacer(minLength: 0)
            }
            .frame(minHeight: 40, alignment: .leading)
            .padding(.horizontal, 24)
            .contentShape(Rectangle())
            .onTapGesture {
                if !isReadOnly {
                    if editingIndex != nil {
                        saveSubItem()
                    }
                    self.isEditingTitle = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        self.isInputActive = true
                    }
                }
            }
        }
    }

    private func subItemText(_ title: String, isDone: Bool) -> some View {
        Text(title)
            .font(.system(size: 17, weight: .regular))
            .foregroundColor(Color(hex: "0A0A0A").opacity(isDone ? 0.3 : 0.8))
            .strikethrough(isDone)
            .lineSpacing(4)
            .lineLimit(nil)
    }

    private var completedSectionDivider: some View {
        Rectangle()
            .fill(Color.black.opacity(0.05))
            .frame(height: 0.637)
            .padding(.vertical, 8)
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.white)
    }

    private func toolbarButton(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .regular))
                    .frame(width: 16, height: 16)

                Text(title)
                    .font(.system(size: 15, weight: .regular))
                    .tracking(-0.01)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .foregroundColor(Color(hex: "0A0A0A"))
            .frame(height: 21, alignment: .center)
            .frame(maxWidth: .infinity)
        }
        .flatButtonStyle()
    }

    private var reminderToolbarButton: some View {
        Button {
            if editingIndex != nil {
                saveSubItem()
            }
            withAnimation(.easeInOut(duration: 0.22)) {
                showReminderView = true
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: hasReminder ? "bell.fill" : "bell")
                    .font(.system(size: 16, weight: .regular))
                    .frame(width: 16, height: 16)

                Text(reminderToolbarTitle)
                    .font(.system(size: 15, weight: hasReminder ? .medium : .regular))
                    .tracking(-0.01)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .foregroundColor(Color(hex: "0A0A0A"))
            .frame(height: 21, alignment: .center)
            .frame(maxWidth: .infinity)
        }
        .flatButtonStyle()
    }

    private var toolbarDivider: some View {
        Rectangle()
            .fill(Color.black.opacity(0.08))
            .frame(width: 1, height: 16)
            .padding(.horizontal, 3)
    }

    private var shareToolbarButton: some View {
        Button {
            if editingIndex != nil {
                saveSubItem()
            }
            generateAndShareImage()
        } label: {
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 16, weight: .regular))
                .frame(width: 16, height: 16)
                .frame(width: 40, height: 21)
        }
        .foregroundColor(Color(hex: "0A0A0A"))
        .accessibilityLabel(Text("Share"))
        .flatButtonStyle()
    }

    private var bottomToolbar: some View {
        HStack(spacing: 0) {
            if !isReadOnly {
                imageToolbarMenu
                toolbarDivider
                toolbarButton(icon: "plus", title: NSLocalizedString("Subitem", comment: "Subitem toolbar button")) {
                    addSubItem()
                }
                toolbarDivider
                reminderToolbarButton
                toolbarDivider
                shareToolbarButton
            } else {
                Spacer()
                shareToolbarButton
                Spacer()
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 20)
        .padding(.bottom, 20)
        .frame(height: 62, alignment: .top)
        .background(Color.white)
        .overlay(
            Rectangle()
                .fill(Color.black.opacity(0.05))
                .frame(height: 0.637),
            alignment: .top
        )
    }

    private var imageToolbarMenu: some View {
        Button {
            if editingIndex != nil {
                saveSubItem()
            }
            showImageSourceDialog = true
        } label: {
            HStack(spacing: 8) {
                Image("imageIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18, height: 18)
                Text("Image")
                    .font(.system(size: 15, weight: .regular))
                    .tracking(-0.01)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .foregroundColor(Color(hex: "0A0A0A"))
            .frame(height: 21)
            .frame(maxWidth: .infinity)
        }
        .flatButtonStyle()
    }

    private func importSelectedPhotos(_ photos: [Data]) {
        let remaining = 20 - TodoImageStore.shared.images(for: item.id).count
        guard remaining > 0 else { imageImportError = .limitReached(remaining: 0); return }
        Task {
            for data in photos.prefix(remaining) {
                do {
                    try TodoImageStore.shared.importImageData(data, into: item.id)
                } catch let error as TodoImageImportError {
                    imageImportError = error
                    break
                } catch {
                    imageImportError = .processingFailed
                    break
                }
            }
            if photos.count > remaining { imageImportError = .limitReached(remaining: remaining) }
        }
    }

    private func requestCamera() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else { imageImportError = .cameraUnavailable; return }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: showCamera = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async { if granted { showCamera = true } else { imageImportError = .cameraPermissionDenied } }
            }
        case .denied, .restricted: imageImportError = .cameraPermissionDenied
        @unknown default: imageImportError = .cameraUnavailable
        }
    }

    private func chooseCameraFromImageSheet() {
        showImageSourceDialog = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            requestCamera()
        }
    }

    private func chooseLibraryFromImageSheet() {
        showImageSourceDialog = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            showPhotoLibrary = true
        }
    }

    private func importCameraImage(_ image: UIImage) {
        do {
            guard let data = image.jpegData(compressionQuality: 1) else { throw TodoImageImportError.processingFailed }
            try TodoImageStore.shared.importImageData(data, into: item.id)
        } catch let error as TodoImageImportError {
            imageImportError = error
        } catch {
            imageImportError = .processingFailed
        }
    }

    private var hasReminder: Bool {
        item.reminderType != nil
    }

    private var reminderToolbarTitle: String {
        guard let reminderType = item.reminderType else {
            return NSLocalizedString("Reminder", comment: "Reminder toolbar button")
        }

        switch reminderType {
        case .single:
            if let reminderDate = item.reminderDate {
                return DateFormatterHelper.formattedDate(reminderDate)
            }
        case .daily:
            if let reminderTime = item.reminderTime {
                return "Daily at \(DateFormatterHelper.formattedTime(reminderTime))"
            }
        case .weekly:
            if let reminderTime = item.reminderTime, let weekdays = item.reminderWeekdays {
                let weekdaysString = weekdays.sorted().map { DateFormatterHelper.weekdaySymbol(for: $0) }.joined(separator: ", ")
                return "\(weekdaysString) \(DateFormatterHelper.formattedTime(reminderTime))"
            }
        case .monthly:
            if let reminderTime = item.reminderTime, let daysOfMonth = item.reminderDaysOfMonth {
                let daysString = daysOfMonth.sorted().map { "\($0)" }.joined(separator: ", ")
                return "Monthly on \(daysString) at \(DateFormatterHelper.formattedTime(reminderTime))"
            }
        }

        return NSLocalizedString("Reminder", comment: "Reminder toolbar button")
    }

    var body: some View {
        VStack(spacing: 0) {
            // 顶部区域：分享按钮和下拉指示器
            HStack {
                Spacer()
                Image(systemName: "chevron.compact.down")
                    .foregroundColor(Color(hex: "0A0A0A").opacity(0.2))
                    .font(.system(size: 24, weight: .regular))
                    .padding(.top, 16)
                Spacer()
            }
            .frame(height: 64, alignment: .top)

            titleView()
                .padding(.top, 8)
                .padding(.bottom, 24)

            // 子事项
            List {
                TodoImageGrid(todoID: item.id, isReadOnly: isReadOnly, editingImageID: $editingImageID)
                    // The List already has the same 24pt horizontal inset as the title.
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: item.subItems.isEmpty ? 8 : 16, trailing: 0))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.white)

                if showingNewSubItemInput {
                    TextField("New Subitem", text: $newSubItemTitle, axis: .vertical)
                        .font(.system(size: 17, weight: .regular))
                        .foregroundColor(Color(hex: "0A0A0A").opacity(0.8))
                        .lineSpacing(4)
                        .lineLimit(1...4)
                        .focused($isNewSubItemInputActive) // 激活状态
                        .keyboardType(.default)
                        .submitLabel(.done)
                        .textFieldStyle(PlainTextFieldStyle())
                        .onSubmit {
                            saveOrCloseNewSubItem()
                        }
                        .onChange(of: newSubItemTitle) { newValue in
                            guard newValue.contains(where: { $0.isNewline }) else { return }
                            newSubItemTitle = newValue.filter { !$0.isNewline }
                            saveOrCloseNewSubItem()
                        }
                        .onAppear {
                            isNewSubItemInputActive = true
                        }
                        .subItemListRowStyle()
                }

                ForEach(Array(item.subItems.enumerated()), id: \.element.id) { index, subItem in
                    Group {
                        if item.subItems[index].isDone && index > 0 && !item.subItems[index - 1].isDone {
                            completedSectionDivider
                        }

                        // 标记为 done 的子事项
                        if item.subItems[index].isDone {
                            HStack(alignment: .top, spacing: 12) {
                                Text("✓")
                                    .font(.system(size: 17, weight: .regular))
                                    .foregroundColor(Color(hex: "0A0A0A").opacity(0.2))
                                    .frame(width: 14, height: 24, alignment: .leading)
                                    .offset(y: -1)
                                subItemText(item.subItems[index].title, isDone: true)
                                Spacer(minLength: 0)
                            }
                            .subItemListRowStyle()
                            // 标记子事项为未完成
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                if !isReadOnly {
                                    Button {
                                        item.subItems[index].isDone.toggle()
                                        sortSubItems() // 重新排序，将未完成项移到前面
                                        let generator = UIImpactFeedbackGenerator(style: .heavy); generator.impactOccurred()
                                    } label: {
                                        Label("", systemImage: "arrow.uturn.backward")
                                    }
                                    .tint(Color(hex: "3BBF5E"))
                                }
                            }
                            // 删除按钮
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                if !isReadOnly {
                                    Button(role: .destructive) {
                                        item.subItems.remove(at: index)
                                        onSave(item)
                                        let generator = UIImpactFeedbackGenerator(style: .light); generator.impactOccurred()
                                    } label: {
                                        Label("", systemImage: "trash")
                                    }
                                    .tint(Color(hex: "F55447"))
                                }
                            }
                        } else {
                            if editingIndex == index {
                                TextField("Subitem", text: $editingSubItemTitle, axis: .vertical)
                                .font(.system(size: 17, weight: .regular))
                                .foregroundColor(Color(hex: "0A0A0A").opacity(0.8))
                                .lineSpacing(4)
                                .lineLimit(1...4)
                                .focused($isSubItemInputActive)
                                .keyboardType(.default)
                                .submitLabel(.done)
                                .onSubmit {
                                    // 提交编辑，更新数组
                                    saveSubItem()
                                }
                                .onChange(of: editingSubItemTitle) { newValue in
                                    guard newValue.contains(where: { $0.isNewline }) else { return }
                                    editingSubItemTitle = newValue.filter { !$0.isNewline }
                                    saveSubItem()
                                }
                                .frame(minHeight: 44)
                                .subItemListRowStyle()
                            } else {
                                HStack(alignment: .top, spacing: 12) {
                                    Text("•")
                                        .font(.system(size: 17, weight: .regular))
                                        .foregroundColor(Color(hex: "0A0A0A").opacity(0.8))
                                        .frame(width: 8, height: 24, alignment: .leading)
                                        .offset(y: -1)
                                    subItemText(item.subItems[index].title, isDone: false)
                                    Spacer(minLength: 0)
                                }
                                .contentShape(Rectangle()) // 使整个行区域可点击
                                .highPriorityGesture(
                                    TapGesture().onEnded {
                                        beginEditingSubItem(at: index)
                                    }
                                )
                                .subItemListRowStyle()
                                // 标记子事项为完成
                                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                    if !isReadOnly {
                                        Button {
                                            item.subItems[index].isDone.toggle()
                                            sortSubItems()
                                            let generator = UIImpactFeedbackGenerator(style: .light); generator.impactOccurred()
                                        } label: {
                                            Image("purecheck")
                                                .resizable()
                                                .aspectRatio(contentMode: .fit)
                                                .frame(width: 12, height: 12)
                                        }
                                        .tint(Color(hex: "3BBF5E"))
                                    }
                                }
                                // 删除按钮
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    if !isReadOnly {
                                        Button(role: .destructive) {
                                            item.subItems.remove(at: index)
                                            onSave(item)
                                            let generator = UIImpactFeedbackGenerator(style: .light); generator.impactOccurred()
                                        } label: {
                                            Label("", systemImage: "trash")
                                        }
                                        .tint(Color(hex: "F55447"))
                                    }
                                }
                            }
                        }
                    }
                }
                .onDelete(perform: isReadOnly ? nil : deleteSubItem)
                .onMove(perform: (editingIndex != nil || isNewSubItemInputActive || isReadOnly) ? nil : moveSubItem)
            }
            .padding(.horizontal, 24)
            .listStyle(PlainListStyle())
            .environment(\.defaultMinListRowHeight, 1)
            .modifier(HiddenListBackground())
            .background(Color.white)
            .overlayPreferenceValue(TodoImageDeleteAnchorKey.self) { anchors in
                GeometryReader { proxy in
                    if !isReadOnly,
                       let editingImageID,
                       let anchor = anchors[editingImageID],
                       let image = TodoImageStore.shared.images(for: item.id).first(where: { $0.id == editingImageID }) {
                        let frame = proxy[anchor]
                        Button {
                            imagePendingDeletion = image
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundColor(Color.red)
                                .background(Color.white, in: Circle())
                                .frame(width: 32, height: 32)
                                .contentShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .position(x: frame.maxX - 7, y: frame.minY + 7)
                        .zIndex(10)
                        .accessibilityLabel(Text("Delete image"))
                    }
                }
            }

            bottomToolbar
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
                .edgeAttachedSheetStyle()
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
                .edgeAttachedSheetStyle()
            }
        }
        .onAppear {
            requestNotificationPermission()
        }
        .onDisappear {
            if editingIndex != nil {
                saveSubItem()
            }
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
        .sheet(isPresented: $showShareSheet) {
            if let shareFileURL = shareFileURL {
                ActivityViewController(activityItems: [shareFileURL])
            } else if let shareImage = shareImage {
                ActivityViewController(activityItems: [shareImage])
            }
        }
        .sheet(isPresented: $showImageSourceDialog) {
            if #available(iOS 16.4, *) {
                ImageSourceSheet(
                    onCamera: chooseCameraFromImageSheet,
                    onLibrary: chooseLibraryFromImageSheet
                )
                .presentationDetents([.height(140)])
                .presentationCornerRadius(30)
                .presentationDragIndicator(.visible)
                .presentationBackground(Color.white)
            } else {
                ImageSourceSheet(
                    onCamera: chooseCameraFromImageSheet,
                    onLibrary: chooseLibraryFromImageSheet
                )
                .presentationDetents([.height(140)])
                .presentationDragIndicator(.visible)
            }
        }
        .sheet(isPresented: $showPhotoLibrary) {
            TodoPhotoPicker(maximumSelectionCount: max(1, 20 - TodoImageStore.shared.images(for: item.id).count), onData: { data in
                showPhotoLibrary = false
                importSelectedPhotos(data)
            }, onCancel: { showPhotoLibrary = false })
        }
        .sheet(isPresented: $showCamera) {
            TodoCameraPicker(onImage: { image in
                showCamera = false
                importCameraImage(image)
            }, onCancel: { showCamera = false })
                .ignoresSafeArea()
        }
        .alert("Unable to add image", isPresented: Binding(get: { imageImportError != nil }, set: { if !$0 { imageImportError = nil } })) {
            Button("OK", role: .cancel) { imageImportError = nil }
        } message: {
            Text(imageImportError?.localizedDescription ?? NSLocalizedString("Please try again.", comment: "Generic image import failure"))
        }
        .alert("Delete image?", isPresented: Binding(get: { imagePendingDeletion != nil }, set: { if !$0 { imagePendingDeletion = nil } })) {
            Button("Delete", role: .destructive) {
                if let image = imagePendingDeletion { TodoImageStore.shared.remove(image) }
                imagePendingDeletion = nil
                editingImageID = nil
            }
            Button("Cancel", role: .cancel) { imagePendingDeletion = nil }
        } message: {
            Text("This image will be permanently deleted from this item.")
        }
    }
    
    // MARK: - 分享功能
    
    private func generateAndShareImage() {
        let shareableView = ShareableView(item: item)
        let renderer = ImageRenderer(content: shareableView)
        
        // 设置超高质量渲染 - 3倍分辨率确保清晰度
        renderer.scale = max(UIScreen.main.scale * 2.0, 3.0)
        
        if let uiImage = renderer.uiImage {
            // 创建带文件名的分享项
            let fileName = "PureToDo_\(item.title.prefix(20)).png"
            let tempURL = createTemporaryImageFile(image: uiImage, fileName: fileName)
            
            if let url = tempURL {
                // 分享文件而不是 UIImage
                shareImage = nil
                shareFileURL = url
            } else {
                // 回退到原始方式
                shareImage = uiImage
            }
            showShareSheet = true
        }
    }
    
    // 创建临时图片文件
    private func createTemporaryImageFile(image: UIImage, fileName: String) -> URL? {
        guard let data = image.pngData() else { return nil }
        
        let tempDirectory = FileManager.default.temporaryDirectory
        let fileURL = tempDirectory.appendingPathComponent(fileName)
        
        do {
            try data.write(to: fileURL)
            return fileURL
        } catch {
            print("无法创建临时图片文件: \(error)")
            return nil
        }
    }
}

// MARK: - 可分享的视图
struct ShareableView: View {
    let item: TodoItem
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Image(systemName: "chevron.compact.down")
                    .foregroundColor(Color(hex: "0A0A0A").opacity(0.2))
                    .font(.system(size: 24, weight: .regular))
                    .padding(.top, 16)
                Spacer()
            }
            .frame(height: 64, alignment: .top)

            HStack {
                Text(item.title)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(Color(hex: "0A0A0A").opacity(0.9))
                    .lineSpacing(4)
                    .lineLimit(nil)
                Spacer(minLength: 0)
            }
            .frame(minHeight: 40, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 24)

            let attachments = TodoImageStore.shared.images(for: item.id)
            if !attachments.isEmpty {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5), spacing: 8) {
                    ForEach(attachments) { attachment in
                        if let image = TodoImageStore.shared.thumbnail(for: attachment) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(maxWidth: .infinity)
                                .aspectRatio(1, contentMode: .fit)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }
            
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(item.subItems.enumerated()), id: \.element.id) { index, subItem in
                    if subItem.isDone && index > 0 && !item.subItems[index - 1].isDone {
                        completedSectionDivider
                    }

                    shareSubItemRow(subItem)
                }
            }
            .padding(.horizontal, 24)
            
            let screenHeight = UIScreen.main.bounds.height
            let contentHeight = calculateContentHeight()
            let remainingHeight = max(0, screenHeight - contentHeight - 46)
            
            if remainingHeight > 0 {
                Spacer()
                    .frame(height: remainingHeight)
            }
            
            HStack {
                Spacer()
                HStack(spacing: 4) {
                    Image("purechecklight")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 16)
                    
                    Text("Pure To Do")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "0A0A0A").opacity(0.3))
                }
                .padding(.top, 30)
                .padding(.bottom, 10)
                Spacer()
            }
            
            // 添加一些底部间距，确保内容完整显示
            Spacer()
                .frame(height: 20)
        }
        .background(Color.white)
        .frame(width: UIScreen.main.bounds.width)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var completedSectionDivider: some View {
        Rectangle()
            .fill(Color.black.opacity(0.05))
            .frame(height: 0.637)
            .padding(.vertical, 4)
    }

    private func shareSubItemRow(_ subItem: TodoItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            if subItem.isDone {
                Text("✓")
                    .font(.system(size: 17, weight: .regular))
                    .foregroundColor(Color(hex: "0A0A0A").opacity(0.2))
                    .frame(width: 14, height: 24, alignment: .leading)
            } else {
                Text("•")
                    .font(.system(size: 17, weight: .regular))
                    .foregroundColor(Color(hex: "0A0A0A").opacity(0.8))
                    .frame(width: 8, height: 24, alignment: .leading)
            }

            Text(subItem.title)
                .font(.system(size: 17, weight: .regular))
                .foregroundColor(Color(hex: "0A0A0A").opacity(subItem.isDone ? 0.3 : 0.8))
                .strikethrough(subItem.isDone)
                .lineSpacing(4)
                .lineLimit(nil)

            Spacer(minLength: 0)
        }
        .padding(.leading, 4)
        .padding(.vertical, 12)
    }
    
    // 计算内容高度的方法
    private func calculateContentHeight() -> CGFloat {
        // 顶部区域高度
        let topAreaHeight: CGFloat = 64
        
        // 主事项标题高度
        let titleHeight: CGFloat = 22 + 8 + 24
        
        // 子事项列表高度
        let subItemHeight: CGFloat = 48
        let completedDividerCount = zip(item.subItems, item.subItems.dropFirst()).filter { pair in
            !pair.0.isDone && pair.1.isDone
        }.count
        let subItemsHeight = CGFloat(item.subItems.count) * subItemHeight + CGFloat(completedDividerCount) * (0.637 + 8)
        
        // Footer 区域高度
        let footerHeight: CGFloat = 20 + 12 + 10 + 20 // top padding + text height + bottom padding + bottom spacing
        
        return topAreaHeight + titleHeight + subItemsHeight + footerHeight
    }
}

// MARK: - 分享控制器
struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        
        // 对于 iPad，设置 popover 的源视图
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
            
            var currentViewController = rootViewController
            while let presentedViewController = currentViewController.presentedViewController {
                currentViewController = presentedViewController
            }
            
            if let popover = controller.popoverPresentationController {
                popover.sourceView = currentViewController.view
                popover.sourceRect = CGRect(x: currentViewController.view.bounds.midX,
                                          y: currentViewController.view.bounds.midY,
                                          width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
        }
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
