//
//  TodoWidgetView.swift
//  Pull to do
//
//  Created by PHY on 2024/8/8.
//
// TodoWidgetView.swift

import SwiftUI
import WidgetKit
import Foundation

extension Color {
    init(hex: String) {
        let hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)
        self.init(
            .sRGB,
            red: Double((rgb >> 16) & 0xFF) / 255.0,
            green: Double((rgb >> 8) & 0xFF) / 255.0,
            blue: Double(rgb & 0xFF) / 255.0,
            opacity: 1.0
        )
    }
}

struct TodoWidgetEntryView: View {
    var entry: TodoWidgetProvider.Entry
    @Environment(\.widgetFamily) var family
    
    @Environment(\.colorScheme) var colorScheme
    var isDarkMode: Bool {
        colorScheme == .dark
    }
    
    var body: some View {
        if #available(iOSApplicationExtension 17.0, *) {
            switch family {
            case .systemSmall:
                smallWidgetView
            case .systemMedium:
                mediumWidgetView
            case .systemLarge:
                largeWidgetView
            default:
                smallWidgetView
            }
        } else {
            // 针对较低版本的回退处理
            Text("This widget requires iOS 17 or later.")
                .padding()
        }
    }
    
    @available(iOSApplicationExtension 17.0, *)
    private var smallWidgetView: some View {
        
        VStack(alignment: .leading) {
            Spacer().frame(height: 10)
            
            HStack(alignment:.top){
                Spacer().frame(width: 2)
                Image(isDarkMode ? "checkDM" : "checkLM")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 24)
                    .padding(.leading,-6)
                
                Spacer().frame(width: 6)
                Text("\(entry.totalItemCount) To Do")
                    .font(.system(size: 18))
                    .fontWeight(.bold)
                    .foregroundColor(isDarkMode ? .white.opacity(0.95) : .black.opacity(0.9))
            }
            Spacer().frame(height: 16)
            ForEach(entry.items.prefix(4).indices, id: \.self) { index in
                let item = entry.items[index]
                HStack {
                    Text("•") // 这里是圆点符号
                        .font(.system(size: 11)) // 调整大小
                        .fontWeight(.medium)
                        .foregroundColor(isDarkMode ? .white.opacity(0.9) : .black.opacity(0.9))
                    Spacer().frame(width: 2)
                    Text(item.title)
                        .font(.system(size: 11))
                        .fontWeight(.medium)
                        .lineLimit(1)
                        .foregroundColor(isDarkMode ? .white.opacity(0.95) : .black.opacity(0.9))
                        .padding(.vertical, 0)
                }
                if index < entry.items.prefix(4).count - 1 {
                    DottedSeparator()
                }
            }
            .frame(width:120, alignment:.leading)
            Spacer()
            
        }
        .containerBackground(LinearGradient(
            gradient: Gradient(colors: isDarkMode ? [Color(hex: "081222"), Color(hex: "171F2E")] : [Color(hex: "E8F3FB"), Color.white]),
            startPoint: .top,
            endPoint: .bottom
        ), for: .widget)
        .ignoresSafeArea() //
        
    }
    
    @available(iOSApplicationExtension 17.0, *)
    private var mediumWidgetView: some View {
        ZStack{
            // 背景图
            Image(isDarkMode ? "stars":"")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.trailing,30)
                .padding(.top,0)
            
            HStack(alignment: .top) {
                Spacer().frame(width: 7)
                
                VStack(alignment: .leading) {
                    Spacer().frame(height: 15)
                    ForEach(entry.items.prefix(5).indices, id: \.self) { index in
                        let item = entry.items[index]
                        HStack{
                            Text("•") // 这里是圆点符号
                                .font(.system(size: 12)) // 调整大小
                                .fontWeight(.medium)
                                .foregroundColor(isDarkMode ? .white.opacity(0.9) : .black.opacity(0.9))
                            Text(item.title)
                                .font(.system(size: 12))
                                .fontWeight(.medium)
                                .lineLimit(1)
                                .foregroundColor(isDarkMode ? .white.opacity(0.9) : .black.opacity(0.9))
                        }
                        if index < entry.items.prefix(5).count - 1 {
                            DottedSeparator()
                        }
                    }
                    Spacer().frame(height: 14)
                }
                .frame(width:180, alignment:.leading)
                Spacer().frame(width: 10)
                //Capsule().fill(Color(hex: "4BB7FF")).frame(height: 120).frame(width: 1.4).opacity(0.08).padding(.top,8)
                Spacer().frame(width: 8)
                VStack(){
                    Spacer().frame(height: 16)
                    Image(isDarkMode ? "checkDM" : "checkLM")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 34)
                        .padding(.leading,62)
                    Spacer()
                    Text("\(entry.totalItemCount) To Do")
                        .font(.system(size: 21))
                        .fontWeight(.bold)
                        .foregroundColor(isDarkMode ? .white.opacity(0.95) : .black.opacity(0.9))
                        .padding(.leading,-4)
                    Spacer().frame(height: 12)
                }
                .frame(maxWidth: .infinity, alignment:.leading)
                Spacer()
            }
            
            .containerBackground(LinearGradient(
                gradient: Gradient(colors: isDarkMode ? [Color(hex: "081222"), Color(hex: "171F2E")] : [Color(hex: "E8F3FB"), Color.white]),
                startPoint: .top,
                endPoint: .bottom
            ), for: .widget)
            .ignoresSafeArea() //
        }
    }
    
    @available(iOSApplicationExtension 17.0, *)
    private var largeWidgetView: some View {
        ZStack {
            Image("Lstars")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.top,-15)
            
            // 内容部分
            HStack(alignment: .top){
                Spacer()
                VStack(alignment: .leading) {
                    Spacer().frame(height: 30)
                    HStack(alignment: .top) {
                        Spacer().frame(width: 0)
                        Image("checkDM")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 32)
                            .padding(.leading,-3)
                        
                        Spacer().frame(width: 10)
                        
                        Text("\(entry.totalItemCount) To Do")
                            .font(.system(size: 26))
                            .fontWeight(.bold)
                            .foregroundColor(.white.opacity(0.95))
                            .padding(.top,0)
                    }
                    Spacer().frame(height: 24)
                    ForEach(entry.items.prefix(8).indices, id: \.self) { index in
                        let item = entry.items[index]
                        HStack{
                            Text("•") // 这里是圆点符号
                                .font(.system(size: 12)) // 调整大小
                                .fontWeight(.medium)
                                .foregroundColor(.white.opacity(0.9))
                            Text(item.title)
                                .font(.system(size: 12))
                                .fontWeight(.medium)
                                .lineLimit(1)
                                .foregroundColor(.white.opacity(0.9))
                                .padding(.vertical, -1)
                        }
                        if index < entry.items.prefix(8).count - 1 {
                            DottedSeparator()
                        }
                    }
                    .frame(width:230, alignment:.leading)
                    Spacer()
                }
                Spacer()
            }
        }
        .containerBackground(LinearGradient(
            gradient: Gradient(colors: [Color(hex: "081222"), Color(hex: "171F2E")]),
            startPoint: .top,
            endPoint: .bottom
        ), for: .widget)
        .ignoresSafeArea() //
    }
}

