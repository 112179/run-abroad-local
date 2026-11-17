import Foundation
import SwiftUI

// MARK: - 种子数据加载

enum StoreError: Equatable {
    case missingFile
    case decode(String)
    case empty
}

enum Store {
    /// 加载结果（含错误信息，界面上会直接提示，不再静默变空）
    static let loaded: (pathways: [Pathway], error: StoreError?) = load()

    static var pathways: [Pathway] { loaded.pathways }
    static var error: StoreError? { loaded.error }

    private static func load() -> ([Pathway], StoreError?) {
        guard let url = Bundle.main.url(forResource: "seed", withExtension: "json") else {
            return ([], .missingFile)
        }
        guard let data = try? Data(contentsOf: url) else { return ([], .missingFile) }

        let decoder = JSONDecoder()
        // 1) 顶层结构（词库 + 路径数组）
        guard let root = try? decoder.decode(Seed.self, from: data) else {
            // 2) 顶层失败时，逐条解析路径，收集具体错误
            let detail = diagnose(data: data)
            return ([], .decode(detail))
        }
        apply(root)
        if root.pathways.isEmpty { return ([], .empty) }
        return (root.pathways, nil)
    }

    /// 逐条容错：某一条路径字段不合规时只丢那一条，而不是整个 App 变成 0 条。
    private static func diagnose(data: Data) -> String {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let raw = obj["pathways"] else { return "seed.json 顶层结构无法识别" }

        guard let arr = raw as? [Any] else { return "pathways 不是数组" }
        var okCount = 0
        var firstError = ""
        let decoder = JSONDecoder()
        for (idx, item) in arr.enumerated() {
            guard let itemData = try? JSONSerialization.data(withJSONObject: item) else { continue }
            do {
                _ = try decoder.decode(Pathway.self, from: itemData)
                okCount += 1
            } catch {
                if firstError.isEmpty {
                    let id = (item as? [String: Any])?["id"] as? String ?? "#\(idx)"
                    firstError = "\(id): \(error)"
                }
            }
        }
        if okCount > 0 {
            return "共 \(arr.count) 条，其中 \(okCount) 条可解析；首个错误 \(firstError)"
        }
        return "全部 \(arr.count) 条解析失败；首个错误 \(firstError)"
    }

    private static func apply(_ root: Seed) {
        Lexicon.skillNames = root.SKILLS ?? [:]
        Lexicon.typeLabels = root.TYPE_LABEL ?? [:]
        Lexicon.regionLabels = root.REGION_LABEL ?? [:]
        Lexicon.regionOf = root.REGION_OF ?? [:]
        Lexicon.studyLoc = root.STUDY_LOC ?? [:]
        Lexicon.langs = root.LANGS ?? [:]
        Lexicon.developed = Set(root.DEVELOPED ?? [])
        Lexicon.incomeBands = root.MONTHLY_INCOME_BANDS ?? []
        Lexicon.incomeSources = root.INCOME_SOURCE_LOCATIONS ?? []
        Lexicon.updated = root.updated ?? ""
        Lexicon.excludes = (root.excludes ?? [:]).keys.sorted().compactMap { k in
            guard let v = root.excludes?[k] else { return nil }
            return (k, v.label, v.hint)
        }
    }

    struct Seed: Decodable {
        let pathways: [Pathway]
        let SKILLS: [String: String]?
        let TYPE_LABEL: [String: String]?
        let REGION_LABEL: [String: String]?
        let REGION_OF: [String: String]?
        let STUDY_LOC: [String: String]?
        let LANGS: [String: String]?
        let DEVELOPED: [String]?
        let MONTHLY_INCOME_BANDS: [Lexicon.IncomeBand]?
        let INCOME_SOURCE_LOCATIONS: [String]?
        let excludes: [String: ExcludeInfo]?
        let updated: String?

        struct ExcludeInfo: Decodable { let label: String; let hint: String? }
    }

    static var orderedIncomeSources: [String] {
        let first = ["中国大陆", "中国香港"]
        let last = "其他国家 / 地区"
        let middle = Lexicon.incomeSources
            .filter { !first.contains($0) && $0 != last }
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        return first.filter { Lexicon.incomeSources.contains($0) } + middle
            + (Lexicon.incomeSources.contains(last) ? [last] : [])
    }

    static var countries: [String] {
        Array(Set(pathways.map { $0.country })).sorted {
            let a = Lexicon.regionOrder.firstIndex(of: Lexicon.regionOf[$0] ?? "other") ?? 9
            let b = Lexicon.regionOrder.firstIndex(of: Lexicon.regionOf[$1] ?? "other") ?? 9
            return a != b ? a < b : $0.localizedStandardCompare($1) == .orderedAscending
        }
    }
}

// MARK: - 档案持久化

@MainActor
final class AppModel: ObservableObject {
    @Published var profile: Profile {
        didSet { persist() }
    }
    @Published var filters = Filters()
    @Published var page: Page = .form
    @Published var uiStyle: UIStyle {
        didSet { UserDefaults.standard.set(uiStyle.rawValue, forKey: "uiStyle.v1") }
    }

    enum Page { case form, results }

    private static let key = "profile.v1"

    init() {
        let saved = UserDefaults.standard.string(forKey: "uiStyle.v1")
        uiStyle = UIStyle(rawValue: saved ?? "") ?? .dashboard
        if let data = UserDefaults.standard.data(forKey: Self.key),
           let p = try? JSONDecoder().decode(Profile.self, from: data) {
            profile = p
        } else {
            profile = Profile()
        }
        // 修正默认风格：新装用户默认 B 结果优先
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }

    var bucket: MatchBucket { Engine.matchAll(profile, pathways: Store.pathways) }
    var filtered: MatchBucket { filters.apply(bucket, profile) }
    var bottlenecks: [Bottleneck] { Engine.bottlenecks(filtered) }

    func resetProfile() {
        profile = Profile()
    }
}
