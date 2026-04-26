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
        // 当 iCloud 数据变化时，需要重新加载数据并解决冲突
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            // 通知应用重新加载数据
            NotificationCenter.default.post(name: NSNotification.Name("iCloudDataDidChange"), object: nil)
            
            // 解决数据冲突：比较 iCloud 和本地数据，使用最新的
            self.resolveDataConflicts()
        }
    }
    
    // 解决数据冲突：比较 iCloud 和本地数据的时间戳，使用最新的数据
    private func resolveDataConflicts() {
        // 获取 iCloud 数据
        let iCloudItems = decodeItemsFromKeyValueStore(forKey: itemsKey) ?? []
        let iCloudDoneItems = decodeItemsFromKeyValueStore(forKey: doneItemsKey) ?? []
        let iCloudPinnedItems = decodeItemsFromKeyValueStore(forKey: pinnedItemsKey) ?? []
        let iCloudCategories = decodeCategoriesFromKeyValueStore(forKey: categoriesKey) ?? []
        
        // 获取本地数据
        let localItems = decodeItemsFromSharedDefaults(forKey: itemsKey) ?? []
        let localDoneItems = decodeItemsFromSharedDefaults(forKey: doneItemsKey) ?? []
        let localPinnedItems = decodeItemsFromSharedDefaults(forKey: pinnedItemsKey) ?? []
        let localCategories = decodeCategoriesFromSharedDefaults(forKey: categoriesKey) ?? []
        
        // 比较并选择最新的数据（通过比较数组大小和最后修改时间）
        // 如果本地数据更多，说明本地数据更新，需要同步到 iCloud
        // 如果 iCloud 数据更多，说明 iCloud 数据更新，需要同步到本地
        
        var needsSave = false
        
        // 比较 items
        if shouldUseLocalData(local: localItems, iCloud: iCloudItems) {
            // 本地数据更新，同步到 iCloud
            if let encodedItems = try? JSONEncoder().encode(localItems) {
                keyValueStore.set(encodedItems, forKey: itemsKey)
                needsSave = true
            }
        } else if iCloudItems.count > localItems.count || !iCloudItems.isEmpty {
            // iCloud 数据更新，同步到本地
            if let encodedItems = try? JSONEncoder().encode(iCloudItems) {
                sharedDefaults.set(encodedItems, forKey: itemsKey)
            }
        }
        
        // 比较 doneItems
        if shouldUseLocalData(local: localDoneItems, iCloud: iCloudDoneItems) {
            if let encodedDoneItems = try? JSONEncoder().encode(localDoneItems) {
                keyValueStore.set(encodedDoneItems, forKey: doneItemsKey)
                needsSave = true
            }
        } else if iCloudDoneItems.count > localDoneItems.count || !iCloudDoneItems.isEmpty {
            if let encodedDoneItems = try? JSONEncoder().encode(iCloudDoneItems) {
                sharedDefaults.set(encodedDoneItems, forKey: doneItemsKey)
            }
        }
        
        // 比较 pinnedItems
        if shouldUseLocalData(local: localPinnedItems, iCloud: iCloudPinnedItems) {
            if let encodedPinnedItems = try? JSONEncoder().encode(localPinnedItems) {
                keyValueStore.set(encodedPinnedItems, forKey: pinnedItemsKey)
                needsSave = true
            }
        } else if iCloudPinnedItems.count > localPinnedItems.count || !iCloudPinnedItems.isEmpty {
            if let encodedPinnedItems = try? JSONEncoder().encode(iCloudPinnedItems) {
                sharedDefaults.set(encodedPinnedItems, forKey: pinnedItemsKey)
            }
        }
        
        // 比较 categories
        if shouldUseLocalData(local: localCategories, iCloud: iCloudCategories) {
            if let encodedCategories = try? JSONEncoder().encode(localCategories) {
                keyValueStore.set(encodedCategories, forKey: categoriesKey)
                needsSave = true
            }
        } else if iCloudCategories.count > localCategories.count || !iCloudCategories.isEmpty {
            if let encodedCategories = try? JSONEncoder().encode(iCloudCategories) {
                sharedDefaults.set(encodedCategories, forKey: categoriesKey)
            }
        }
        
        // 如果需要保存到 iCloud，执行同步
        if needsSave {
            keyValueStore.synchronize()
        }
        sharedDefaults.synchronize()
    }
    
    // 判断是否应该使用本地数据
    private func shouldUseLocalData<T: Collection>(local: T, iCloud: T) -> Bool {
        // 如果本地数据明显更多，使用本地数据
        if local.count > iCloud.count + 5 {
            return true
        }
        // 如果 iCloud 数据为空但本地有数据，使用本地数据
        if iCloud.isEmpty && !local.isEmpty {
            return true
        }
        // 如果本地数据包含 categoryId（新功能），而 iCloud 数据没有，使用本地数据
        if let localItems = local as? [TodoItem], let iCloudItems = iCloud as? [TodoItem] {
            let localHasCategories = localItems.contains { $0.categoryId != nil }
            let iCloudHasCategories = iCloudItems.contains { $0.categoryId != nil }
            if localHasCategories && !iCloudHasCategories && localItems.count >= iCloudItems.count {
                return true
            }
        }
        // 否则使用 iCloud 数据（假设 iCloud 是权威数据源）
        return false
    }
    
    // 从 KeyValueStore (iCloud) 解码数据
    func decodeItemsFromKeyValueStore(forKey key: String) -> [TodoItem]? {
        if let data = keyValueStore.data(forKey: key) {
            return try? JSONDecoder().decode([TodoItem].self, from: data)
        }
        return nil
    }
    
    func decodeCategoriesFromKeyValueStore(forKey key: String) -> [Category]? {
        if let data = keyValueStore.data(forKey: key) {
            return try? JSONDecoder().decode([Category].self, from: data)
        }
        return nil
    }
    
    // 从 SharedDefaults (本地) 解码数据
    func decodeItemsFromSharedDefaults(forKey key: String) -> [TodoItem]? {
        if let data = sharedDefaults.data(forKey: key) {
            return try? JSONDecoder().decode([TodoItem].self, from: data)
        }
        return nil
    }
    
    func decodeCategoriesFromSharedDefaults(forKey key: String) -> [Category]? {
        if let data = sharedDefaults.data(forKey: key) {
            return try? JSONDecoder().decode([Category].self, from: data)
        }
        return nil
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
        return loadDataWithFallback(forKey: itemsKey, decodeFunction: decodeItemsFromKeyValueStore) ?? []
    }
    
    func loadDoneItems() -> [TodoItem] {
        return loadDataWithFallback(forKey: doneItemsKey, decodeFunction: decodeItemsFromKeyValueStore) ?? []
    }
    
    func loadPinnedItems() -> [TodoItem] {
        return loadDataWithFallback(forKey: pinnedItemsKey, decodeFunction: decodeItemsFromKeyValueStore) ?? []
    }
    
    // 新增：加载分类数据
    func loadCategories() -> [Category] {
        return loadDataWithFallback(forKey: categoriesKey, decodeFunction: decodeCategoriesFromKeyValueStore) ?? []
    }
    
    // 加载数据，优先使用最新数据（比较 iCloud 和本地数据）
    private func loadDataWithFallback<T>(forKey key: String, decodeFunction: (String) -> T?) -> T? {
        // 先尝试从 iCloud 加载
        let iCloudData = decodeFunction(key)
        
        // 从本地加载
        let localData: T?
        if T.self == [TodoItem].self {
            localData = decodeItemsFromSharedDefaults(forKey: key) as? T
        } else if T.self == [Category].self {
            localData = decodeCategoriesFromSharedDefaults(forKey: key) as? T
        } else {
            localData = nil
        }
        
        // 比较并返回最新的数据
        if let iCloud = iCloudData as? [TodoItem], let local = localData as? [TodoItem] {
            // 如果本地数据明显更多，使用本地数据并同步到 iCloud
            if local.count > iCloud.count + 5 {
                // 同步本地数据到 iCloud
                if let encoded = try? JSONEncoder().encode(local) {
                    keyValueStore.set(encoded, forKey: key)
                    keyValueStore.synchronize()
                }
                return localData
            }
            // 如果 iCloud 数据更多或相等，使用 iCloud 数据
            return iCloudData
        } else if let iCloud = iCloudData as? [Category], let local = localData as? [Category] {
            if local.count > iCloud.count {
                if let encoded = try? JSONEncoder().encode(local) {
                    keyValueStore.set(encoded, forKey: key)
                    keyValueStore.synchronize()
                }
                return localData
            }
            return iCloudData
        }
        
        // 如果只有一种数据源，返回它
        return iCloudData ?? localData
    }
    
    // 保留旧的 decodeItems 方法以保持兼容性（现在使用新的方法）
    private func decodeItems(forKey key: String) -> [TodoItem]? {
        return decodeItemsFromKeyValueStore(forKey: key)
    }
    
    // 保留旧的 decodeCategories 方法以保持兼容性
    private func decodeCategories(forKey key: String) -> [Category]? {
        return decodeCategoriesFromKeyValueStore(forKey: key)
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
        // 监听 iCloud 数据变化
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(syncItems),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: NSUbiquitousKeyValueStore.default
        )
        // 监听自定义的 iCloud 数据变化通知
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(syncItems),
            name: NSNotification.Name("iCloudDataDidChange"),
            object: nil
        )
        
        // 启动时尝试恢复数据
        attemptDataRecovery()
    }
    
    @objc private func syncItems() {
        // 重新加载所有数据
        loadAllItems()
        loadCategories()
    }
    
    // 尝试从本地恢复数据（如果 iCloud 数据丢失或过旧）
    private func attemptDataRecovery() {
        // 检查 iCloud 和本地数据的一致性
        let iCloudItems = dataStore.decodeItemsFromKeyValueStore(forKey: "todoItems") ?? []
        let localItems = dataStore.decodeItemsFromSharedDefaults(forKey: "todoItems") ?? []
        
        // 如果本地数据明显更新，尝试恢复
        if localItems.count > iCloudItems.count + 5 {
            // 本地数据可能更新，尝试同步到 iCloud
            dataStore.saveItems(localItems, 
                              dataStore.decodeItemsFromSharedDefaults(forKey: "doneTodoItems") ?? [],
                              dataStore.decodeItemsFromSharedDefaults(forKey: "pinnedTodoItems") ?? [])
        }
    }
    
    func loadAllItems() {
        items = dataStore.loadItems()
        doneItems = dataStore.loadDoneItems()
        pinnedItems = dataStore.loadPinnedItems()
        
        // 清理所有"孤儿"通知（对应的事项已不存在或已完成）
        NotificationHelper.cleanupOrphanedNotifications(
            items: items,
            pinnedItems: pinnedItems,
            doneItems: doneItems
        )
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
