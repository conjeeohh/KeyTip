//
//  HUDContentView.swift
//  KeyTip
//
//  HUD 悬浮窗内容视图
//  高品质 macOS 原生风格，对齐 Raycast / Apple 原生界面审美
//

import SwiftUI

// MARK: - NSVisualEffectView 桥接

/// 将 NSVisualEffectView 桥接到 SwiftUI
/// 提供比 SwiftUI 内建 .material 更精细的毛玻璃控制
struct VisualEffectBackground: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        view.wantsLayer = true
        view.layer?.cornerRadius = 16
        view.layer?.masksToBounds = true
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// MARK: - 主视图

/// HUD 悬浮窗的根内容视图
struct HUDContentView: View {

    let appInfo: ActiveAppInfo
    let shortcutGroups: [ShortcutGroup]
    var onDismiss: (() -> Void)?

    /// 动态列数
    private var columnCount: Int {
        let count = shortcutGroups.count
        if count <= 2 { return min(count, 2) }
        if count <= 5 { return 2 }
        return 3
    }

    /// 贪心分列算法 — 将分组均衡分配到各列
    private var columns: [[ShortcutGroup]] {
        guard !shortcutGroups.isEmpty else { return [] }
        let cols = columnCount
        var result: [[ShortcutGroup]] = Array(repeating: [], count: cols)
        var heights = Array(repeating: 0, count: cols)

        for group in shortcutGroups {
            let minIdx = heights.indices.min(by: { heights[$0] < heights[$1] }) ?? 0
            result[minIdx].append(group)
            heights[minIdx] += group.items.count + 2
        }
        return result
    }

    var body: some View {
        VStack(spacing: 0) {
            headerView
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 14)

            // 分隔线
            Rectangle()
                .fill(.primary.opacity(0.08))
                .frame(height: 0.5)
                .padding(.horizontal, 20)

            if shortcutGroups.isEmpty {
                emptyStateView
            } else {
                shortcutGridView
            }
        }
        .frame(minWidth: 560, maxWidth: 920, minHeight: 220, maxHeight: 620)
        .background(
            VisualEffectBackground(material: .hudWindow, blendingMode: .behindWindow)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.primary.opacity(0.1), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.25), radius: 30, y: 10)
        .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: 14) {
            // App 图标
            Image(nsImage: appInfo.icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 40, height: 40)
                .shadow(color: .black.opacity(0.12), radius: 3, y: 1)

            // App 名称 + Bundle ID
            VStack(alignment: .leading, spacing: 3) {
                Text(appInfo.localizedName)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(appInfo.bundleIdentifier)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // 快捷键总数
            let totalCount = shortcutGroups.reduce(0) { $0 + $1.items.count }
            Text("\(totalCount) 个快捷键")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.quaternary)
                .clipShape(Capsule())

            // 关闭按钮
            Button(action: { onDismiss?() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("关闭 (Esc)")
        }
    }

    // MARK: - 快捷键网格

    private var shortcutGridView: some View {
        ScrollView(.vertical, showsIndicators: true) {
            HStack(alignment: .top, spacing: 24) {
                ForEach(Array(columns.enumerated()), id: \.offset) { _, column in
                    VStack(alignment: .leading, spacing: 20) {
                        ForEach(column) { group in
                            ShortcutGroupView(group: group)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 18)
        }
    }

    // MARK: - 空状态

    private var emptyStateView: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "keyboard.badge.ellipsis")
                .font(.system(size: 40))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.tertiary)
            Text("未检测到快捷键")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)
            Text("该应用可能没有菜单栏快捷键，\n或需要授予辅助功能权限。")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity, minHeight: 160)
        .padding()
    }
}

// MARK: - 分组视图

struct ShortcutGroupView: View {

    let group: ShortcutGroup

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            // 分组标题
            Text(group.menuName.uppercased())
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
                .kerning(0.5)
                .padding(.bottom, 2)

            // 快捷键列表
            ForEach(group.items) { item in
                ShortcutItemRow(item: item)
            }
        }
    }
}

// MARK: - 快捷键行视图

struct ShortcutItemRow: View {

    let item: ShortcutItem

    var body: some View {
        HStack(spacing: 10) {
            // 菜单项标题
            Text(item.title)
                .font(.system(size: 13))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 12)

            // 快捷键按键 — 等宽字体，极简圆角背景
            KeyCapView(shortcut: item.displayShortcut)
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 6)
        .background(
            Group {
                if item.isCustom {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Color.accentColor.opacity(0.07))
                }
            }
        )
    }
}

// MARK: - 快捷键按钮视图

/// 单个快捷键组合的视觉展示
/// 使用等宽字体 + 极简圆角背景，对齐 Apple HIG 风格
struct KeyCapView: View {

    let shortcut: String

    var body: some View {
        Text(shortcut)
            .font(.system(size: 12, weight: .medium, design: .monospaced))
            .foregroundStyle(.primary)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Color(nsColor: .quaternarySystemFill))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .strokeBorder(.primary.opacity(0.06), lineWidth: 0.5)
            )
    }
}
