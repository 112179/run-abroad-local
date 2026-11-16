import SwiftUI

// 表单字段绑定（三种风格共用）

// MARK: - 表单字段集合（三种风格共用同一套组件与绑定）

@MainActor
struct ProfileFieldBindings {
    var model: AppModel?

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
        Binding(get: { model?.profile ?? Profile() },
                set: { if let m = model { m.profile = $0 } })
    }

    var age: Binding<Int> { profile.age }
    var degree: Binding<Int> { profile.degree }
    var uniRank: Binding<Int> { profile.uniRank }
    var ugRank: Binding<Int> { profile.ugRank }
    var studyLoc: Binding<String> { profile.studyLoc }
    var english: Binding<Int> { profile.english }
    var french: Binding<Int> { profile.french }
    var langs: Binding<[String]> { profile.langs }
    var workExp: Binding<Int> { profile.workExp }
    var funds: Binding<Int> { profile.funds }
    var hasOffer: Binding<Bool> { profile.hasOffer }
    var skills: Binding<[String]> { profile.skills }
    var goals: Binding<[String]> { profile.goals }

    var incomeType: Binding<Int> {
        let map = ["none", "employee", "selfEmployed", "passive", "mixed"]
        return Binding(
            get: {
                guard let t = profile.wrappedValue.incomeType,
                      let i = map.firstIndex(of: t) else { return 0 }
                return i
            },
            set: { i in
                var p = profile.wrappedValue
                p.incomeType = map[i]
                if !["employee", "selfEmployed", "mixed"].contains(map[i]) {
                    p.remoteAbroad = nil
                    p.activeIncome = nil
                    p.primaryIncomeCountry = nil
                }
                if !["passive", "mixed"].contains(map[i]) { p.passiveIncome = nil }
                profile.wrappedValue = p
            })
    }

    var remoteAbroad: Binding<Int> {
        let map = ["no", "uncertain", "yes"]
        return Binding(
            get: {
                guard let r = profile.wrappedValue.remoteAbroad,
                      let i = map.firstIndex(of: r) else { return 1 }
                return i
            },
            set: { i in
                var p = profile.wrappedValue
                p.remoteAbroad = map[i]
                if map[i] != "yes" {
                    p.activeIncome = nil
                    p.primaryIncomeCountry = nil
                }
                profile.wrappedValue = p
            })
    }

    var activeIncome: Binding<Int> {
        Binding(get: { profile.wrappedValue.activeIncome ?? 0 },
                set: { v in var p = profile.wrappedValue; p.activeIncome = v; profile.wrappedValue = p })
    }

    var passiveIncome: Binding<Int> {
        Binding(get: { profile.wrappedValue.passiveIncome ?? 0 },
                set: { v in var p = profile.wrappedValue; p.passiveIncome = v; profile.wrappedValue = p })
    }

    var incomeSource: Binding<Int> {
        let list = Store.orderedIncomeSources
        return Binding(
            get: {
                guard let c = profile.wrappedValue.primaryIncomeCountry,
                      let i = list.firstIndex(of: c) else { return 0 }
                return i
            },
            set: { i in
                var p = profile.wrappedValue
                p.primaryIncomeCountry = i < list.count ? list[i] : nil
                profile.wrappedValue = p
            })
    }
}

// MARK: - 可复用的字段块

/// 基本情况
struct BasicFields: View {
    let b: ProfileFieldBindings

    var body: some View {
        Group {
            AgeRow(profile: b.profile)
            Divider()
            PickerRow(title: "最高学历", selection: b.degree,
                      options: Lexicon.degreeLabels.enumerated().map { ($0.offset, $0.element) })
            if b.profileValue.degree > 3 {
                Divider()
                PickerRow(title: "本科院校", selection: b.ugRank, options: b.rankOptions)
            }
            Divider()
            PickerRow(title: "毕业院校", selection: b.uniRank, options: b.rankOptions)
            Divider()
            StringPickerRow(title: "学位取得地", selection: b.studyLoc, options: b.studyLocOptions)
            Divider()
            GraduationRow(profile: b.profile)
        }
    }
}

struct LanguageFields: View {
    let b: ProfileFieldBindings

    var body: some View {
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
    let b: ProfileFieldBindings

    var body: some View {
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
    let b: ProfileFieldBindings

    var body: some View {
        Group {
            PickerRow(title: "收入类型", selection: b.incomeType,
                      options: [(0, "暂无稳定收入"), (1, "受雇工资"),
                                (2, "自由职业 / 自营"), (3, "被动收入"), (4, "多种收入")])
            if b.profileValue.hasActiveIncome {
                Divider()
                PickerRow(title: "能否长期境外远程", selection: b.remoteAbroad,
                          options: [(0, "不能"), (1, "不确定"), (2, "可以")])
                if b.profileValue.remoteAbroad == "yes" {
                    Divider()
                    PickerRow(title: "远程月收入", selection: b.activeIncome,
                              options: Lexicon.incomeBands.map { ($0.v, $0.t) })
                    Divider()
                    PickerRow(title: "主要收入来源地", selection: b.incomeSource,
                              options: Store.orderedIncomeSources.enumerated()
                                .map { ($0.offset, $0.element) })
                }
            }
            if b.profileValue.hasPassiveIncome {
                Divider()
                PickerRow(title: "被动收入", selection: b.passiveIncome,
                          options: Lexicon.incomeBands.map { ($0.v, $0.t) })
            }
        }
    }
}

struct SkillFields: View {
    let b: ProfileFieldBindings

    var body: some View {
        ChipRow(title: nil, options: Lexicon.skillOptions, selection: b.skills, exclusive: "none")
    }
}

struct GoalFields: View {
    let b: ProfileFieldBindings

    var body: some View {
        ChipRow(title: nil, options: Lexicon.goalOptions, selection: b.goals, exclusive: nil)
    }
}

// ProfileFieldBindings 需要能读 profile 本身
@MainActor
extension ProfileFieldBindings {
    var profileValue: Profile { model?.profile ?? Profile() }
}
