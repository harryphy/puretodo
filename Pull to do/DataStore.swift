//  DataStore.swift
//  Pure To Do
//
//  Created by PHY on 2023/12/8.
//  Version 2.4

import Foundation
import WidgetKit

// 数据存储类
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
        ensureDefaultCategoryExists()
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
    
    // 确保默认分类存在
    private func ensureDefaultCategoryExists() {
        let categories = loadCategories()
        if categories.isEmpty {
            let defaultCategory = Category(name: "To Do")
            saveCategories([defaultCategory])
        }
        
        // 迁移现有数据到默认分类
        migrateExistingDataToDefaultCategory()
    }
    
    // 迁移现有数据到默认分类
    private func migrateExistingDataToDefaultCategory() {
        let categories = loadCategories()
        guard let defaultCategory = categories.first else { return }
        
        // 检查是否已经迁移过
        let keyValueStore = NSUbiquitousKeyValueStore.default
        if keyValueStore.bool(forKey: "categoryMigrationCompleted") {
            return
        }
        
        // 加载现有事项
        var items = loadItems()
        var pinnedItems = loadPinnedItems()
        var doneItems = loadDoneItems()
        
        // 为没有分类ID的事项分配默认分类
        var hasChanges = false
        
        for i in 0..<items.count {
            if items[i].categoryId == nil {
                items[i].categoryId = defaultCategory.id
                hasChanges = true
            }
        }
        
        for i in 0..<pinnedItems.count {
            if pinnedItems[i].categoryId == nil {
                pinnedItems[i].categoryId = defaultCategory.id
                hasChanges = true
            }
        }
        
        for i in 0..<doneItems.count {
            if doneItems[i].categoryId == nil {
                doneItems[i].categoryId = defaultCategory.id
                hasChanges = true
            }
        }
        
        // 保存更改
        if hasChanges {
            saveItems(items, doneItems, pinnedItems)
        }
        
        // 标记迁移完成
        keyValueStore.set(true, forKey: "categoryMigrationCompleted")
        keyValueStore.synchronize()
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
    
    // 新增：保存分类数据
    func saveCategories(_ categories: [Category]) {
        let encoder = JSONEncoder()
        if let encodedCategories = try? encoder.encode(categories) {
            keyValueStore.set(encodedCategories, forKey: categoriesKey)
            sharedDefaults.set(encodedCategories, forKey: categoriesKey)
        }
        keyValueStore.synchronize()
        sharedDefaults.synchronize()
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

class TodoDataStore: ObservableObject {
    @Published var items: [TodoItem] = []
    @Published var doneItems: [TodoItem] = []
    @Published var pinnedItems: [TodoItem] = []
    @Published var categories: [Category] = [] // 新增：分类数据
    
    private let dataStore = DataStore.shared
    
    init() {
        loadAllItems()
        loadCategories()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(syncItems),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: NSUbiquitousKeyValueStore.default
        )
    }
    
    @objc private func syncItems() {
        loadAllItems()
        loadCategories()
    }
    
    func loadAllItems() {
        items = dataStore.loadItems()
        doneItems = dataStore.loadDoneItems()
        pinnedItems = dataStore.loadPinnedItems()
    }
    
    // 新增：加载分类数据
    func loadCategories() {
        categories = dataStore.loadCategories()
    }
    
    func saveItems() {
        dataStore.saveItems(items, doneItems, pinnedItems)
    }
    
    // 新增：保存分类数据
    func saveCategories() {
        dataStore.saveCategories(categories)
    }
}
