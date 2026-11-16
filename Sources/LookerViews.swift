import SwiftUI

// MARK: - 风格 B：结果优先 Looker
// 顶部大结论卡（可点开调参）+ 按「时间成本」分的时间线，表单收进抽屉。

struct LookerView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showEditor = false
    @State private var showSettings = false
    @State private var tab: MatchStatus = .eligible

    private var bucket: MatchBucket { model.filtered }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    verdictCard
                    tabBar
                    let items = bucket[tab]
                    if items.isEmpty {
                        EmptyHint(status: tab)
                    } else {
                        VStack(spacing: 10) {
                            ForEach(Array(items.enumerated()), id: \.element.id) { idx, r in
                                NavigationLink(value: r.path) {
                                    TimelineRow(result: r, index: idx + 1, status: tab)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    footnote
                }
                .padding(.horizontal, 16)
                .padding(.top, 6)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("润学导航")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: Pathway.self) { p in
                DetailView(path: p, profile: model.profile)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: { Image(systemName: "slider.horizontal.3") }
                }
            }
            .sheet(isPresented: $showEditor) {
                ProfileEditorSheet()
            }
            .sheet(isPresented: $showSettings) {
                SettingsSheet(showReset: .constant(false))
            }
        }
    }

    // MARK: 结论卡

    private var verdictCard: some View {
        let b = model.bucket
        let total = b.total
        let ready = b.eligible.count
        let near = b.close.count

        return Button { showEditor = true } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(ready)").font(.system(size: 46, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("/ \(total) 条路径").font(.subheadline).foregroundStyle(.white.opacity(0.85))
                    Spacer()
                    Image(systemName: "slider.horizontal.3")
                        .font(.footnote).foregroundStyle(.white.opacity(0.85))
                }
                Text(verdictLine(ready: ready, near: near))
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.95))
                    .fixedSize(horizontal: false, vertical: true)

                // 进度条：符合 / 差一点 / 长期
                GeometryReader { geo in
                    HStack(spacing: 3) {
                        ForEach(MatchStatus.allCases, id: \.self) { s in
                            let w = total > 0 ? geo.size.width * CGFloat(b[s].count) / CGFloat(total) : 0
                            RoundedRectangle(cornerRadius: 3)
                                .fill(color(for: s))
                                .frame(width: max(0, w - 3))
                        }
                    }
                }
                .frame(height: 7)

                HStack(spacing: 12) {
                    legend("符合", b.eligible.count, .green)
                    legend("差一点", b.close.count, .orange)
                    legend("长期", b.stretch.count, .purple)
                    legend("走不通", b.blocked.count, .gray)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(colors: [Color(red: 0.12, green: 0.28, blue: 0.62),
                                        Color(red: 0.16, green: 0.42, blue: 0.78)],
                               startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: .black.opacity(0.18), radius: 16, y: 8)
        }
        .buttonStyle(.plain)
    }

    private func legend(_ t: String, _ n: Int, _ c: Color) -> some View {
        HStack(spacing: 4) {
            Circle().fill(c).frame(width: 6, height: 6)
            Text("\(t) \(n)").font(.caption2).foregroundStyle(.white.opacity(0.9))
        }
    }

    private func verdictLine(ready: Int, near: Int) -> String {
        if ready >= 20 { return "选择不少：\(ready) 条路径你现在就能走，另有 \(near) 条差一点。" }
        if ready > 0 { return "有 \(ready) 条现在就能走，\(near) 条只差一两项可以补的条件。" }
        if near > 0 { return "暂时没有完全符合的，但 \(near) 条只差一点 —— 通常是语言或资金。" }
        return "目前都被硬门槛挡住了（年龄 / 毕业年限 / 院校排名），看看能不能调整方向。"
    }

    // MARK: 分段

    private var tabBar: some View {
        HStack(spacing: 6) {
            ForEach(MatchStatus.allCases, id: \.self) { s in
                let on = tab == s
                Button {
                    withAnimation(.snappy(duration: 0.2)) { tab = s }
                } label: {
                    HStack(spacing: 4) {
                        Text(s.title).font(.caption.weight(on ? .semibold : .regular))
                        Text("\(bucket[s].count)").font(.caption2.weight(.bold))
                            .foregroundStyle(on ? .white : Color.secondary)
                            .padding(.horizontal, 5).padding(.vertical, 1)
                            .background(on ? color(for: s) : Color(.tertiarySystemFill), in: Capsule())
                    }
                    .padding(.horizontal, 11).padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(on ? Color(.secondarySystemGroupedBackground) : .clear,
                                in: Capsule())
                    .foregroundStyle(on ? Color.primary : Color.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Color(.tertiarySystemFill).opacity(0.6), in: Capsule())
    }

    private var footnote: some View {
        VStack(spacing: 6) {
            if !model.bottlenecks.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label("最划算的补法", systemImage: "lightbulb.max")
                        .font(.caption.weight(.semibold))
                    Text(model.bottlenecks.first!.text + "（可解锁 \(model.bottlenecks.first!.count) 条）")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
            }
            Text("初筛工具，不是法律意见 · 数据 \(Lexicon.updated)")
                .font(.caption2).foregroundStyle(.tertiary)
                .padding(.vertical, 16)
        }
    }

    private func color(for s: MatchStatus) -> Color {
        switch s {
        case .eligible: return .green
        case .close: return .orange
        case .stretch: return .purple
        case .blocked: return .gray
        }
    }
}

// MARK: - 时间线行

private struct TimelineRow: View {
    let result: MatchResult
    let index: Int
    let status: MatchStatus

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                Text("\(index)")
                    .font(.caption2.weight(.bold)).monospacedDigit()
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(color, in: Circle())
                Rectangle().fill(Color(.separator)).frame(width: 1).frame(maxHeight: .infinity)
                    .opacity(0)
            }
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(result.path.flag)
                    Text(result.path.name).font(.subheadline.weight(.semibold)).lineLimit(2)
                    Spacer(minLength: 2)
                    Text("\(result.score)").font(.caption.weight(.bold)).monospacedDigit()
                        .foregroundStyle(color)
                }
                Text("\(result.path.country) · \(Lexicon.typeLabel(result.path.type))\(Engine.leadsToPR(result.path) ? " · 通往永居" : "")")
                    .font(.caption2).foregroundStyle(.secondary)
                if let e = result.effort {
                    HStack(spacing: 5) {
                        Image(systemName: "hourglass").font(.system(size: 8))
                        Text("准备 " + Fmt.months(e.months))
                    }
                    .font(.caption2).foregroundStyle(.orange)
                }
                if result.status != .eligible, let first = (result.hardGaps + result.softGaps).first {
                    Text(first.text).font(.caption2).foregroundStyle(.secondary).lineLimit(2)
                }
            }
            .padding(12)
            .background(Color(.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private var color: Color {
        switch status {
        case .eligible: return .green
        case .close: return .orange
        case .stretch: return .purple
        case .blocked: return .gray
        }
    }
}

private struct EmptyHint: View {
    let status: MatchStatus
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray").font(.title2).foregroundStyle(.tertiary)
            Text("这一类暂时没有匹配的路径").font(.footnote).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

// MARK: - 调参抽屉（同一套字段，底部弹起）

struct ProfileEditorSheet: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var section = 0

    private var b: ProfileFieldBindings { ProfileFieldBindings(model: model) }
    private let titles = ["基本", "语言", "经验", "收入", "技能", "目标"]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("", selection: $section) {
                    ForEach(0..<titles.count, id: \.self) { Text(titles[$0]).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

                ScrollView {
                    VStack(spacing: 14) {
                        switch section {
                        case 0: FieldGroup { BasicFields(b: b) }
                        case 1: FieldGroup { LanguageFields(b: b) }
                        case 2: FieldGroup { ExperienceFields(b: b) }
                        case 3: FieldGroup { IncomeFields(b: b) }
                        case 4: FieldGroup { SkillFields(b: b) }
                        default: FieldGroup { GoalFields(b: b) }
                        }
                    }
                    .padding(16)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("调整条件")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}

struct FieldGroup<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(spacing: 12) { content }
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
