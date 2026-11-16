import Foundation

/// 匹配引擎 —— 对应上游 js/engine.js，判定逻辑与文案保持一致。
/// 原则：不做「能 / 不能」的二元判断，而是告诉用户「差什么、补上要多久」。
enum Engine {

    // MARK: - 缺口准备成本

    static let gapEffort: [String: Effort] = [
        "english": Effort(months: [2, 12], cost: "low", uncertain: false),
        "french": Effort(months: [6, 18], cost: "mid", uncertain: false),
        "otherLang": Effort(months: [6, 24], cost: "mid", uncertain: false),
        "workExp": Effort(months: [12, 12], cost: "none", uncertain: false), // 按缺失年数线性放大
        "funds": Effort(months: [3, 24], cost: "mid", uncertain: false),
        "income": Effort(months: [3, 12], cost: "none", uncertain: false),
        "jobOffer": Effort(months: [3, 12], cost: "none", uncertain: true),
        "skills": Effort(months: [12, 36], cost: "mid", uncertain: false),
        "degree": Effort(months: [12, 24], cost: "high", uncertain: false),
        "studyIn": Effort(months: [12, 24], cost: "high", uncertain: false),
        "gradWithin": Effort(months: [0, 1], cost: "none", uncertain: true),
    ]

    static let costRank = ["none": 0, "low": 1, "mid": 2, "high": 3]

    static func effortOf(_ field: String, profile: Profile, path: Pathway) -> Effort {
        var base = gapEffort[field] ?? Effort(months: [0, 0], cost: "none", uncertain: true)
        if field == "workExp" {
            let missing = max(0, (path.req.workExp ?? 0) - profile.workExp)
            let m = 12 * missing
            base.months = [m, m]
        }
        return base
    }

    static func summarize(_ softGaps: [Gap]) -> Effort? {
        guard !softGaps.isEmpty else { return nil }
        let efforts = softGaps.compactMap { $0.effort }
        let lo = efforts.map { $0.months[0] }.max() ?? 0
        let hi = efforts.map { $0.months[1] }.max() ?? 0
        let cost = efforts.reduce("none") { top, e in
            (costRank[e.cost] ?? 0) > (costRank[top] ?? 0) ? e.cost : top
        }
        return Effort(months: [lo, hi], cost: cost, uncertain: efforts.contains { $0.uncertain })
    }

    // MARK: - 收入

    static let activeIncomeTypes: Set<String> = ["employee", "selfEmployed", "mixed"]

    enum BandResult { case met, below, ambiguous, unknown }

    static func compareBand(_ value: Int?, threshold: Int) -> BandResult {
        guard let value else { return .unknown }
        guard let band = Lexicon.incomeBands.first(where: { $0.v == value }) else {
            return value >= threshold ? .met : .below
        }
        if band.min >= threshold { return .met }
        if let max = band.max, max < threshold { return .below }
        return .ambiguous
    }

