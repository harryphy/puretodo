//
//  TodoWidget.swift
//  Pull to do
//
//  Created by PHY on 2024/8/8.
//

// TodoWidgetProvider.swift

import WidgetKit
import SwiftUI
import Foundation

struct TodoEntry: TimelineEntry {
    let date: Date
    let items: [TodoItem]
    let totalItemCount: Int
}

struct TodoWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodoEntry {
        TodoEntry(date: Date(), items: [TodoItem(title: "Placeholder", isDone: false, date: Date())], totalItemCount: 0)
    }

    func getSnapshot(in context: Context, completion: @escaping (TodoEntry) -> Void) {
        // 创建 8 条预览文本
        let sampleItems = [
                    TodoItem(title: "Buy groceries", isDone: false, date: Date()),
                    TodoItem(title: "Complete project report", isDone: false, date: Date()),
                    TodoItem(title: "Plan weekend trip", isDone: false, date: Date()),
                    TodoItem(title: "Exercise for 30 minutes", isDone: false, date: Date()),
                    TodoItem(title: "Call mom", isDone: false, date: Date()),
                    TodoItem(title: "Read a book", isDone: false, date: Date()),
                    TodoItem(title: "Schedule dentist appointment", isDone: false, date: Date()),
                    TodoItem(title: "Update resume", isDone: false, date: Date())
                ]
        // 创建一个假的总数
        let fakeTotalItemCount = 15

        // 创建快照条目
        let entry = TodoEntry(date: Date(), items: sampleItems, totalItemCount: fakeTotalItemCount)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodoEntry>) -> Void) {
        // 从共享数据存储中加载 pinnedTodoItems 和 todoItems
        let userDefaults = UserDefaults(suiteName: "group.com.Harry.P.Pure-To-Do")
        var pinnedItems: [TodoItem] = []
        var otherItems: [TodoItem] = []
        var categories: [Category] = []

        if let pinnedData = userDefaults?.data(forKey: "pinnedTodoItems"),
           let decodedPinnedItems = try? JSONDecoder().decode([TodoItem].self, from: pinnedData) {
            pinnedItems = decodedPinnedItems
        }
        
        if let itemsData = userDefaults?.data(forKey: "todoItems"),
           let decodedItems = try? JSONDecoder().decode([TodoItem].self, from: itemsData) {
            otherItems = decodedItems
        }
        
        // 加载分类数据
        if let categoriesData = userDefaults?.data(forKey: "categories"),
           let decodedCategories = try? JSONDecoder().decode([Category].self, from: categoriesData) {
            categories = decodedCategories
        }

        // 找到"To Do"分类的ID
        let toDoCategoryId = categories.first(where: { $0.name == "To Do" })?.id
        
        // 只显示"To Do"分类的事项（包括没有分类ID的旧数据）
        let filteredPinnedItems = pinnedItems.filter { item in
            if let toDoCategoryId = toDoCategoryId {
                return item.categoryId == toDoCategoryId || item.categoryId == nil
            } else {
                return item.categoryId == nil
            }
        }
        
        let filteredOtherItems = otherItems.filter { item in
            if let toDoCategoryId = toDoCategoryId {
                return item.categoryId == toDoCategoryId || item.categoryId == nil
            } else {
                return item.categoryId == nil
            }
        }

        // 合并 pinnedItems 和 otherItems
        let items = filteredPinnedItems + filteredOtherItems

        // 计算总数
        let totalItemCount = items.count

        // 创建时间线条目
        let entry = TodoEntry(date: Date(), items: items, totalItemCount: totalItemCount)
        let timeline = Timeline(entries: [entry], policy: .atEnd)
        completion(timeline)
    }
}
