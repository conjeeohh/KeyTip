//
//  ShortcutItem.swift
//  KeyTip
//
//  快捷键数据模型
//  统一表示从 Accessibility API 读取的菜单栏快捷键信息
//

import Cocoa

/// 快捷键修饰键组合
/// 使用 OptionSet 以支持多个修饰键的组合（如 ⌘⇧）
struct ShortcutModifiers: OptionSet, Sendable, Hashable {
    let rawValue: Int

    /// Command (⌘) 键
    static let command  = ShortcutModifiers(rawValue: 1 << 0)
    /// Shift (⇧) 键
    static let shift    = ShortcutModifiers(rawValue: 1 << 1)
    /// Option/Alt (⌥) 键
    static let option   = ShortcutModifiers(rawValue: 1 << 2)
    /// Control (⌃) 键
    static let control  = ShortcutModifiers(rawValue: 1 << 3)

    /// 将修饰键转换为符号字符串（如 "⌘⇧"）
    /// 按照 macOS 标准顺序排列：⌃ ⌥ ⇧ ⌘
    var symbolString: String {
        var parts: [String] = []
        if contains(.control) { parts.append("⌃") }
        if contains(.option)  { parts.append("⌥") }
        if contains(.shift)   { parts.append("⇧") }
        if contains(.command) { parts.append("⌘") }
        return parts.joined()
    }
}

/// 单个快捷键条目
/// 表示一个菜单项及其对应的键盘快捷键
struct ShortcutItem: Identifiable, Sendable, Hashable {

    /// 唯一标识符
    let id: String

    /// 菜单项标题（如 "复制"、"粘贴"）
    let title: String

    /// 所属菜单分类（顶级菜单名，如 "文件"、"编辑"）
    let menuName: String

    /// 快捷键修饰键组合
    let modifiers: ShortcutModifiers

    /// 快捷键字符（如 "C"、"V"、"⌫"）
    /// 已转换为用户可读的显示格式
    let keyCharacter: String

    /// 快捷键的完整显示字符串（如 "⌘C"、"⌘⇧S"）
    var displayShortcut: String {
        return modifiers.symbolString + keyCharacter
    }

    /// 是否为自定义添加的快捷键（非系统读取）
    let isCustom: Bool

    // MARK: - 初始化

    /// 创建一个从菜单栏读取的快捷键条目
    init(title: String, menuName: String, modifiers: ShortcutModifiers, keyCharacter: String) {
        // 使用 菜单名+标题+快捷键 作为唯一 ID
        // 同一菜单下可能有同名菜单项但快捷键不同（如 Finder 的排序选项在不同上下文出现）
        self.id = "\(menuName).\(title).\(modifiers.symbolString)\(keyCharacter)"
        self.title = title
        self.menuName = menuName
        self.modifiers = modifiers
        self.keyCharacter = keyCharacter
        self.isCustom = false
    }

    /// 创建一个自定义快捷键条目
    init(id: String, title: String, menuName: String, modifiers: ShortcutModifiers, keyCharacter: String, isCustom: Bool) {
        self.id = id
        self.title = title
        self.menuName = menuName
        self.modifiers = modifiers
        self.keyCharacter = keyCharacter
        self.isCustom = isCustom
    }
}

/// 按菜单分类的快捷键分组
/// 用于 UI 展示时按菜单类别分组显示
struct ShortcutGroup: Identifiable, Sendable {

    /// 分组名称（即菜单名，如 "文件"、"编辑"）
    let menuName: String

    /// 该分组下的所有快捷键
    let items: [ShortcutItem]

    /// 使用菜单名作为 Identifiable 的 id
    var id: String { menuName }
}

// MARK: - 特殊按键字符映射

/// 将 Accessibility API 返回的特殊字符映射为用户可读的符号
/// AX API 返回的按键字符可能是 Unicode 私有区域的特殊码点
enum SpecialKeyMapping {

    /// 将特殊字符转换为可读符号
    /// - Parameter character: 从 AX API 获取的原始按键字符
    /// - Returns: 可读的按键符号字符串
    static func displayString(for character: String) -> String {
        // 如果是单个字符，检查是否为特殊功能键
        guard character.count == 1, let scalar = character.unicodeScalars.first else {
            return character.uppercased()
        }

        switch scalar.value {
        // 功能键区域 (NSEvent 特殊键码)
        case 0xF700: return "↑"       // Up Arrow
        case 0xF701: return "↓"       // Down Arrow
        case 0xF702: return "←"       // Left Arrow
        case 0xF703: return "→"       // Right Arrow
        case 0xF704: return "F1"
        case 0xF705: return "F2"
        case 0xF706: return "F3"
        case 0xF707: return "F4"
        case 0xF708: return "F5"
        case 0xF709: return "F6"
        case 0xF70A: return "F7"
        case 0xF70B: return "F8"
        case 0xF70C: return "F9"
        case 0xF70D: return "F10"
        case 0xF70E: return "F11"
        case 0xF70F: return "F12"
        case 0xF710: return "F13"
        case 0xF711: return "F14"
        case 0xF712: return "F15"
        case 0xF713: return "F16"
        case 0xF714: return "F17"
        case 0xF715: return "F18"
        case 0xF716: return "F19"
        case 0xF717: return "F20"

        // 其他特殊键
        case 0xF727: return "Ins"     // Insert
        case 0xF728: return "⌫"      // Delete (Forward)
        case 0xF729: return "↖"      // Home
        case 0xF72B: return "↘"      // End
        case 0xF72C: return "⇞"      // Page Up
        case 0xF72D: return "⇟"      // Page Down
        case 0xF72F: return "⎋"      // Escape (备用)

        // 常见控制字符
        case 0x08:   return "⌫"      // Backspace
        case 0x09:   return "⇥"      // Tab
        case 0x0D:   return "↩"      // Return/Enter
        case 0x1B:   return "⎋"      // Escape
        case 0x20:   return "␣"      // Space
        case 0x7F:   return "⌫"      // Delete

        default:
            // 普通字符直接大写显示
            return character.uppercased()
        }
    }
}
