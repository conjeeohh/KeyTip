//
//  DisplayConfigSerializer.swift
//  KeyTip
//
//  将当前展示配置序列化为 TOML 文本
//

import Foundation

enum DisplayConfigSerializer {

    static func serialize(_ config: AppDisplayConfig) -> String {
        var lines: [String] = []

        lines.append("include_system_shortcuts = \(config.includeSystemShortcuts ? "true" : "false")")

        if config.hiddenSystemItems.isEmpty {
            lines.append("hide = []")
        } else {
            lines.append("hide = [")
            for itemID in config.hiddenSystemItems {
                lines.append("  \(quoted(itemID)),")
            }
            lines.append("]")
        }

        if !config.items.isEmpty {
            lines.append("")
        }

        for (index, item) in config.items.enumerated() {
            lines.append("[[items]]")
            lines.append("title = \(quoted(item.title))")

            if item.group != AppDisplayConfig.defaultGroupName {
                lines.append("group = \(quoted(item.group))")
            }

            switch item.kind {
            case .shortcut(let shortcut):
                lines.append("shortcut = \(quoted(shortcut))")
            case .command(let command):
                lines.append("command = \(quoted(command))")
            }

            if index < config.items.count - 1 {
                lines.append("")
            }
        }

        return lines.joined(separator: "\n") + "\n"
    }

    private static func quoted(_ value: String) -> String {
        let encoder = JSONEncoder()
        let data = (try? encoder.encode(value)) ?? Data("\"\"".utf8)
        return String(decoding: data, as: UTF8.self)
    }
}
