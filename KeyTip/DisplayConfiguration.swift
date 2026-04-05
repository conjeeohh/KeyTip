//
//  DisplayConfiguration.swift
//  KeyTip
//
//  当前 App 的展示配置模型
//  配置来源为按应用划分的 TOML 文件
//

import Foundation

/// 单个应用的展示配置
struct AppDisplayConfig: Sendable {

    /// 是否包含系统读取到的默认快捷键
    var includeSystemShortcuts: Bool = true

    /// 需要隐藏的系统快捷键 ID
    var hiddenSystemItems: [String] = []

    /// 自定义展示项
    var items: [CustomDisplayItem] = []

    static let defaultGroupName = "自定义"

    /// 首次创建配置文件时写入的模板
    static let fileTemplate = """
    include_system_shortcuts = true
    hide = []

    # 添加自定义展示项示例：
    #
    # [[items]]
    # title = "切换到左侧标签页"
    # shortcut = "⌘⇧["
    # group = "标签页"
    #
    # [[items]]
    # title = "打开阅读模式"
    # command = "Show Reader"
    # group = "命令"
    """
}

/// 自定义展示项
struct CustomDisplayItem: Identifiable, Sendable, Hashable {
    let title: String
    let group: String
    let kind: CustomDisplayItemKind

    var id: String {
        "\(group)|\(title)|\(kind.content)"
    }
}

/// 自定义展示项类型
enum CustomDisplayItemKind: Sendable, Hashable {
    case shortcut(String)
    case command(String)

    var content: String {
        switch self {
        case .shortcut(let value), .command(let value):
            return value
        }
    }
}

/// HUD 渲染层的统一展示项
struct DisplayItem: Identifiable, Sendable, Hashable {
    let title: String
    let groupName: String
    let accessory: DisplayItemAccessory
    let source: DisplayItemSource

    var id: String {
        "\(groupName)|\(title)|\(accessory.content)|\(source.identity)"
    }

    var isCustom: Bool {
        if case .custom = source {
            return true
        }
        return false
    }

    var systemItemID: String? {
        if case .system(let itemID) = source {
            return itemID
        }
        return nil
    }
}

/// HUD 展示项来源
enum DisplayItemSource: Sendable, Hashable {
    case system(itemID: String)
    case custom

    var identity: String {
        switch self {
        case .system(let itemID):
            return "system:\(itemID)"
        case .custom:
            return "custom"
        }
    }
}

/// HUD 渲染层的右侧展示内容
enum DisplayItemAccessory: Sendable, Hashable {
    case shortcut(String)
    case command(String)

    var content: String {
        switch self {
        case .shortcut(let value), .command(let value):
            return value
        }
    }
}

/// HUD 分组
struct DisplayGroup: Identifiable, Sendable {
    let title: String
    let items: [DisplayItem]

    var id: String { title }
}

/// 配置列表页中使用的摘要
struct AppDisplayConfigSummary: Sendable {
    let includeSystemShortcuts: Bool
    let hiddenCount: Int
    let shortcutCount: Int
    let commandCount: Int
}

extension AppDisplayConfig {
    var summary: AppDisplayConfigSummary {
        let shortcutCount = items.reduce(into: 0) { count, item in
            if case .shortcut = item.kind {
                count += 1
            }
        }

        let commandCount = items.count - shortcutCount

        return AppDisplayConfigSummary(
            includeSystemShortcuts: includeSystemShortcuts,
            hiddenCount: hiddenSystemItems.count,
            shortcutCount: shortcutCount,
            commandCount: commandCount
        )
    }
}
