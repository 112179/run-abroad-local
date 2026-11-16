import SwiftUI

// MARK: - 表单页

struct FormView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showReset = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    hero

                    SectionCard(title: "基本情况", systemImage: "person.text.rectangle") {
                        AgeRow(profile: $model.profile)
                        Divider()
                        PickerRow(title: "最高学历",
                                  selection: $model.profile.degree,
                                  options: Lexicon.degreeLabels.enumerated().map { ($0.offset, $0.element) })
                        if model.profile.degree > 3 {
                            Divider()
                            PickerRow(title: "本科院校",
                                      selection: $model.profile.ugRank,
                                      options: rankOptions)
                        }
                        Divider()
                        PickerRow(title: "毕业院校",
                                  selection: $model.profile.uniRank,
                                  options: rankOptions)
                        Divider()
                        PickerRow(title: "学位取得地",
                                  selection: $model.profile.studyLoc,
                                  options: studyLocOptions)
                        Divider()
                        GraduationRow(profile: $model.profile)
                    }

                    SectionCard(title: "语言", systemImage: "character.bubble") {
                        PickerRow(title: "英语", selection: $model.profile.english,
                                  options: Lexicon.engLabels.enumerated().map { ($0.offset, $0.element) })
                        Divider()
                        PickerRow(title: "法语", selection: $model.profile.french,
                                  options: Lexicon.fraLabels.enumerated().map { ($0.offset, $0.element) })
                        Divider()
                        ChipRow(title: "其他语言",
                                options: Lexicon.langOptions,
                                selection: $model.profile.langs,
                                exclusive: "none")
                    }

                    SectionCard(title: "经验与资金", systemImage: "briefcase") {
                        PickerRow(title: "工作经验", selection: $model.profile.workExp,
                                  options: [(0, "应届 / 无全职经验"), (1, "1–2 年"), (3, "3–5 年"),
                                            (5, "5–10 年"), (10, "10 年以上")])
                        Divider()
                        PickerRow(title: "可用资金", selection: $model.profile.funds,
                                  options: [(1000, "1 万人民币以内"), (3000, "2 万人民币左右"),
                                            (10000, "7 万人民币左右"), (30000, "20 万人民币左右"),
                                            (100000, "70 万人民币左右"), (500000, "350 万人民币左右"),
                                            (1000000, "700 万人民币以上")])
                        Divider()
                        Toggle(isOn: $model.profile.hasOffer) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("已有海外 offer / 合同")
                                Text("当地雇主的工作、培训或季节工合同")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .tint(.blue)
                    }

                    SectionCard(title: "收入情况", systemImage: "banknote",
                                note: "只用于判断数字游民 / 被动收入类路径") {
                        PickerRow(title: "收入类型", selection: incomeTypeBinding,
                                  options: [(0, "暂无稳定收入"), (1, "受雇工资"),
                                            (2, "自由职业 / 自营"), (3, "被动收入"), (4, "多种收入")])
                        if model.profile.hasActiveIncome {
                            Divider()
                            PickerRow(title: "能否长期境外远程", selection: remoteBinding,
                                      options: [(0, "不能"), (1, "不确定"), (2, "可以")])
                            if model.profile.remoteAbroad == "yes" {
                                Divider()
                                PickerRow(title: "远程月收入", selection: activeIncomeBinding,
                                          options: Lexicon.incomeBands.map { ($0.v, $0.t) })
                                Divider()
                                PickerRow(title: "主要收入来源地", selection: incomeSourceBinding,
                                          options: Store.orderedIncomeSources.enumerated()
                                            .map { ($0.offset, $0.element) })
                            }
                        }
                        if model.profile.hasPassiveIncome {
                            Divider()
                            PickerRow(title: "被动收入", selection: passiveIncomeBinding,
                                      options: Lexicon.incomeBands.map { ($0.v, $0.t) })
                        }
                    }

                    SectionCard(title: "技能方向", systemImage: "hammer",
                                note: "可不选；选了会优先推荐对口路径") {
                        ChipRow(title: nil, options: Lexicon.skillOptions,
                                selection: $model.profile.skills, exclusive: "none")
                    }

                    SectionCard(title: "你的目标", systemImage: "target") {
                        ChipRow(title: nil, options: Lexicon.goalOptions,
                                selection: $model.profile.goals, exclusive: nil)
                    }

                    Button {
                        model.page = .results
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    } label: {
                        HStack {
                            Image(systemName: "sparkle.magnifyingglass")
                            Text("看看我能走哪些路径")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(colors: [.accentColor, .accentColor.opacity(0.78)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing),
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .foregroundStyle(.white)
                        .shadow(color: .accentColor.opacity(0.3), radius: 12, y: 6)
                    }
                    .buttonStyle(.plain)

                    Text("数据更新 \(Lexicon.updated) · 共 \(Store.pathways.count) 条路径 · 全部离线运行\n初筛工具，不是法律意见，任何决定前请以官网为准")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 24)
                }
                .padding(.horizontal, 16)
            }
            .background(Color(.systemGroupedBackground))
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("润学导航")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("重置所有信息", systemImage: "arrow.counterclockwise", role: .destructive) {
                            showReset = true
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .confirmationDialog("清空已填信息？", isPresented: $showReset, titleVisibility: .visible) {
                Button("重置", role: .destructive) { model.resetProfile() }
            }
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("填几项基本信息")
                .font(.largeTitle.bold())
            Text("从 \(Store.pathways.count) 条签证 / 移民路径里筛出适合你的，并告诉你还差什么。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }

    private var rankOptions: [(Int, String)] {
        [(50, "世界排名前 50"), (100, "前 100（QS100）"), (200, "前 200"),
         (500, "前 500"), (9999, "500 开外 / 双非")]
    }

    private var studyLocOptions: [(String, String)] {
        let order = ["cn", "hk", "jp", "kr", "sg", "au", "nz", "uk", "ie", "us", "ca",
                     "de", "fr", "nl", "it", "es", "pt", "se", "no", "dk", "fi", "be", "at", "ch", "pl",
                     "eu", "other"]
        var opts = order.compactMap { key -> (String, String)? in
            guard let label = Lexicon.studyLoc[key] else { return nil }
            return (key, label)
        }
        for (k, v) in Lexicon.studyLoc.sorted(by: { $0.key < $1.key }) where !order.contains(k) {
            opts.append((k, v))
        }
        return opts
    }

    // 可选值 0–4 与上游 incomeType 字符串互转
    private var incomeTypeBinding: Binding<Int> {
        let map = ["none", "employee", "selfEmployed", "passive", "mixed"]
        return Binding(
            get: {
                guard let t = model.profile.incomeType, let i = map.firstIndex(of: t) else { return 0 }
                return i
            },
            set: { i in
                model.profile.incomeType = map[i]
                if !["employee", "selfEmployed", "mixed"].contains(map[i]) {
                    model.profile.remoteAbroad = nil
                    model.profile.activeIncome = nil
                    model.profile.primaryIncomeCountry = nil
                }
                if !["passive", "mixed"].contains(map[i]) { model.profile.passiveIncome = nil }
            })
    }

    private var remoteBinding: Binding<Int> {
        let map = ["no", "uncertain", "yes"]
        return Binding(
            get: {
                guard let r = model.profile.remoteAbroad, let i = map.firstIndex(of: r) else { return 1 }
                return i
            },
            set: { i in
                model.profile.remoteAbroad = map[i]
                if map[i] != "yes" {
                    model.profile.activeIncome = nil
                    model.profile.primaryIncomeCountry = nil
                }
            })
    }

    private var activeIncomeBinding: Binding<Int> {
        Binding(
            get: { model.profile.activeIncome ?? 0 },
            set: { model.profile.activeIncome = $0 })
    }

    private var passiveIncomeBinding: Binding<Int> {
        Binding(
            get: { model.profile.passiveIncome ?? 0 },
            set: { model.profile.passiveIncome = $0 })
    }

    private var incomeSourceBinding: Binding<Int> {
        let list = Store.orderedIncomeSources
        return Binding(
            get: {
                guard let c = model.profile.primaryIncomeCountry,
                      let i = list.firstIndex(of: c) else { return 0 }
                return i
            },
            set: { model.profile.primaryIncomeCountry = list[$0] })
    }
}
