//
//  ShortcutMerger.swift
//  KeyTip
//
//  快捷键数据合并引擎
//  将 Accessibility API 读取的系统快捷键与用户自定义配置合并
//  合并流程：系统快捷键 → 剔除隐藏项 → 追加自定义项
//

import Foundation

/// 快捷键数据合并器
/// 负责将系统读取的菜单栏快捷键与用户的自定义配置进行合并
///
/// ## 合并规则
/// 1. 以 Accessibility API 读取的系统快捷键为基础数据
/// 2. 根据 hiddenItems 配置，剔除用户标记为隐藏的快捷键
/// 3. 根据 customItems 配置，追加用户自定义的快捷键
/// 4. 自定义快捷键按 menuName 分组，如果与已有分组同名则合并到该分组末尾
@MainActor
enum ShortcutMerger {

    /// 合并系统快捷键与自定义配置
    /// - Parameters:
    ///   - systemGroups: 从 Accessibility API 读取的系统快捷键分组
    ///   - bundleID: 目标应用的 Bundle ID，用于查找对应的自定义配置
    /// - Returns: 合并后的快捷键分组列表
    static func merge(systemGroups: [ShortcutGroup], for bundleID: String) -> [ShortcutGroup] {
        // 获取该应用的自定义配置
        guard let config = ConfigStore.shared.config(for: bundleID) else {
            // 没有自定义配置，直接返回系统快捷键
            return systemGroups
        }

        // Step 1: 剔除隐藏项
        let filteredGroups = filterHiddenItems(groups: systemGroups, hiddenItems: config.hiddenItems)

        // Step 2: 追加自定义项
        let mergedGroups = appendCustomItems(groups: filteredGroups, customItems: config.customItems)

        return mergedGroups
    }

    // MARK: - 私有方法

    /// 从快捷键分组中剔除隐藏项
    /// - Parameters:
    ///   - groups: 原始快捷键分组
    ///   - hiddenItems: 需要隐藏的快捷键 ID 列表
    /// - Returns: 剔除隐藏项后的分组（空分组会被移除）
    private static func filterHiddenItems(groups: [ShortcutGroup], hiddenItems: [String]) -> [ShortcutGroup] {
        // 如果没有隐藏项，直接返回
        guard !hiddenItems.isEmpty else { return groups }

        // 将隐藏列表转为 Set 以提升查找效率
        let hiddenSet = Set(hiddenItems)

        var result: [ShortcutGroup] = []

        for group in groups {
            // 过滤掉被隐藏的快捷键
            let filteredItems = group.items.filter { !hiddenSet.contains($0.id) }

            // 只保留非空分组
            if !filteredItems.isEmpty {
                result.append(ShortcutGroup(menuName: group.menuName, items: filteredItems))
            }
        }

        let hiddenCount = hiddenItems.count
        let removedCount = groups.reduce(0) { $0 + $1.items.count } - result.reduce(0) { $0 + $1.items.count }
        if removedCount > 0 {
            print("🔇 已隐藏 \(removedCount) 个快捷键（配置了 \(hiddenCount) 条隐藏规则）")
        }

        return result
    }

    /// 将自定义快捷键追加到分组中
    /// - Parameters:
    ///   - groups: 已过滤的快捷键分组
    ///   - customItems: 用户自定义的快捷键条目
    /// - Returns: 追加自定义项后的分组
    private static func appendCustomItems(groups: [ShortcutGroup], customItems: [CustomShortcutEntry]) -> [ShortcutGroup] {
        // 如果没有自定义项，直接返回
        guard !customItems.isEmpty else { return groups }

        // 将自定义条目转换为 ShortcutItem 并按 menuName 分组
        var customGroups: [String: [ShortcutItem]] = [:]
        for entry in customItems {
            let item = entry.toShortcutItem()
            customGroups[item.menuName, default: []].append(item)
        }

        // 合并自定义分组到已有分组
        var result = groups
        var existingMenuNames = Set(groups.map { $0.menuName })

        for (menuName, items) in customGroups {
            if existingMenuNames.contains(menuName) {
                // 如果同名分组已存在，将自定义项追加到该分组末尾
                if let index = result.firstIndex(where: { $0.menuName == menuName }) {
                    let existingItems = result[index].items
                    result[index] = ShortcutGroup(menuName: menuName, items: existingItems + items)
                }
            } else {
                // 新分组，追加到末尾
                result.append(ShortcutGroup(menuName: menuName, items: items))
                existingMenuNames.insert(menuName)
            }
        }

        print("✨ 已追加 \(customItems.count) 个自定义快捷键")

        return result
    }
}