struct DottedSeparator: View {
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                path.move(to: CGPoint(x: 0, y: geometry.size.height / 2))
                path.addLine(to: CGPoint(x: geometry.size.width, y: geometry.size.height / 2))
            }
            .stroke(Color.gray.opacity(0.25), style: StrokeStyle(lineWidth: 1.2, lineCap: .round, dash: [1, 5]))
        }
        .frame(height: 1.2)
    }
}

@main
struct TodoWidget: Widget {
    let kind: String = "TodoWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodoWidgetProvider()) { entry in
            TodoWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Pure To Do")
        .description("Shows your to-do items.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct TodoWidget_Previews: PreviewProvider {
    static var previews: some View {
        if #available(iOSApplicationExtension 17.0, *) {
            Group {
                TodoWidgetEntryView(entry: TodoEntry(date: Date(), items: sampleItems, totalItemCount: 24))
                    .previewContext(WidgetPreviewContext(family: .systemSmall))
                
                TodoWidgetEntryView(entry: TodoEntry(date: Date(), items: sampleItems, totalItemCount: 24))
                    .previewContext(WidgetPreviewContext(family: .systemMedium))
                
                TodoWidgetEntryView(entry: TodoEntry(date: Date(), items: sampleItems, totalItemCount: 54))
                    .previewContext(WidgetPreviewContext(family: .systemLarge))
            }
        } else {
            Text("This widget requires iOS 17 or later.")
                .previewContext(WidgetPreviewContext(family: .systemSmall))
        }
    }
}

// Sample items for preview
let sampleItems = [
    TodoItem(title: "Excepteur sint occaecat cupidatat no", isDone: false, date: Date()),
    TodoItem(title: "sunt in culpa qui officia", isDone: false, date: Date()),
    TodoItem(title: "Duis aute irure dolor", isDone: false, date: Date()),
    TodoItem(title: "Excepteur sint occaecat cupidatat non Excepteur sint occaecat cupidatat non", isDone: false, date: Date()),
    TodoItem(title: "Item 5", isDone: false, date: Date()),
    TodoItem(title: "Consectetur adipiscing elit", isDone: false, date: Date()),
    TodoItem(title: "Item 7", isDone: false, date: Date()),
    TodoItem(title: "Item 8", isDone: false, date: Date()),
]