    static func checkIncome(_ profile: Profile, _ path: Pathway, _ income: Pathway.Income) -> Gap? {
        let activeType = activeIncomeTypes.contains(profile.incomeType ?? "")
        let passiveType = ["passive", "mixed"].contains(profile.incomeType ?? "")
        let sourceKnown = profile.primaryIncomeCountry != nil
        let sourceListed = income.sourceIn == nil ||
            (sourceKnown && (income.sourceIn!.contains(profile.primaryIncomeCountry!)))
        let sourceOk = sourceListed && ((income.foreignSource != true) ||
            (sourceKnown && profile.primaryIncomeCountry != path.country))
        let activeAmount = compareBand(profile.activeIncome, threshold: income.minMonthlyUSD)
        let passiveAmount = compareBand(profile.passiveIncome, threshold: income.minMonthlyUSD)

        let remoteOk = activeType && profile.remoteAbroad == "yes" && activeAmount == .met && sourceOk
        let passiveOk = passiveType && passiveAmount == .met

        switch income.mode {
        case "remote" where remoteOk: return nil
        case "passive" where passiveOk: return nil
        case "either" where remoteOk || passiveOk: return nil
        default: break
        }

        let incomeTypeUnknown = profile.incomeType == nil
        let remoteUnknown = incomeTypeUnknown || (activeType && (
            profile.remoteAbroad == nil || profile.remoteAbroad == "uncertain" ||
            (profile.remoteAbroad == "yes" && (
                activeAmount == .unknown ||
                ((income.foreignSource == true || income.sourceIn != nil) && !sourceKnown)))))
        let passiveUnknown = incomeTypeUnknown || (passiveType && passiveAmount == .unknown)
        let unknown: Bool
        switch income.mode {
        case "remote": unknown = remoteUnknown
        case "passive": unknown = passiveUnknown
        default: unknown = remoteUnknown || passiveUnknown
        }

        let checksRemote = income.mode == "remote" || income.mode == "either"
        let checksPassive = income.mode == "passive" || income.mode == "either"
        let threshold = "$\(income.minMonthlyUSD.formatted())/月"
        func withShortfall(_ m: String) -> String {
            guard let hint = income.shortfallHint, !hint.isEmpty else { return m }
            return "\(m)；\(hint)"
        }

        var text: String
        if checksRemote && activeType && profile.remoteAbroad == "no" {
            text = "当前工作不能长期在境外远程进行"
        } else if checksRemote && activeType && profile.remoteAbroad == "uncertain" {
            text = "需先确认当前工作是否允许长期在境外远程进行"
        } else if checksRemote && activeType && profile.remoteAbroad == "yes" && sourceKnown && !sourceListed {
            text = income.sourceHint ?? "主要收入来源地不在该路径认可的国家 / 地区范围内"
        } else if checksRemote && activeType && profile.remoteAbroad == "yes" && activeAmount == .below {
            text = withShortfall("当前远程收入低于该路径约 \(threshold)的要求")
        } else if checksRemote && activeType && profile.remoteAbroad == "yes" && activeAmount == .ambiguous {
            text = "当前远程收入档位无法确认是否达到该路径约 \(threshold)的要求"
        } else if checksRemote && activeType && profile.remoteAbroad == "yes" &&
                    income.foreignSource == true && sourceKnown && profile.primaryIncomeCountry == path.country {
            text = "主要收入来自目标国家/地区，不符合该路径以境外收入为主的要求"
        } else if checksPassive && passiveType && profile.passiveIncome != nil && passiveAmount == .below {
            text = withShortfall("当前稳定被动收入低于该路径约 \(threshold)的要求")
        } else if checksPassive && passiveType && passiveAmount == .ambiguous {
            text = "当前稳定被动收入档位无法确认是否达到该路径约 \(threshold)的要求"
        } else if unknown {
            text = "需补充持续收入信息，确认这条路径的收入条件"
        } else if income.mode == "remote" {
            text = "需要可长期在境外完成的远程工作，并有每月约 $\(income.minMonthlyUSD.formatted()) 的持续主动收入" +
                ((income.foreignSource == true) ? "（主要来自居住国以外）" : "")
        } else if income.mode == "passive" {
            text = "需要每月约 $\(income.minMonthlyUSD.formatted()) 的持续被动收入"
        } else {
            text = "需要每月约 $\(income.minMonthlyUSD.formatted()) 的持续远程或被动收入"
        }
        return Gap(kind: .soft, field: "income", text: text)
    }

    // MARK: - 单条路径判定

