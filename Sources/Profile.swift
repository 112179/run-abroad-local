import Foundation

// MARK: - 用户档案

struct Profile: Codable, Equatable {
    var age: Int = 25
    var degree: Int = 3              // 0 无 / 1 高中 / 2 大专 / 3 本科 / 4 硕士 / 5 博士
    var uniRank: Int = 9999          // 世界排名档位，9999 = 不限/500 开外
    var ugRank: Int = 9999
    var studyLoc: String = "cn"
    var yearsSinceGrad: Int? = nil   // nil = 还在读 / 尚未毕业
    var english: Int = 2
    var french: Int = 0
    var workExp: Int = 1
    var funds: Int = 3000
    var incomeType: String? = nil    // none / employee / selfEmployed / passive / mixed
    var remoteAbroad: String? = nil  // no / uncertain / yes
    var activeIncome: Int? = nil
    var passiveIncome: Int? = nil
    var primaryIncomeCountry: String? = nil
    var hasOffer: Bool = false
    var langs: [String] = []
    var skills: [String] = []
    var goals: [String] = []

    var effectiveUGRank: Int { degree > 3 ? ugRank : uniRank }
    var hasActiveIncome: Bool { ["employee", "selfEmployed", "mixed"].contains(incomeType ?? "") }
    var hasPassiveIncome: Bool { ["passive", "mixed"].contains(incomeType ?? "") }
}

// MARK: - 匹配结果

enum GapKind: String, Codable { case hard, soft }

struct Effort: Codable, Equatable {
    var months: [Int]        // [lo, hi]
    var cost: String         // none / low / mid / high
    var uncertain: Bool
}

struct Gap: Identifiable, Codable {
    var id = UUID()
    var kind: GapKind
    var field: String
    var text: String
    var effort: Effort?
}

enum MatchStatus: String, Codable, CaseIterable {
    case eligible, close, stretch, blocked

    var title: String {
        switch self {
        case .eligible: return "符合条件"
        case .close: return "差一点"
        case .stretch: return "需要长期准备"
        case .blocked: return "暂时走不通"
        }
    }
    var hint: String {
        switch self {
        case .eligible: return "按你填的信息，这些路径的硬性门槛你都过了"
        case .close: return "只差一两项，而且都能补上（语言、经验、资金、offer）"
        case .stretch: return "缺口较多，但方向上没有被堵死"
        case .blocked: return "存在短期改不了的硬门槛（年龄、毕业年限、院校排名）"
        }
    }
}

struct MatchResult: Identifiable {
    var path: Pathway
    var status: MatchStatus
    var hardGaps: [Gap]
    var softGaps: [Gap]
    var skillMatch: Bool
    var effort: Effort?
    var score: Int

    var id: String { path.id }
}

struct Bottleneck: Identifiable {
    var field: String
    var count: Int
    var months: [Int]
    var text: String
    var id: String { field }
}

struct MatchBucket {
    var eligible: [MatchResult] = []
    var close: [MatchResult] = []
    var stretch: [MatchResult] = []
    var blocked: [MatchResult] = []

    var all: [MatchResult] { eligible + close + stretch + blocked }
    subscript(_ s: MatchStatus) -> [MatchResult] {
        get {
            switch s {
            case .eligible: return eligible
            case .close: return close
            case .stretch: return stretch
            case .blocked: return blocked
            }
        }
        set {
            switch s {
            case .eligible: eligible = newValue
            case .close: close = newValue
            case .stretch: stretch = newValue
            case .blocked: blocked = newValue
            }
        }
    }
    var total: Int { eligible.count + close.count + stretch.count + blocked.count }
}
