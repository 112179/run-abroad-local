import SwiftUI

// MARK: - 表单字段绑定（三种风格共用统一套组件）
//
// 关键：这里所有 Binding 都在 get/set 里读写 AppModel（@Published），
// 不把 model 直接嵌进视图 —— 否则 SwiftUI 观察不到变化，Stepper / 标签点了没反应。

@MainActor
struct ProfileFieldBindings {
    var model: AppModel

    var rankOptions: [(Int, String)] {
        [(50, "世界排名前 50"), (100, "前 100（QS100）"), (200, "前 200"),
         (500, "前 500"), (9999, "500 开外 / 双非")]
    }

    var studyLocOptions: [(String, String)] {
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

    var profile: Binding<Profile> {
        Binding(get: { self.model.profile }, set: { self.model.profile = $0 })
    }

    var profileValue: Profile { model.profile }

    // 逐字段绑定，setter 里整体赋值以触发 @Published
    var age: Binding<Int> {
        Binding(get: { self.model.profile.age },
                set: { v in var p = self.model.profile; p.age = v; self.model.profile = p })
    }
    var degree: Binding<Int> {
        Binding(get: { self.model.profile.degree },
                set: { v in var p = self.model.profile; p.degree = v; self.model.profile = p })
    }
    var uniRank: Binding<Int> {
        Binding(get: { self.model.profile.uniRank },
                set: { v in var p = self.model.profile; p.uniRank = v; self.model.profile = p })
    }
    var ugRank: Binding<Int> {
        Binding(get: { self.model.profile.ugRank },
                set: { v in var p = self.model.profile; p.ugRank = v; self.model.profile = p })
    }
    var studyLoc: Binding<String> {
        Binding(get: { self.model.profile.studyLoc },
                set: { v in var p = self.model.profile; p.studyLoc = v; self.model.profile = p })
    }
    var yearsSinceGrad: Binding<Int?> {
        Binding(get: { self.model.profile.yearsSinceGrad },
                set: { v in var p = self.model.profile; p.yearsSinceGrad = v; self.model.profile = p })
    }
    var english: Binding<Int> {
        Binding(get: { self.model.profile.english },
                set: { v in var p = self.model.profile; p.english = v; self.model.profile = p })
    }
    var french: Binding<Int> {
        Binding(get: { self.model.profile.french },
                set: { v in var p = self.model.profile; p.french = v; self.model.profile = p })
    }
    var langs: Binding<[String]> {
        Binding(get: { self.model.profile.langs },
                set: { v in var p = self.model.profile; p.langs = v; self.model.profile = p })
    }
    var workExp: Binding<Int> {
        Binding(get: { self.model.profile.workExp },
                set: { v in var p = self.model.profile; p.workExp = v; self.model.profile = p })
    }
    var funds: Binding<Int> {
        Binding(get: { self.model.profile.funds },
                set: { v in var p = self.model.profile; p.funds = v; self.model.profile = p })
    }
    var hasOffer: Binding<Bool> {
        Binding(get: { self.model.profile.hasOffer },
                set: { v in var p = self.model.profile; p.hasOffer = v; self.model.profile = p })
    }
    var skills: Binding<[String]> {
        Binding(get: { self.model.profile.skills },
                set: { v in var p = self.model.profile; p.skills = v; self.model.profile = p })
    }
    var goals: Binding<[String]> {
        Binding(get: { self.model.profile.goals },
                set: { v in var p = self.model.profile; p.goals = v; self.model.profile = p })
    }

    var incomeType: Binding<Int> {
        let map = ["none", "employee", "selfEmployed", "passive", "mixed"]
        return Binding(
            get: {
                guard let t = self.model.profile.incomeType,
                      let i = map.firstIndex(of: t) else { return 0 }
                return i
            },
            set: { i in
                var p = self.model.profile
                p.incomeType = map[min(max(i, 0), map.count - 1)]
                if !["employee", "selfEmployed", "mixed"].contains(p.incomeType ?? "") {
                    p.remoteAbroad = nil
                    p.activeIncome = nil
                    p.primaryIncomeCountry = nil
                }
                if !["passive", "mixed"].contains(p.incomeType ?? "") { p.passiveIncome = nil }
                self.model.profile = p
            })
    }

    var remoteAbroad: Binding<Int> {
        let map = ["no", "uncertain", "yes"]
        return Binding(
            get: {
                guard let r = self.model.profile.remoteAbroad,
                      let i = map.firstIndex(of: r) else { return 1 }
                return i
            },
            set: { i in
                var p = self.model.profile
                p.remoteAbroad = map[min(max(i, 0), map.count - 1)]
                if p.remoteAbroad != "yes" {
                    p.activeIncome = nil
                    p.primaryIncomeCountry = nil
                }
                self.model.profile = p
            })
    }

    var activeIncome: Binding<Int> {
        Binding(get: { self.model.profile.activeIncome ?? 0 },
                set: { v in var p = self.model.profile; p.activeIncome = v; self.model.profile = p })
    }

    var passiveIncome: Binding<Int> {
        Binding(get: { self.model.profile.passiveIncome ?? 0 },
                set: { v in var p = self.model.profile; p.passiveIncome = v; self.model.profile = p })
    }

    var incomeSource: Binding<Int> {
        let list = Store.orderedIncomeSources
        return Binding(
            get: {
                guard let c = self.model.profile.primaryIncomeCountry,
                      let i = list.firstIndex(of: c) else { return 0 }
                return i
            },
            set: { i in
                var p = self.model.profile
                p.primaryIncomeCountry = i < list.count ? list[i] : nil
                self.model.profile = p
            })
    }
}

// MARK: - 可复用的字段块

struct BasicFields: View {
    @ObservedObject var model: AppModel

