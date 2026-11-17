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
        do {
            let root = try decoder.decode(Seed.self, from: data)
            apply(root)
            if root.pathways.isEmpty { return ([], .empty) }
            return (root.pathways, nil)
        } catch {
            // 2) 顶层失败：先单独验证 pathways，再逐个顶层字段验证，定位真凶
            let detail = diagnose(data: data, seedError: error)
            return ([], .decode(detail))
        }
    }

    /// 定位顶层解码失败的具体字段：常见原因是某个词库字段的类型和 Swift 声明不一致
    private static func diagnose(data: Data, seedError: Error) -> String {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return "seed.json 顶层不是对象：\(seedError)"
        }
        let decoder = JSONDecoder()

        // pathways 单条验证
        if let arr = obj["pathways"] as? [Any] {
            var okCount = 0
            var firstError = ""
            for (idx, item) in arr.enumerated() {
                guard let itemData = try? JSONSerialization.data(withJSONObject: item) else { continue }
                do {
                    _ = try decoder.decode(Pathway.self, from: itemData)
                    okCount += 1
                } catch where firstError.isEmpty {
                    let id = (item as? [String: Any])?["id"] as? String ?? "#\(idx)"
                    firstError = "\(id): \(error)"
                } catch {}
            }
            if okCount == arr.count, firstError.isEmpty {
                return "pathways 全部 \(arr.count) 条可解析，问题在词库字段：\n\(seedError)"
            }
            return "pathways \(okCount)/\(arr.count) 条可解析；首个错误 \(firstError)"
        }

        // 逐个顶层键用 JSONDecoder 试解码，找出类型不符的字段
        var suspects: [String] = []
        for (key, value) in obj where key != "pathways" {
            guard let kv = try? JSONSerialization.data(withJSONObject: [key: value]),
                  (try? JSONSerialization.jsonObject(with: kv)) != nil else { continue }
            if !fieldDecodes(key: key, valueData: kv) {
                suspects.append(key)
            }
        }
        let hint = suspects.isEmpty ? "" : "（疑似字段：\(suspects.joined(separator: ", "))）"
        return "词库字段类型不符\(hint)：\n\(seedError)"
    }

    /// 单个顶层字段的类型校验（按声明类型分别尝试）
    private static func fieldDecodes(key: String, valueData: Data) -> Bool {
        let decoder = JSONDecoder()
        func tryDecode<T: Decodable>(_ type: T.Type) -> Bool {
            guard let whole = try? JSONSerialization.jsonObject(with: valueData) as? [String: Any],
                  let raw = whole[key],
                  let d = try? JSONSerialization.data(withJSONObject: raw) else { return false }
            return (try? decoder.decode(T.self, from: d)) != nil
        }
        switch key {
        case "DEVELOPED":
            return tryDecode([String].self)
        case "MONTHLY_INCOME_BANDS":
            return tryDecode([Lexicon.IncomeBand].self)
        case "INCOME_SOURCE_LOCATIONS":
            return tryDecode([String].self)
        case "updated":
            return tryDecode(String.self)
        case "excludes":
            return tryDecode([String: Seed.ExcludeInfo].self)
        case "DEG", "ENG", "FRA", "LANGS", "STUDY_LOC", "SKILLS", "GOALS",
             "REGION_LABEL", "REGION_OF", "TYPE_LABEL":
            return tryDecode([String: String].self)
        default:
            return true
        }
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
        Lexicon.excludes = (root.excludes ?? [:]).sorted { $0.key < $1.key }.map { k, v in
            (k, v.label, v.hint ?? "")
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
