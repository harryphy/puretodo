//  Models.swift
//  Pure To Do
//
//  Created by PHY on 2023/12/8.
//  Version 2.4

import Foundation

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

// 定义 TodoItem 结构体
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
    
    // 自定义初始化器
    init(title: String, isDone: Bool, date: Date, subItems: [TodoItem] = [], categoryId: UUID? = nil) {
        self.id = UUID()
        self.title = title
        self.isDone = isDone
        self.isPinned = false
        self.date = date
        self.doneDate = nil
        self.reminderDate = nil
        self.subItems = subItems
        self.categoryId = categoryId
        self.reminderType = nil
        self.reminderTime = nil
        self.reminderWeekdays = nil
        self.reminderDaysOfMonth = nil
    }
    
    // 完整初始化器
    init(id: UUID = UUID(), title: String, isDone: Bool, isPinned: Bool = false, date: Date, doneDate: Date? = nil, reminderDate: Date? = nil, subItems: [TodoItem] = [], categoryId: UUID? = nil, reminderType: ReminderType? = nil, reminderTime: Date? = nil, reminderWeekdays: [Int]? = nil, reminderDaysOfMonth: [Int]? = nil) {
        self.id = id
        self.title = title
        self.isDone = isDone
        self.isPinned = isPinned
        self.date = date
        self.doneDate = doneDate
        self.reminderDate = reminderDate
        self.subItems = subItems
        self.categoryId = categoryId
        self.reminderType = reminderType
        self.reminderTime = reminderTime
        self.reminderWeekdays = reminderWeekdays
        self.reminderDaysOfMonth = reminderDaysOfMonth
    }
} 
