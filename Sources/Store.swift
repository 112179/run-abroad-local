import Foundation
import SwiftUI

// MARK: - 种子数据加载

enum Store {
    static let shared: (pathways: [Pathway], lexiconLoaded: Bool) = load()

    private static func load() -> ([Pathway], Bool) {
        guard let url = Bundle.main.url(forResource: "seed", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            assertionFailure("seed.json 缺失")
            return ([], false)
        }
        guard let root = try? JSONDecoder().decode(Seed.self, from: data) else {
            assertionFailure("seed.json 解析失败")
            return ([], false)
        }
        Lexicon.skillNames = root.SKILLS
        Lexicon.typeLabels = root.TYPE_LABEL
        Lexicon.regionLabels = root.REGION_LABEL
        Lexicon.regionOf = root.REGION_OF
        Lexicon.studyLoc = root.STUDY_LOC
        Lexicon.langs = root.LANGS
        Lexicon.developed = Set(root.DEVELOPED)
        Lexicon.incomeBands = root.MONTHLY_INCOME_BANDS
        Lexicon.incomeSources = root.INCOME_SOURCE_LOCATIONS
        Lexicon.updated = root.updated
        Lexicon.excludes = root.excludes.keys.sorted().compactMap { k in
            guard let v = root.excludes[k] else { return nil }
            return (k, v.label, v.hint)
        }
        return (root.pathways, true)
    }

    static var pathways: [Pathway] { shared.pathways }

    private struct Seed: Decodable {
        let pathways: [Pathway]
        let SKILLS: [String: String]
        let TYPE_LABEL: [String: String]
        let REGION_LABEL: [String: String]
        let REGION_OF: [String: String]
        let STUDY_LOC: [String: String]
        let LANGS: [String: String]
        let DEVELOPED: [String]
        let MONTHLY_INCOME_BANDS: [Lexicon.IncomeBand]
        let INCOME_SOURCE_LOCATIONS: [String]
        let excludes: [String: ExcludeInfo]
        let updated: String

        struct ExcludeInfo: Decodable { let label: String; let hint: String }
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
