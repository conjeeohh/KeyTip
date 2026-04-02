//
//  ContentView.swift
//  KeyTip
//
//  临时主视图 - 将在 Step 5 中被正式的 HUD 和设置视图替换
//

import SwiftUI

/// 临时占位视图
/// 当前阶段应用以 Menu Bar 模式运行，此视图暂不显示
struct ContentView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "keyboard")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("KeyTip")
                .font(.title)
                .fontWeight(.bold)
            Text("全局快捷键查看工具")
                .foregroundStyle(.secondary)
            Text("应用正在状态栏运行中")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(width: 300, height: 200)
        .padding()
    }
}

#Preview {
    ContentView()
}
