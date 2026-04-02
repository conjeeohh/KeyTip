//
//  HUDPanelController.swift
//  KeyTip
//
//  HUD 悬浮窗控制器
//  管理 HUD 面板的创建、显示、隐藏和内容更新
//

import Cocoa
import SwiftUI

/// HUD 悬浮窗控制器
/// 负责管理 HUD 面板的生命周期和内容展示
@MainActor
class HUDPanelController {

    // MARK: - 属性

    /// HUD 面板实例（懒加载，首次使用时创建）
    private var panel: HUDPanel?

    /// 当前是否显示中
    var isShowing: Bool {
        return panel?.isVisible ?? false
    }

    /// 全局点击事件监听器（用于点击外部关闭）
    private var clickMonitor: Any?

    // MARK: - 公开方法

    /// 显示 HUD，展示指定应用的快捷键
    /// - Parameters:
    ///   - appInfo: 前台应用信息
    ///   - groups: 快捷键分组列表
    func show(appInfo: ActiveAppInfo, groups: [ShortcutGroup]) {
        // 如果已经显示，先关闭旧的
        if isShowing {
            dismiss()
        }

        // 创建 SwiftUI 内容视图
        let contentView = HUDContentView(
            appInfo: appInfo,
            shortcutGroups: groups,
            onDismiss: { [weak self] in
                self?.dismiss()
            }
        )

        // 计算合适的面板尺寸
        let panelSize = calculatePanelSize(groupCount: groups.count, totalItems: groups.reduce(0) { $0 + $1.items.count })

        // 创建或复用面板
        let hudPanel = HUDPanel(contentRect: NSRect(origin: .zero, size: panelSize))

        // 将 SwiftUI 视图嵌入面板
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.frame = hudPanel.contentView!.bounds
        hostingView.autoresizingMask = [.width, .height]

        // 设置 hostingView 背景透明，让毛玻璃效果透出
        hostingView.layer?.backgroundColor = .clear

        hudPanel.contentView?.addSubview(hostingView)

        // 保存引用
        panel = hudPanel

        // 居中显示
        hudPanel.showCentered()

        // 注册全局点击监听器（点击面板外部关闭）
        setupClickOutsideMonitor()

        print("🖥️ HUD 已显示")
    }

    /// 关闭 HUD
    func dismiss() {
        // 移除点击外部监听器
        removeClickOutsideMonitor()

        // 动画关闭
        panel?.dismissAnimated()
        panel = nil

        print("🖥️ HUD 已关闭")
    }

    /// 切换显示/隐藏
    func toggle(appInfo: ActiveAppInfo, groups: [ShortcutGroup]) {
        if isShowing {
            dismiss()
        } else {
            show(appInfo: appInfo, groups: groups)
        }
    }

    // MARK: - 私有方法

    /// 计算面板尺寸
    private func calculatePanelSize(groupCount: Int, totalItems: Int) -> NSSize {
        // 根据快捷键数量动态调整面板尺寸
        let baseWidth: CGFloat
        let baseHeight: CGFloat

        if groupCount <= 2 {
            baseWidth = 520
        } else if groupCount <= 5 {
            baseWidth = 680
        } else {
            baseWidth = 860
        }

        // 高度根据最大列的项目数估算
        let maxItemsPerColumn = max(totalItems / max(groupCount > 4 ? 3 : 2, 1), 5)
        baseHeight = min(CGFloat(maxItemsPerColumn * 24 + 100), 550)

        return NSSize(width: baseWidth, height: max(baseHeight, 250))
    }

    /// 注册全局点击监听（点击 HUD 外部时关闭）
    private func setupClickOutsideMonitor() {
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.dismiss()
            }
        }
    }

    /// 移除全局点击监听
    private func removeClickOutsideMonitor() {
        if let monitor = clickMonitor {
            NSEvent.removeMonitor(monitor)
            clickMonitor = nil
        }
    }
}
