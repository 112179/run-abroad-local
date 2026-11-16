import SwiftUI

// MARK: - 结果页

struct ResultsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showFilters = false
    @State private var expanded: Set<String> = []

    private var bucket: MatchBucket { model.bucket }
    private var filtered: MatchBucket { model.filtered }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16, pinnedViews: [.sectionHeaders]) {
                    summary
                    if let note = model.filters.hiddenNote(bucket, model.profile, total: bucket.total) {
                        Text(note)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 4)
                    }
                    ForEach(MatchStatus.allCases, id: \.self) { status in
                        let items = filtered[status]
                        if !items.isEmpty {
                            Section {
                                VStack(spacing: 10) {
                                    ForEach(Array(items.enumerated()), id: \.element.id) { idx, r in
                                        NavigationLink(value: r.path) {
                                            ResultCard(result: r, rank: idx + 1)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, 16)
                            } header: {
                                GroupHeader(status: status, count: items.count)
                            }
                        }
                    }
                    Text("结果仅用于初筛，政策随时变动，请以官网为准")
                        .font(.caption2).foregroundStyle(.tertiary)
                        .padding(.vertical, 20)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(model.filters.isEmpty ? "匹配结果" : "匹配结果（已筛选）")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: Pathway.self) { p in
                DetailView(path: p, profile: model.profile)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        model.page = .form
                    } label: {
                        Label("修改信息", systemImage: "chevron.left")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showFilters = true
                    } label: {
                        Image(systemName: model.filters.isEmpty
                              ? "line.3.horizontal.decrease.circle"
                              : "line.3.horizontal.decrease.circle.fill")
                    }
                }
            }
            .sheet(isPresented: $showFilters) {
                FilterSheet()
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    // MARK: 概览

    private var summary: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                StatTile(value: "\(filtered.eligible.count)", title: "符合条件",
                         color: .green, icon: "checkmark.seal.fill")
                StatTile(value: "\(filtered.close.count)", title: "差一点",
                         color: .orange, icon: "clock.badge.checkmark")
                StatTile(value: "\(filtered.stretch.count)", title: "长期准备",
                         color: .purple, icon: "calendar.badge.clock")
                StatTile(value: "\(filtered.blocked.count)", title: "走不通",
                         color: .gray, icon: "nosign")
            }

            if filtered.eligible.isEmpty && filtered.close.isEmpty {
                InfoBanner(icon: "exclamationmark.triangle",
                           text: "没有直接可行的路径。看一下下边的「优先补哪一项」，通常补上一两项就能打开不少门。")
            }

            if !model.bottlenecks.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Label("优先补哪一项最划算", systemImage: "lightbulb.max")
                        .font(.subheadline.weight(.semibold))
                    ForEach(Array(model.bottlenecks.enumerated()), id: \.element.id) { idx, b in
                        HStack(alignment: .top, spacing: 10) {
                            Text("\(idx + 1)")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white)
                                .frame(width: 18, height: 18)
                                .background(Color.accentColor, in: Circle())
                            VStack(alignment: .leading, spacing: 2) {
                                Text(b.text).font(.footnote.weight(.medium))
                                Text("挡住 \(b.count) 条路径 · 平均需 \(Fmt.months(b.months))")
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
}

private struct StatTile: View {
    let value: String
    let title: String
    let color: Color
    let icon: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 15, weight: .semibold)).foregroundStyle(color)
            Text(value).font(.title2.weight(.bold)).monospacedDigit().foregroundStyle(color)
            Text(title).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct InfoBanner: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon).foregroundStyle(.orange)
            Text(text).font(.footnote).fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct GroupHeader: View {
    let status: MatchStatus
    let count: Int

    var body: some View {
        HStack(spacing: 8) {
            Text(status.title).font(.footnote.weight(.semibold))
            Text("\(count)").font(.caption2.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 6).padding(.vertical, 1)
                .background(color, in: Capsule())
            Spacer()
            Text(status.hint).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(.bar)
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

// MARK: - 结果卡片

struct ResultCard: View {
    let result: MatchResult
    let rank: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                Text(result.path.flag).font(.system(size: 26))
                VStack(alignment: .leading, spacing: 2) {
                    Text(result.path.name).font(.headline).lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Text("\(result.path.country) · \(Lexicon.typeLabel(result.path.type))")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 4)
                VStack(spacing: 2) {
                    Text("\(result.score)").font(.subheadline.weight(.bold)).monospacedDigit()
                        .foregroundStyle(scoreColor)
                    Text("匹配度").font(.system(size: 9)).foregroundStyle(.tertiary)
                }
            }

            if result.status == .eligible {
                Label("门槛都过了", systemImage: "checkmark.circle.fill")
                    .font(.caption).foregroundStyle(.green)
            } else {
                ForEach(result.hardGaps.prefix(2)) { g in
                    Label(g.text, systemImage: "xmark.octagon.fill")
                        .font(.caption).foregroundStyle(.red)
                        .lineLimit(2)
                }
                ForEach(result.softGaps.prefix(3)) { g in
                    Label(g.text, systemImage: "exclamationmark.circle.fill")
                        .font(.caption).foregroundStyle(.orange)
                        .lineLimit(2)
                }
                if result.softGaps.count > 3 {
                    Text("另有 \(result.softGaps.count - 3) 项待补 →")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 6) {
                if let e = result.effort {
                    Tag(text: Fmt.months(e.months), icon: "hourglass")
                    Tag(text: "花费\(Fmt.costLabel[e.cost] ?? e.cost)", icon: "banknote")
                }
                if Engine.leadsToPR(result.path) {
                    Tag(text: "通往永居", icon: "house.badge.checkmark", tint: .green)
                }
                Tag(text: "难度 \(result.path.difficulty)/5", icon: "gauge.with.dots.needle.33percent")
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(alignment: .topLeading) {
            if rank == 1 {
                Text("最推荐")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(Color.accentColor, in: Capsule())
                    .offset(x: 10, y: -7)
            }
        }
    }

    private var scoreColor: Color {
        switch result.status {
        case .eligible: return .green
        case .close: return .orange
        case .stretch: return .purple
        case .blocked: return .gray
        }
    }
}

struct Tag: View {
    let text: String
    var icon: String? = nil
    var tint: Color = .secondary

    var body: some View {
        HStack(spacing: 3) {
            if let icon { Image(systemName: icon).font(.system(size: 8, weight: .semibold)) }
            Text(text)
        }
        .font(.caption2)
        .foregroundStyle(tint)
        .padding(.horizontal, 7).padding(.vertical, 3)
        .background((tint == .secondary ? Color(.tertiarySystemFill) : tint.opacity(0.12)),
                    in: Capsule())
    }
}

// MARK: - 筛选

struct FilterSheet: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle("只看发达经济体", isOn: $model.filters.onlyDeveloped)
                        .tint(.blue)
                } footer: {
                    Text("按 IMF「先进经济体」口径")
                }

                Section("地区") {
                    FlowListOptions(options: Lexicon.regionOrder.map { ($0, Lexicon.regionLabels[$0] ?? $0) },
                                    selection: $model.filters.regions)
                }

                Section("国家 / 地区") {
                    NavigationLink {
                        CountryPicker(selection: $model.filters.countries)
                    } label: {
                        HStack {
                            Text("已选")
                            Spacer()
                            Text(model.filters.countries.isEmpty ? "全部"
                                 : "\(model.filters.countries.count) 个")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section {
                    ForEach(Lexicon.excludes, id: \.key) { ex in
                        Toggle(isOn: Binding(
                            get: { model.filters.excludes.contains(ex.key) },
                            set: { on in
                                if on { model.filters.excludes.insert(ex.key) }
                                else { model.filters.excludes.remove(ex.key) }
                            })) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("我不想" + ex.label)
                                if !ex.hint.isEmpty {
                                    Text(ex.hint).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                        .tint(.blue)
                    }
                } header: {
                    Text("排除条件")
                } footer: {
                    Text("勾选后会直接从结果里筛掉对应路径，并说明隐藏了多少条")
                }
            }
            .navigationTitle("筛选")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("清空") {
                        model.filters = Filters()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}

private struct FlowListOptions: View {
    let options: [(String, String)]
    @Binding var selection: Set<String>

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(options, id: \.0) { opt in
                let on = selection.contains(opt.0)
                Button {
                    if on { selection.remove(opt.0) } else { selection.insert(opt.0) }
                } label: {
                    Text(opt.1)
                        .font(.footnote.weight(on ? .semibold : .regular))
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(on ? Color.accentColor.opacity(0.16) : Color(.tertiarySystemFill),
                                    in: Capsule())
                        .foregroundStyle(on ? Color.accentColor : Color.primary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct CountryPicker: View {
    @Binding var selection: Set<String>
    @State private var query = ""

    var body: some View {
        List {
            ForEach(groupedCountries, id: \.0) { region, countries in
                Section(Lexicon.regionLabels[region] ?? region) {
                    ForEach(countries, id: \.self) { c in
                        Button {
                            if selection.contains(c) { selection.remove(c) } else { selection.insert(c) }
                        } label: {
                            HStack {
                                Text(c).foregroundStyle(.primary)
                                Spacer()
                                if selection.contains(c) {
                                    Image(systemName: "checkmark").foregroundStyle(.accentColor)
                                }
                            }
                        }
                    }
                }
            }
        }
        .searchable(text: $query)
        .navigationTitle("国家 / 地区")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var groupedCountries: [(String, [String])] {
        let all = Store.countries.filter { query.isEmpty || $0.contains(query) }
        let dict = Dictionary(grouping: all) { Lexicon.regionOf[$0] ?? "other" }
        return Lexicon.regionOrder.compactMap { r in
            guard let list = dict[r], !list.isEmpty else { return nil }
            return (r, list)
        }
    }
}
