//
//  DisplayContentBuilder.swift
//  KeyTip
//
//  将系统快捷键与当前 App 的展示配置组装成 HUD 可渲染的数据
//

import Foundation

@MainActor
enum DisplayContentBuilder {

    static func build(systemGroups: [ShortcutGroup], config: AppDisplayConfig) -> [DisplayGroup] {
        var result: [DisplayGroup] = []

        if config.includeSystemShortcuts {
            let hiddenItems = Set(config.hiddenSystemItems)

            for group in systemGroups {
                let displayItems = group.items.compactMap { item -> DisplayItem? in
                    guard !hiddenItems.contains(item.id) else { return nil }

                    return DisplayItem(
                        title: item.title,
                        groupName: group.menuName,
                        accessory: .shortcut(item.displayShortcut),
                        isCustom: false
                    )
                }

                if !displayItems.isEmpty {
                    result.append(DisplayGroup(title: group.menuName, items: displayItems))
                }
            }
        }

        let customGroups = buildCustomGroups(from: config.items)
        result.append(contentsOf: customGroups)

        return result
    }

    private static func buildCustomGroups(from items: [CustomDisplayItem]) -> [DisplayGroup] {
        guard !items.isEmpty else { return [] }

        var groupedItems: [String: [DisplayItem]] = [:]
        var orderedGroupNames: [String] = []

        for item in items {
            let displayItem: DisplayItem

            switch item.kind {
            case .shortcut(let shortcut):
                displayItem = DisplayItem(
                    title: item.title,
                    groupName: item.group,
                    accessory: .shortcut(shortcut),
                    isCustom: true
                )
            case .command(let command):
                displayItem = DisplayItem(
                    title: item.title,
                    groupName: item.group,
                    accessory: .command(command),
                    isCustom: true
                )
            }

            if groupedItems[item.group] == nil {
                orderedGroupNames.append(item.group)
            }

            groupedItems[item.group, default: []].append(displayItem)
        }

        return orderedGroupNames.compactMap { groupName in
            guard let items = groupedItems[groupName], !items.isEmpty else { return nil }
            return DisplayGroup(title: groupName, items: items)
        }
    }
}
