//
//  CustomShortcutConfig.swift
//  KeyTip
//
//  自定义快捷键配置模型
//  允许用户针对特定应用（通过 Bundle ID 标识）定义隐藏项和自定义快捷键
//

import Foundation

/// 单个自定义快捷键条目
/// 用于用户手动添加的，系统菜单栏中不存在的快捷键
struct CustomShortcutEntry: Codable, Sendable, Hashable, Identifiable {

    /// 唯一标识符
    let id: String

    /// 快捷键标题（如 "切换标签页"）
    let title: String

    /// 所属分类名称（如 "自定义"、"插件"）
    let menuName: String

    /// 修饰键组合的原始值（存储 ShortcutModifiers.rawValue 以支持 Codable）
    let modifiersRawValue: Int

    /// 快捷键字符（如 "T"、"⌫"）
    let keyCharacter: String

    // MARK: - 便捷属性

    /// 获取修饰键组合
    var modifiers: ShortcutModifiers {
        ShortcutModifiers(rawValue: modifiersRawValue)
    }

    // MARK: - 初始化

    /// 创建自定义快捷键条目
    init(title: String, menuName: String = "自定义", modifiers: ShortcutModifiers, keyCharacter: String) {
        self.id = UUID().uuidString
        self.title = title
        self.menuName = menuName
        self.modifiersRawValue = modifiers.rawValue
        self.keyCharacter = keyCharacter
    }

    /// 转换为 ShortcutItem 以便统一展示
    func toShortcutItem() -> ShortcutItem {
        return ShortcutItem(
            id: "custom.\(id)",
            title: title,
            menuName: menuName,
            modifiers: modifiers,
            keyCharacter: keyCharacter,
            isCustom: true
        )
    }
}

/// 针对特定应用的快捷键配置
/// 每个 Bundle ID 对应一个配置实例
struct AppShortcutConfig: Codable, Sendable {

    /// 目标应用的 Bundle ID（如 "com.apple.Safari"）
    let bundleIdentifier: String

    /// 需要隐藏的快捷键 ID 列表
    /// ID 格式为 "菜单名.标题"（如 "文件.新建窗口"）
    /// 匹配 ShortcutItem.id
    var hiddenItems: [String]

    /// 用户自定义添加的快捷键列表
    var customItems: [CustomShortcutEntry]

    // MARK: - 初始化

    init(bundleIdentifier: String, hiddenItems: [String] = [], customItems: [CustomShortcutEntry] = []) {
        self.bundleIdentifier = bundleIdentifier
        self.hiddenItems = hiddenItems
        self.customItems = customItems
    }
}

/// 全局配置容器
/// 包含所有应用的自定义配置
struct ShortcutConfiguration: Codable, Sendable {

    /// 所有应用的配置，以 Bundle ID 为键
    var appConfigs: [String: AppShortcutConfig]

    init(appConfigs: [String: AppShortcutConfig] = [:]) {
        self.appConfigs = appConfigs
    }

    /// 获取指定应用的配置（如果不存在则返回 nil）
    func config(for bundleID: String) -> AppShortcutConfig? {
        return appConfigs[bundleID]
    }

    /// 获取或创建指定应用的配置
    mutating func getOrCreateConfig(for bundleID: String) -> AppShortcutConfig {
        if let existing = appConfigs[bundleID] {
            return existing
        }
        let newConfig = AppShortcutConfig(bundleIdentifier: bundleID)
        appConfigs[bundleID] = newConfig
        return newConfig
    }

    /// 更新指定应用的配置
    mutating func updateConfig(_ config: AppShortcutConfig) {
        appConfigs[config.bundleIdentifier] = config
    }

    /// 删除指定应用的配置
    mutating func removeConfig(for bundleID: String) {
        appConfigs.removeValue(forKey: bundleID)
    }
}
