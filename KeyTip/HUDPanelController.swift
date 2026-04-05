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
@MainActor
class HUDPanelController {

    // MARK: - 属性

    private var panel: HUDPanel?
    private var clickMonitor: Any?

    var isShowing: Bool {
        return panel?.isVisible ?? false
    }

    // MARK: - 公开方法

    func show(appInfo: ActiveAppInfo, groups: [DisplayGroup], onConfigure: (() -> Void)? = nil) {
        if isShowing {
            dismiss()
        }

        let contentView = HUDContentView(
            appInfo: appInfo,
            displayGroups: groups,
            onConfigure: {
                onConfigure?()
            },
            onDismiss: { [weak self] in
                self?.dismiss()
            }
        )

        // 动态计算面板尺寸
        let panelSize = calculatePanelSize(
            groupCount: groups.count,
            totalItems: groups.reduce(0) { $0 + $1.items.count }
        )

        let hudPanel = HUDPanel(contentRect: NSRect(origin: .zero, size: panelSize))

        // 将 SwiftUI 视图嵌入面板 — 背景必须完全透明
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.frame = NSRect(origin: .zero, size: panelSize)
        hostingView.autoresizingMask = [.width, .height]

        // 确保 hosting view 背景透明，让 SwiftUI 层的毛玻璃和阴影生效
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = .clear

        hudPanel.contentView = hostingView

        panel = hudPanel
        hudPanel.showCentered()
        setupClickOutsideMonitor()

        print("🖥️ HUD 已显示")
    }

    func dismiss() {
        removeClickOutsideMonitor()
        panel?.dismissAnimated()
        panel = nil
        print("🖥️ HUD 已关闭")
    }

    // MARK: - 私有方法

    private func calculatePanelSize(groupCount: Int, totalItems: Int) -> NSSize {
        let baseWidth: CGFloat
        if groupCount <= 2 {
            baseWidth = 560
        } else if groupCount <= 5 {
            baseWidth = 720
        } else {
            baseWidth = 900
        }

        let cols = groupCount <= 2 ? max(groupCount, 1) : (groupCount <= 5 ? 2 : 3)
        let maxItemsPerCol = max(totalItems / cols, 6)
        let baseHeight = min(CGFloat(maxItemsPerCol * 26 + 120), 580)

        return NSSize(width: baseWidth, height: max(baseHeight, 260))
    }

    private func setupClickOutsideMonitor() {
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.dismiss()
            }
        }
    }

    private func removeClickOutsideMonitor() {
        if let monitor = clickMonitor {
            NSEvent.removeMonitor(monitor)
            clickMonitor = nil
        }
    }
}
