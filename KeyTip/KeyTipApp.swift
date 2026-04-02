//
//  KeyTipApp.swift
//  KeyTip
//
//  应用入口 - 采用 AppDelegate 结合 SwiftUI App 的架构
//  使用 @NSApplicationDelegateAdaptor 桥接 AppDelegate，以便更好地控制窗口和全局生命周期
//

import SwiftUI

@main
struct KeyTipApp: App {

    // MARK: - AppDelegate 桥接

    /// 使用 @NSApplicationDelegateAdaptor 将 AppDelegate 桥接到 SwiftUI 生命周期
    /// 这样可以同时利用 SwiftUI 的声明式 API 和 AppKit 的底层控制能力
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    // MARK: - Scene

    var body: some Scene {
        // 使用 Settings scene 而非 WindowGroup
        // 因为本应用是 Menu Bar 应用，不需要主窗口
        // Settings scene 会在用户点击「偏好设置」时显示（Step 5 中完善）
        Settings {
            Text("KeyTip 偏好设置将在后续步骤中实现")
                .frame(width: 400, height: 300)
                .padding()
        }
    }
}