    static func check(_ profile: Profile, _ path: Pathway) -> MatchResult {
        let req = path.req
        var gaps: [Gap] = []

        if let age = req.age, age.count == 2 {
            let (lo, hi) = (age[0], age[1])
            if profile.age < lo {
                gaps.append(Gap(kind: .hard, field: "age", text: "年龄需满 \(lo) 岁"))
            } else if profile.age > hi {
                gaps.append(Gap(kind: .hard, field: "age",
                                text: "超龄 \(profile.age - hi) 岁（上限 \(hi) 岁）"))
            }
        }

        let currentStudent = profile.yearsSinceGrad == nil && profile.degree >= 1
        if let minDeg = req.minDeg, profile.degree < minDeg,
           !(req.allowCurrentStudent == true && currentStudent),
           !(req.degOrWorkExp != nil && profile.workExp >= req.degOrWorkExp!) {
            gaps.append(Gap(kind: .soft, field: "degree",
                            text: "需要\(Lexicon.degreeLabels[min(minDeg, 5)])及以上学历，你目前是\(Lexicon.degreeLabels[min(profile.degree, 5)])"))
        }

        if let uniRank = req.uniRank, profile.uniRank > uniRank {
            gaps.append(Gap(kind: .hard, field: "uniRank",
                            text: "要求世界排名前 \(uniRank) 的院校，你的院校档位不满足"))
        }

        if let ugRank = req.ugRank, profile.effectiveUGRank > ugRank {
            gaps.append(Gap(kind: .hard, field: "ugRank",
                            text: "要求本科院校为世界排名前 \(ugRank)（QS\(ugRank)），硕博院校不算，你的本科院校档位不满足"))
        }

        if let within = req.gradWithin {
            if profile.yearsSinceGrad == nil {
                gaps.append(Gap(kind: .soft, field: "gradWithin", text: "需在毕业 \(within) 年内申请"))
            } else if profile.yearsSinceGrad! > within {
                gaps.append(Gap(kind: .hard, field: "gradWithin",
                                text: "毕业已满 \(profile.yearsSinceGrad!) 年，超过 \(within) 年窗口期"))
            }
        }

        if let minEng = req.minEng, profile.english < minEng {
            gaps.append(Gap(kind: .soft, field: "english",
                            text: "语言需达到「\(Lexicon.engLabels[min(minEng, 4)])」，你当前是「\(Lexicon.engLabels[min(profile.english, 4)])」"))
        }

        if let minFra = req.minFrench, profile.french < minFra {
            gaps.append(Gap(kind: .soft, field: "french",
                            text: "法语需达到「\(Lexicon.fraLabels[min(minFra, 3)])」，你当前是「\(Lexicon.fraLabels[min(profile.french, 3)])」"))
        }

        if let other = req.otherLang, !profile.langs.contains(other.code) {
            gaps.append(Gap(kind: .soft, field: "otherLang", text: "需要\(other.label)水平"))
        }

        if let workExp = req.workExp, profile.workExp < workExp {
            gaps.append(Gap(kind: .soft, field: "workExp",
                            text: "需要 \(workExp) 年以上工作经验，你有 \(profile.workExp) 年"))
        }

        if let funds = req.fundsUSD, profile.funds < funds {
            gaps.append(Gap(kind: .soft, field: "funds",
                            text: "需准备约 $\(funds.formatted()) 资金证明，超出你的预算区间"))
        }

        if let income = req.income, let gap = checkIncome(profile, path, income) {
            gaps.append(gap)
        }

        if let any = req.studyInAny, !any.isEmpty {
            if !any.contains(profile.studyLoc) {
                let locations = any.map { Lexicon.studyLoc[$0] ?? $0 }.joined(separator: " / ")
                gaps.append(Gap(kind: .soft, field: "studyIn",
                                text: "需在以下地区之一的院校就读或毕业：\(locations)"))
            }
        } else if let studyIn = req.studyIn, profile.studyLoc != studyIn {
            gaps.append(Gap(kind: .soft, field: "studyIn",
                            text: "学位需在\(Lexicon.studyLoc[studyIn] ?? studyIn)的院校取得（可先去读书再申请）"))
        }

        if req.jobOffer == true && !profile.hasOffer {
            gaps.append(Gap(kind: .soft, field: "jobOffer", text: "需要先拿到当地的工作 / 培训合同"))
        }

        var skillMatch = false
        if let skills = req.skills, !skills.isEmpty, !profile.skills.isEmpty {
            skillMatch = skills.contains { profile.skills.contains($0) }
            if !skillMatch {
                let names = skills.map { Lexicon.skillNames[$0] ?? $0 }.joined(separator: " / ")
                gaps.append(Gap(kind: .soft, field: "skills", text: "这条路主要面向：\(names)"))
            }
        }

        let hardGaps = gaps.filter { $0.kind == .hard }
        var softGaps = gaps.filter { $0.kind == .soft }
        for i in softGaps.indices {
            softGaps[i].effort = effortOf(softGaps[i].field, profile: profile, path: path)
        }

        let status: MatchStatus
        if gaps.isEmpty { status = .eligible }
        else if !hardGaps.isEmpty { status = .blocked }
        else if softGaps.count <= 2 { status = .close }
        else { status = .stretch }

        return MatchResult(path: path, status: status, hardGaps: hardGaps, softGaps: softGaps,
                           skillMatch: skillMatch, effort: summarize(softGaps),
                           score: score(profile, path, status, softGaps, skillMatch))
    }

    // MARK: - 是否通往永居

