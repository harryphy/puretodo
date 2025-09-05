//
//  SharedTypes.swift
//  Pull to do
//
//  Created by PHY on 2024/8/8.
//

// SharedTypes.swift

import Foundation
import WidgetKit

// 定义提醒类型的枚举
enum ReminderType: String, Codable {
    case single
    case daily
    case weekly
    case monthly
}

// 定义分类结构体
struct Category: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var createdAt: Date
    
    init(name: String) {
        self.id = UUID()
        self.name = name
        self.createdAt = Date()
    }
    
    init(id: UUID = UUID(), name: String, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
    }
}

struct TodoItem: Identifiable, Codable {
    var id = UUID()
    var title: String
    var isDone: Bool
    var isPinned: Bool = false
    var date: Date
    var doneDate: Date? // 记录标记完成的日期
    var reminderDate: Date? // 对于单次提醒
    var subItems: [TodoItem] = [] // 存储子待办项
    var categoryId: UUID? // 新增：分类ID
    
    // 新增的属性
    var reminderType: ReminderType?
    var reminderTime: Date? // 用于每日、每周、每月提醒的时间
    var reminderWeekdays: [Int]? // 用于每周提醒的星期几（1 = 星期日，...，7 = 星期六）
    var reminderDaysOfMonth: [Int]? // 用于每月提醒的日期（1 到 31）
}

class DataStore {
    static let shared = DataStore()
    private let itemsKey = "todoItems"
    private let doneItemsKey = "doneTodoItems"
    private let pinnedItemsKey = "pinnedTodoItems"
    private let categoriesKey = "categories" // 新增：分类数据键
    private let appGroup = "group.com.Harry.P.Pure-To-Do"
    private let keyValueStore = NSUbiquitousKeyValueStore.default
    private let sharedDefaults: UserDefaults
    
    init() {
        sharedDefaults = UserDefaults(suiteName: appGroup)!
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(ubiquitousKeyValueStoreDidChange),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: keyValueStore
        )
        keyValueStore.synchronize()
        migrateDataFromUserDefaultsIfNeeded()
    }
    
    private func migrateDataFromUserDefaultsIfNeeded() {
        let userDefaults = UserDefaults.standard
        
        if userDefaults.bool(forKey: "migrationCompleted") == false {
            if let itemsData = userDefaults.data(forKey: itemsKey),
               let doneItemsData = userDefaults.data(forKey: doneItemsKey),
               let pinnedItemsData = userDefaults.data(forKey: pinnedItemsKey) {
                
                keyValueStore.set(itemsData, forKey: itemsKey)
                sharedDefaults.set(itemsData, forKey: itemsKey)
                
                keyValueStore.set(doneItemsData, forKey: doneItemsKey)
                sharedDefaults.set(doneItemsData, forKey: doneItemsKey)
                
                keyValueStore.set(pinnedItemsData, forKey: pinnedItemsKey)
                sharedDefaults.set(pinnedItemsData, forKey: pinnedItemsKey)
                
                keyValueStore.synchronize()
                sharedDefaults.synchronize()
                
                userDefaults.set(true, forKey: "migrationCompleted")
                userDefaults.removeObject(forKey: itemsKey)
                userDefaults.removeObject(forKey: doneItemsKey)
                userDefaults.removeObject(forKey: pinnedItemsKey)
            }
        }
    }
    
    @objc private func ubiquitousKeyValueStoreDidChange(notification: Notification) {
        // 处理 iCloud 同步变化
    }
    
    func saveItems(_ items: [TodoItem], _ doneItems: [TodoItem], _ pinnedItems: [TodoItem]) {
        let encoder = JSONEncoder()
        if let encodedItems = try? encoder.encode(items) {
            keyValueStore.set(encodedItems, forKey: itemsKey)
            sharedDefaults.set(encodedItems, forKey: itemsKey)
        }
        if let encodedDoneItems = try? encoder.encode(doneItems) {
            keyValueStore.set(encodedDoneItems, forKey: doneItemsKey)
            sharedDefaults.set(encodedDoneItems, forKey: doneItemsKey)
        }
        if let encodedPinnedItems = try? encoder.encode(pinnedItems) {
            keyValueStore.set(encodedPinnedItems, forKey: pinnedItemsKey)
            sharedDefaults.set(encodedPinnedItems, forKey: pinnedItemsKey)
        }
        keyValueStore.synchronize()
        sharedDefaults.synchronize()
        
        // 通知 WidgetKit 重新加载时间线
        WidgetCenter.shared.reloadTimelines(ofKind: "TodoWidget")
    }
    
    func loadItems() -> [TodoItem] {
        return decodeItems(forKey: itemsKey) ?? []
    }
    
    func loadDoneItems() -> [TodoItem] {
        return decodeItems(forKey: doneItemsKey) ?? []
    }
    
    func loadPinnedItems() -> [TodoItem] {
        return decodeItems(forKey: pinnedItemsKey) ?? []
    }
    
    // 新增：加载分类数据
    func loadCategories() -> [Category] {
        return decodeCategories(forKey: categoriesKey) ?? []
    }
    
    private func decodeItems(forKey key: String) -> [TodoItem]? {
        if let data = keyValueStore.data(forKey: key) {
            return try? JSONDecoder().decode([TodoItem].self, from: data)
        }
        return nil
    }
    
    // 新增：解码分类数据
    private func decodeCategories(forKey key: String) -> [Category]? {
        if let data = keyValueStore.data(forKey: key) {
            return try? JSONDecoder().decode([Category].self, from: data)
        }
        return nil
    }
}
