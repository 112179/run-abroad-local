import SwiftUI

/// 界面风格 —— 三套可在 App 设置里随时切换的方案
enum UIStyle: String, CaseIterable, Codable, Identifiable {
    case cards      // A：卡片分组表单（默认）
    case dashboard  // B：结果优先 / 概览看板
    case wizard     // C：分步向导 + 大按钮

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cards: return "A · 卡片表单"
        case .dashboard: return "B · 结果优先"
        case .wizard: return "C · 分步向导"
        }
    }

    var subtitle: String {
        switch self {
        case .cards: return "分 6 张卡片集中填写，一次看全所有条件"
        case .dashboard: return "先给你结论：顶部大卡 + 时间线路径，表单收进抽屉"
        case .wizard: return "一屏一问，逐步推进，适合手机上慢慢填"
        }
    }

    var icon: String {
        switch self {
        case .cards: return "square.grid.2x2"
        case .dashboard: return "chart.bar.doc.horizontal"
        case .wizard: return "point.topleft.down.curvedto.point.bottomright.up"
        }
    }
}