    static func leadsToPR(_ path: Pathway) -> Bool {
        let pr = path.pr ?? ""
        // 先排除否定表述：「不通往永居」里同样含「永居」二字
        let negatives = ["不通往", "不直接通往", "不计入", "不挂钩", "属于短期", "未明确", "需单独核实", "规则以"]
        if negatives.contains(where: { pr.contains($0) }) { return false }
        let positives = ["永居", "永住", "绿卡", "永久居民", "永久居留", "长居", "长期居留",
                         "国民居留卡", "PR", "入籍", "国籍"]
        if pr.hasPrefix("是") { return true }
        return positives.contains(where: { pr.contains($0) })
    }

    // MARK: - 打分（只用于组内排序，不代表成功率）

    static func score(_ profile: Profile, _ path: Pathway, _ status: MatchStatus,
                      _ softGaps: [Gap], _ skillMatch: Bool) -> Int {
        var s: Double
        switch status {
        case .eligible: s = 70
        case .close: s = 50
        case .stretch: s = 30
        case .blocked: return 0
        }

        for g in softGaps {
            guard let e = g.effort else { continue }
            let mid = Double(e.months[0] + e.months[1]) / 2.0
            s -= max(2, min(8, (3 + mid / 6).rounded()))
        }
        if skillMatch { s += 10 }

        let goals = profile.goals
        if goals.contains("pr") { s += leadsToPR(path) ? 14 : -12 }
        if goals.contains("fast") && ["workholiday", "jobseek", "nomad"].contains(path.type) { s += 12 }
        if goals.contains("fast") && path.type == "skilled" { s -= 6 }
        if path.type == "soft" {
            s -= 20
            if goals.contains("fast") { s += 10 }
            if goals.contains("cheap") { s += 6 }
        }
        if goals.contains("cheap") {
            let need = path.req.fundsUSD ?? 0
            if need <= 5000 { s += 10 }
            if need >= 100000 { s -= 15 }
            if path.difficulty >= 4 { s -= 4 }
        }
        if goals.contains("study") && path.type == "study" { s += 12 }
        let incomeMode = path.req.income?.mode
        let remoteRelevant = incomeMode != nil
            ? ["remote", "either"].contains(incomeMode!)
            : path.type == "nomad"
        if goals.contains("remote") && remoteRelevant { s += 16 }
        if goals.contains("business") && path.type == "invest" { s += 14 }
        if goals.contains("family") && ["workholiday", "soft"].contains(path.type) { s -= 8 }
        s -= Double(path.difficulty - 3) * 3

        return max(1, min(99, Int(s.rounded())))
    }

    // MARK: - 主入口

    static func matchAll(_ profile: Profile, pathways: [Pathway]) -> MatchBucket {
        var bucket = MatchBucket()
        for p in pathways {
            let r = check(profile, p)
            bucket[r.status].append(r)
        }
        for status in MatchStatus.allCases {
            bucket[status].sort {
                $0.score != $1.score ? $0.score > $1.score
                    : $0.path.difficulty < $1.path.difficulty
            }
        }
        return bucket
    }

    /// 哪个软缺口挡住了最多路径 —— 「优先补哪一项」往往比列签证更有用。
    static func bottlenecks(_ bucket: MatchBucket) -> [Bottleneck] {
        var stat: [String: (count: Int, lo: Int, hi: Int)] = [:]
        for r in bucket.close + bucket.stretch {
            for g in r.softGaps {
                guard let e = g.effort else { continue }
                var s = stat[g.field] ?? (0, 0, 0)
                s.count += 1; s.lo += e.months[0]; s.hi += e.months[1]
                stat[g.field] = s
            }
        }
        let advice: [String: String] = [
            "english": "提高语言成绩（考出雅思 6.5 或同等）",
            "workExp": "积累工作经验",
            "degree": "提升学历（读一个硕士）",
            "funds": "攒够资金证明",
            "income": "确认并建立符合路径要求的持续收入",
            "jobOffer": "拿到一个海外雇主 offer",
            "skills": "转向紧缺职业方向",
            "gradWithin": "尽快在毕业窗口期内行动",
            "studyIn": "考虑先去目标国家读一个学位",
            "french": "学法语到 NCLC 7（加拿大法语通道分数线远低于常规轮次）",
            "otherLang": "学一门小语种（德语开职业教育，日语开日本本地路径）",
        ]
        return stat.map { field, s -> (Bottleneck, Double) in
            let months = [Int((Double(s.lo) / Double(s.count)).rounded()),
                          Int((Double(s.hi) / Double(s.count)).rounded())]
            let weight = Double(s.count) / (1 + Double(months[0] + months[1]) / 2 / 48)
            return (Bottleneck(field: field, count: s.count, months: months,
                               text: advice[field] ?? field), weight)
        }
        .sorted { $0.1 != $1.1 ? $0.1 > $1.1 : $0.0.count > $1.0.count }
        .prefix(3)
        .map { $0.0 }
    }
}

