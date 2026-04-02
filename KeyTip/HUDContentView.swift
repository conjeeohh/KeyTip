//
//  HUDContentView.swift
//  KeyTip
//
//  HUD 悬浮窗内容视图
//  使用 SwiftUI 编写快捷键展示网格，类似 CheatSheet 的排版
//

import SwiftUI

/// HUD 悬浮窗的根内容视图
/// 展示应用信息 + 快捷键网格 + 关闭按钮
struct HUDContentView: View {

    /// 当前前台应用信息
    let appInfo: ActiveAppInfo

    /// 快捷键分组列表
    let shortcutGroups: [ShortcutGroup]

    /// 关闭回调
    var onDismiss: (() -> Void)?

    // MARK: - 计算属性

    /// 动态列数（根据分组数量调整）
    private var columnCount: Int {
        let groupCount = shortcutGroups.count
        if groupCount <= 2 { return min(groupCount, 2) }
        if groupCount <= 4 { return 2 }
        return 3
    }

    /// 将分组分配到多列中
    private var columns: [[ShortcutGroup]] {
        guard !shortcutGroups.isEmpty else { return [] }
        let cols = columnCount
        var result: [[ShortcutGroup]] = Array(repeating: [], count: cols)

        // 使用贪心算法，按项目数将分组分配到最短的列
        var columnHeights = Array(repeating: 0, count: cols)

        for group in shortcutGroups {
            // 找到当前最短的列
            let minIndex = columnHeights.indices.min(by: { columnHeights[$0] < columnHeights[$1] }) ?? 0
            result[minIndex].append(group)
            // 1 为标题高度，每个 item 算 1 单位
            columnHeights[minIndex] += group.items.count + 1
        }

        return result
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // 顶部：应用信息栏
            headerView
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 12)

            Divider()
                .padding(.horizontal, 16)

            // 主体：快捷键网格
            if shortcutGroups.isEmpty {
                emptyStateView
            } else {
                shortcutGridView
            }
        }
        .frame(minWidth: 500, maxWidth: 900, minHeight: 200, maxHeight: 600)
    }

    // MARK: - 子视图

    /// 顶部应用信息栏
    private var headerView: some View {
        HStack(spacing: 12) {
            // 应用图标
            Image(nsImage: appInfo.icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 36, height: 36)
                .shadow(color: .black.opacity(0.15), radius: 2, y: 1)

            // 应用名称
            VStack(alignment: .leading, spacing: 2) {
                Text(appInfo.localizedName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
                Text(appInfo.bundleIdentifier)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            // 快捷键总数
            let totalCount = shortcutGroups.reduce(0) { $0 + $1.items.count }
            Text("\(totalCount) 个快捷键")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(.quaternary)
                .clipShape(Capsule())

            // 关闭按钮
            Button(action: { onDismiss?() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("关闭 (Esc)")
        }
    }

    /// 快捷键网格视图
    private var shortcutGridView: some View {
        ScrollView(.vertical, showsIndicators: true) {
            HStack(alignment: .top, spacing: 16) {
                ForEach(Array(columns.enumerated()), id: \.offset) { _, column in
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(column) { group in
                            ShortcutGroupView(group: group)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(16)
        }
    }

    /// 空状态视图
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "keyboard.badge.ellipsis")
                .font(.system(size: 36))
                .foregroundStyle(.tertiary)
            Text("未检测到快捷键")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
            Text("该应用可能没有菜单栏快捷键，\n或需要授予辅助功能权限。")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity, minHeight: 150)
        .padding()
    }
}

// MARK: - 分组视图

/// 单个快捷键分组视图
/// 显示分组标题 + 该分组下的所有快捷键条目
struct ShortcutGroupView: View {

    let group: ShortcutGroup

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // 分组标题
            Text(group.menuName)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.bottom, 2)

            // 快捷键条目列表
            ForEach(group.items) { item in
                ShortcutItemView(item: item)
            }
        }
    }
}

// MARK: - 单个快捷键条目视图

/// 单个快捷键条目视图
/// 左侧显示快捷键符号，右侧显示标题
struct ShortcutItemView: View {

    let item: ShortcutItem

    var body: some View {
        HStack(spacing: 8) {
            // 标题
            Text(item.title)
                .font(.system(size: 12))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 8)

            // 快捷键符号
            Text(item.displayShortcut)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.primary.opacity(0.85))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.primary.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(.primary.opacity(0.1), lineWidth: 0.5)
                )
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 4)
        .background(
            item.isCustom
                ? RoundedRectangle(cornerRadius: 4).fill(Color.accentColor.opacity(0.08))
                : RoundedRectangle(cornerRadius: 4).fill(Color.clear)
        )
    }
}
