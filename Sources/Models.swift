import Foundation

// MARK: - 数据模型（对应上游 js/data.js）

struct Pathway: Identifiable, Decodable, Hashable {
    let id: String
    let country: String
    let flag: String
    let name: String
    let nameEn: String?
    let type: String
    let duration: String?
    let pr: String?
    let req: Requirements
    let quota: String?
    let cost: String?
    let costUSD: Int?
    let difficulty: Int
    let notes: String?
    let official: String
    let detail: Detail?

    struct Requirements: Decodable, Hashable {
        let age: [Int]?
        let minDeg: Int?
        let allowCurrentStudent: Bool?
        let degOrWorkExp: Int?
        let uniRank: Int?
        let ugRank: Int?
        let gradWithin: Int?
        let minEng: Int?
        let minFrench: Int?
        let otherLang: OtherLang?
        let workExp: Int?
        let jobOffer: Bool?
        let fundsUSD: Int?
        let studyIn: String?
        let studyInAny: [String]?
        let skills: [String]?
        let income: Income?
    }

    struct OtherLang: Decodable, Hashable {
        let code: String
        let label: String
    }

    struct Income: Decodable, Hashable {
        let mode: String          // remote | passive | either
        let minMonthlyUSD: Int
        let foreignSource: Bool?
        let sourceIn: [String]?
        let shortfallHint: String?
        let sourceHint: String?
    }

    struct Detail: Decodable, Hashable {
        let timeline: String?
        let steps: [String]?
        let docs: [String]?
        let pitfalls: [String]?
        let links: [Link]?
    }

    struct Link: Decodable, Hashable, Identifiable {
        let t: String
        let u: String
        var id: String { u }
    }
}

// MARK: - 静态字典（种子 JSON 提供）

enum Lexicon {
    static let degreeLabels = ["无学历", "高中", "大专", "本科", "硕士", "博士"]
    static let engLabels = ["几乎不会", "日常交流", "雅思 5.5 / CET-6 水平", "雅思 6.5 / 工作可用", "接近母语"]
    static let fraLabels = ["不会法语", "入门 (A1–A2)", "中级 (NCLC 5–6)", "NCLC 7+ / TEF B2 以上"]

    static var skillNames: [String: String] = [:]
    static var typeLabels: [String: String] = [:]
    static var regionLabels: [String: String] = [:]
    static var regionOf: [String: String] = [:]
    static var studyLoc: [String: String] = [:]
    static var langs: [String: String] = [:]
    static var developed: Set<String> = []
    static var incomeBands: [IncomeBand] = []
    static var incomeSources: [String] = []
    static var excludes: [(key: String, label: String, hint: String)] = []
    static var updated = ""

    struct IncomeBand: Decodable, Identifiable {
        let v: Int
        let min: Int
        let max: Int?
        let t: String
        var id: Int { v }
    }

    static let goalOptions: [(key: String, label: String)] = [
        ("fast", "尽快先出去，落脚再说"),
        ("pr", "奔着永居 / 护照去"),
        ("cheap", "预算有限，越便宜越好"),
        ("family", "要带配偶 / 孩子"),
        ("study", "接受再读一个学位"),
        ("remote", "有远程工作 / 想数字游民"),
        ("business", "有创业或投资打算"),
    ]

    static let skillOptions: [(key: String, label: String)] = [
        ("tech", "IT / 软件开发"),
        ("engineering", "工程 / 制造"),
        ("healthcare", "医护 / 生物医药"),
        ("finance", "金融 / 会计"),
        ("science", "科研 / 学术"),
        ("education", "教育 / 培训"),
        ("trades", "技工（厨师/电焊/美发/建筑等）"),
        ("business", "管理 / 市场 / 运营"),
        ("arts", "设计 / 媒体 / 创作"),
        ("none", "暂无明确专业技能"),
    ]

    static let langOptions: [(key: String, label: String)] = [
        ("de", "德语"), ("ja", "日语"), ("ko", "韩语"), ("es", "西班牙语"),
        ("nordic", "北欧语言（芬兰语/挪威语/瑞典语等）"),
    ]

    static let regionOrder = ["asia", "eu", "na", "oc", "latam", "other"]

    static func typeLabel(_ t: String) -> String { typeLabels[t] ?? t }
    static func prText(_ p: Pathway) -> String { Engine.leadsToPR(p) ? "通往永居" : "不通往永居" }
}