// MARK: - 结果筛选

struct Filters {
    var onlyDeveloped = false
    var regions: Set<String> = []
    var countries: Set<String> = []
    var excludes: Set<String> = []

    var isEmpty: Bool {
        !onlyDeveloped && regions.isEmpty && countries.isEmpty && excludes.isEmpty
    }

    func keeps(_ path: Pathway, _ profile: Profile) -> Bool {
        if onlyDeveloped && !Lexicon.developed.contains(path.country) { return false }
        if !regions.isEmpty && !regions.contains(Lexicon.regionOf[path.country] ?? "other") { return false }
        if !countries.isEmpty && !countries.contains(path.country) { return false }
        for key in excludes where excluded(key, path, profile) { return false }
        return true
    }

    func excluded(_ key: String, _ path: Pathway, _ profile: Profile) -> Bool {
        let req = path.req
        switch key {
        case "noStudy":
            if let any = req.studyInAny, !any.isEmpty { return !any.contains(profile.studyLoc) }
            if let studyIn = req.studyIn { return studyIn != profile.studyLoc }
            return ["study", "vocational"].contains(path.type)
        case "noMoney":
            return max(req.fundsUSD ?? 0, path.costUSD ?? 0) >= 20000
        case "noLang":
            let needEng = (req.minEng ?? 0) > profile.english
            let needFra = (req.minFrench ?? 0) > profile.french
            let needOther = req.otherLang.map { !profile.langs.contains($0.code) } ?? false
            return needEng || needFra || needOther
        case "noOffer":
            return req.jobOffer == true
        case "noInvest":
            return path.type == "invest"
        default:
            return false
        }
    }

    func apply(_ bucket: MatchBucket, _ profile: Profile) -> MatchBucket {
        guard !isEmpty else { return bucket }
        var out = MatchBucket()
        for s in MatchStatus.allCases {
            out[s] = bucket[s].filter { keeps($0.path, profile) }
        }
        return out
    }

    /// 说明筛掉了什么（隐式过滤会让人误以为那些路径不存在）
    func hiddenNote(_ bucket: MatchBucket, _ profile: Profile, total: Int) -> String? {
        let all = bucket.all
        let hidden = all.filter { !keeps($0.path, profile) }
        guard !hidden.isEmpty else { return nil }
        var reasons: [String] = []
        if onlyDeveloped {
            let n = all.filter { !Lexicon.developed.contains($0.path.country) }.count
            if n > 0 { reasons.append("非发达地区 \(n) 条") }
        }
        if !regions.isEmpty {
            let n = all.filter { !regions.contains(Lexicon.regionOf[$0.path.country] ?? "other") }.count
            if n > 0 { reasons.append("地区不符 \(n) 条") }
        }
        if !countries.isEmpty {
            let n = all.filter {
                (regions.isEmpty || regions.contains(Lexicon.regionOf[$0.path.country] ?? "other"))
                    && !countries.contains($0.path.country)
            }.count
            if n > 0 { reasons.append("国家不符 \(n) 条") }
        }
        for key in excludes {
            let n = all.filter { excluded(key, $0.path, profile) }.count
            let label = Lexicon.excludes.first { $0.key == key }?.label ?? key
            if n > 0 { reasons.append("\(label) \(n) 条") }
        }
        return "已隐藏 \(hidden.count) 条：\(reasons.joined(separator: " · "))"
    }
}

// MARK: - 工具

extension Int {
    /// 千分位（避免依赖 Locale 环境）
    func formatted() -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = ","
        return f.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}

enum Fmt {
    static func months(_ m: [Int]) -> String {
        if m.count < 2 { return "" }
        if m[1] <= 1 { return "1 个月内" }
        return m[0] == m[1] ? "\(m[0]) 个月" : "\(m[0])–\(m[1]) 个月"
    }
    static let costLabel = ["none": "无", "low": "低", "mid": "中", "high": "高"]

    static func effortLine(_ e: Effort) -> String {
        "预计准备 \(months(e.months))，花费：\(costLabel[e.cost] ?? e.cost)" +
            (e.uncertain ? "，其中有不确定项" : "") + "（粗略估计）"
    }
}
