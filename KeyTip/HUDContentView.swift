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
    var onConfigure: (() -> Void)?
    var onDismiss: (() -> Void)?
    @State private var visibleGroups: [DisplayGroup]

    init(
        appInfo: ActiveAppInfo,
        displayGroups: [DisplayGroup],
        onConfigure: (() -> Void)? = nil,
        onDismiss: (() -> Void)? = nil
    ) {
        self.appInfo = appInfo
        self.onConfigure = onConfigure
        self.onDismiss = onDismiss
        _visibleGroups = State(initialValue: displayGroups)
    }

    /// 动态列数
    private var columnCount: Int {
        let count = visibleGroups.count
        if count <= 2 { return min(count, 2) }
        if count <= 5 { return 2 }
        return 3
    }

    /// 贪心分列算法 — 将分组均衡分配到各列
    private var columns: [[DisplayGroup]] {
        guard !visibleGroups.isEmpty else { return [] }
        let cols = columnCount
        var result: [[DisplayGroup]] = Array(repeating: [], count: cols)
        var heights = Array(repeating: 0, count: cols)

        for group in visibleGroups {
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

            if visibleGroups.isEmpty {
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

            // 展示项总数
            let totalCount = visibleGroups.reduce(0) { $0 + $1.items.count }
            Text("\(totalCount) 项")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.quaternary)
                .clipShape(Capsule())

            Button(action: { onConfigure?() }) {
                Label("配置", systemImage: "slider.horizontal.3")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.quaternary)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .help("打开当前 App 的 TOML 配置文件")

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
        ScrollView(.vertical, showsIndicators: false) {
            HStack(alignment: .top, spacing: 24) {
                ForEach(Array(columns.enumerated()), id: \.offset) { _, column in
                    VStack(alignment: .leading, spacing: 20) {
                        ForEach(column) { group in
                            DisplayGroupView(
                                group: group,
                                onCopySystemItemID: copySystemItemID,
                                onHideSystemItem: hideSystemItem
                            )
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
        .overlay(alignment: .top) {
            ScrollEdgeFade(edge: .top)
        }
        .overlay(alignment: .bottom) {
            ScrollEdgeFade(edge: .bottom)
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
            Text("未检测到可展示内容")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)
            Text("该应用可能没有菜单栏快捷键，\n也可以点击上方“配置”添加自定义内容。")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity, minHeight: 160)
        .padding()
    }

    private func copySystemItemID(_ itemID: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(itemID, forType: .string)
        print("📋 已复制系统项 ID: \(itemID)")
    }

    private func hideSystemItem(_ itemID: String) {
        do {
            try ConfigStore.shared.addHiddenSystemItem(itemID, for: appInfo.bundleIdentifier)
            visibleGroups = visibleGroups.compactMap { group in
                let filteredItems = group.items.filter { $0.systemItemID != itemID }
                guard !filteredItems.isEmpty else { return nil }
                return DisplayGroup(title: group.title, items: filteredItems)
            }
        } catch {
            print("⚠️ 隐藏系统项失败 [\(appInfo.bundleIdentifier)]: \(error.localizedDescription)")
        }
    }
}

// MARK: - 分组视图

struct DisplayGroupView: View {

    let group: DisplayGroup
    let onCopySystemItemID: (String) -> Void
    let onHideSystemItem: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            // 分组标题
            Text(group.title.uppercased())
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
                .kerning(0.5)
                .padding(.bottom, 2)

            // 展示项列表
            ForEach(group.items) { item in
                DisplayItemRow(
                    item: item,
                    onCopySystemItemID: onCopySystemItemID,
                    onHideSystemItem: onHideSystemItem
                )
            }
        }
    }
}

// MARK: - 展示项行视图

struct DisplayItemRow: View {

    let item: DisplayItem
    let onCopySystemItemID: (String) -> Void
    let onHideSystemItem: (String) -> Void

    var body: some View {
        HStack(spacing: 10) {
            // 展示标题
            Text(item.title)
                .font(.system(size: 13))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 12)

            DisplayAccessoryView(accessory: item.accessory)

            if let itemID = item.systemItemID {
                Menu {
                    Button("复制 ID") {
                        onCopySystemItemID(itemID)
                    }

                    Button("隐藏此项", role: .destructive) {
                        onHideSystemItem(itemID)
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .help("复制系统项 ID 或隐藏此项")
            }
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
        .contextMenu {
            if let itemID = item.systemItemID {
                Button("复制 ID") {
                    onCopySystemItemID(itemID)
                }

                Button("隐藏此项") {
                    onHideSystemItem(itemID)
                }
            }
        }
    }
}

// MARK: - 右侧内容视图

struct DisplayAccessoryView: View {

    let accessory: DisplayItemAccessory

    var body: some View {
        switch accessory {
        case .shortcut(let shortcut):
            KeyCapView(shortcut: shortcut)

        case .command(let command):
            CommandPillView(command: command)
        }
    }
}

private enum ScrollFadeEdge {
    case top
    case bottom
}

private struct ScrollEdgeFade: View {

    let edge: ScrollFadeEdge

    var body: some View {
        Rectangle()
            .fill(.ultraThinMaterial)
            .mask(
                LinearGradient(
                    colors: edge == .top
                        ? [.black.opacity(0.55), .clear]
                        : [.clear, .black.opacity(0.55)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(height: 20)
            .allowsHitTesting(false)
    }
}

struct CommandPillView: View {

    let command: String

    var body: some View {
        HStack(spacing: 6) {
            Text("CMD")
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)

            Text(command)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
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
