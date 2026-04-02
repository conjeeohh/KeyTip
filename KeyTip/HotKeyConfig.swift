//
//  HotKeyConfig.swift
//  KeyTip
//
//  热键配置模型
//  定义了长按触发的修饰键和时长，并存储在 UserDefaults 中
//

import Cocoa
import SwiftUI

/// 触发修饰键枚举
enum TriggerModifier: String, CaseIterable, Identifiable {
    case command = "Command"
    case option = "Option"
    case control = "Control"
    case shift = "Shift"

    var id: String { rawValue }

    /// 在设置中显示的本地化名称
    var displayName: String {
        switch self {
        case .command: return "长按 Command (⌘)"
        case .option:  return "长按 Option (⌥)"
        case .control: return "长按 Control (⌃)"
        case .shift:   return "长按 Shift (⇧)"
        }
    }

    /// 映射到 NSEvent 的 ModifierFlags
    var flags: NSEvent.ModifierFlags {
        switch self {
        case .command: return .command
        case .option:  return .option
        case .control: return .control
        case .shift:   return .shift
        }
    }
}

/// 热键配置键名，方便 UserDefaults 取用
enum ConfigKeys {
    static let triggerModifier = "Settings_TriggerModifier"
    static let triggerDuration = "Settings_TriggerDuration"
}