    var body: some View {
        let b = ProfileFieldBindings(model: model)
        Group {
            AgeRow(value: b.age)
            Divider()
            PickerRow(title: "最高学历", selection: b.degree,
                      options: Lexicon.degreeLabels.enumerated().map { ($0.offset, $0.element) })
            if model.profile.degree > 3 {
                Divider()
                PickerRow(title: "本科院校", selection: b.ugRank, options: b.rankOptions)
            }
            Divider()
            PickerRow(title: "毕业院校", selection: b.uniRank, options: b.rankOptions)
            Divider()
            StringPickerRow(title: "学位取得地", selection: b.studyLoc, options: b.studyLocOptions)
            Divider()
            GraduationRow(value: b.yearsSinceGrad)
        }
    }
}

struct LanguageFields: View {
    @ObservedObject var model: AppModel

    var body: some View {
        let b = ProfileFieldBindings(model: model)
        Group {
            PickerRow(title: "英语", selection: b.english,
                      options: Lexicon.engLabels.enumerated().map { ($0.offset, $0.element) })
            Divider()
            PickerRow(title: "法语", selection: b.french,
                      options: Lexicon.fraLabels.enumerated().map { ($0.offset, $0.element) })
            Divider()
            ChipRow(title: "其他语言", options: Lexicon.langOptions,
                    selection: b.langs, exclusive: "none")
        }
    }
}

struct ExperienceFields: View {
    @ObservedObject var model: AppModel

    var body: some View {
        let b = ProfileFieldBindings(model: model)
        Group {
            PickerRow(title: "工作经验", selection: b.workExp,
                      options: [(0, "应届 / 无全职经验"), (1, "1–2 年"), (3, "3–5 年"),
                                (5, "5–10 年"), (10, "10 年以上")])
            Divider()
            PickerRow(title: "可用资金", selection: b.funds,
                      options: [(1000, "1 万人民币以内"), (3000, "2 万人民币左右"),
                                (10000, "7 万人民币左右"), (30000, "20 万人民币左右"),
                                (100000, "70 万人民币左右"), (500000, "350 万人民币左右"),
                                (1000000, "700 万人民币以上")])
            Divider()
            Toggle(isOn: b.hasOffer) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("已有海外 offer / 合同")
                    Text("当地雇主的工作、培训或季节工合同")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .tint(.blue)
        }
    }
}

struct IncomeFields: View {
    @ObservedObject var model: AppModel

    var body: some View {
        let b = ProfileFieldBindings(model: model)
        Group {
            PickerRow(title: "收入类型", selection: b.incomeType,
                      options: [(0, "暂无稳定收入"), (1, "受雇工资"),
                                (2, "自由职业 / 自营"), (3, "被动收入"), (4, "多种收入")])
            if model.profile.hasActiveIncome {
                Divider()
                PickerRow(title: "能否长期境外远程", selection: b.remoteAbroad,
                          options: [(0, "不能"), (1, "不确定"), (2, "可以")])
                if model.profile.remoteAbroad == "yes" {
                    Divider()
                    PickerRow(title: "远程月收入", selection: b.activeIncome,
                              options: Lexicon.incomeBands.map { ($0.v, $0.t) })
                    Divider()
                    PickerRow(title: "主要收入来源地", selection: b.incomeSource,
                              options: Store.orderedIncomeSources.enumerated()
                                .map { ($0.offset, $0.element) })
                }
            }
            if model.profile.hasPassiveIncome {
                Divider()
                PickerRow(title: "被动收入", selection: b.passiveIncome,
                          options: Lexicon.incomeBands.map { ($0.v, $0.t) })
            }
        }
    }
}

struct SkillFields: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ChipRow(title: nil, options: Lexicon.skillOptions,
                selection: ProfileFieldBindings(model: model).skills, exclusive: "none")
    }
}

struct GoalFields: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ChipRow(title: nil, options: Lexicon.goalOptions,
                selection: ProfileFieldBindings(model: model).goals, exclusive: nil)
    }
}
