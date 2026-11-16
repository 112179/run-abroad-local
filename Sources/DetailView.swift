import SwiftUI

// MARK: - 路径详情

struct DetailView: View {
    let path: Pathway
    var profile: Profile? = nil
    @EnvironmentObject private var model: AppModel
    @Environment(\.openURL) private var openURL

    private var result: MatchResult? {
        Engine.check(profile ?? model.profile, path)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                if let r = result, r.status != .eligible { gapSection(r) }
                whatItIs
                requirements
                if let d = path.detail {
                    if let steps = d.steps, !steps.isEmpty {
                        listSection("申请步骤", steps, icon: "list.number", ordered: true)
                    }
                    if let docs = d.docs, !docs.isEmpty {
                        listSection("需要准备的材料", docs, icon: "doc.text", ordered: false)
                    }
                    if let pitfalls = d.pitfalls, !pitfalls.isEmpty {
                        listSection("容易踩的坑", pitfalls, icon: "exclamationmark.triangle",
                                    ordered: false, warn: true)
                    }
                } else {
                    Text("这条还没写详细流程。上面的门槛和链接是准确的，但申请步骤、材料清单还没整理 —— 与其编一套没核实过的流程，不如先空着。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.secondarySystemGroupedBackground),
                                    in: RoundedRectangle(cornerRadius: 14))
                }
                links
                Text("初筛工具，不是法律意见。政策随时变动，请以官方页面为准。")
                    .font(.caption2).foregroundStyle(.tertiary)
                    .padding(.bottom, 24)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(path.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: 头部

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                Text(path.flag).font(.system(size: 40))
                VStack(alignment: .leading, spacing: 2) {
                    Text(path.name).font(.title3.bold())
                    Text("\(path.country)\(path.nameEn.map { " · \($0)" } ?? "")")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            FlowLayout(spacing: 6) {
                Tag(text: Lexicon.typeLabel(path.type), icon: "tag", tint: .accentColor)
                Tag(text: Lexicon.regionLabels[Lexicon.regionOf[path.country] ?? "other"] ?? "",
                    icon: "globe")
                Tag(text: "难度 " + String(repeating: "●", count: path.difficulty)
                        + String(repeating: "○", count: max(0, 5 - path.difficulty)),
                    icon: "gauge.with.dots.needle.33percent")
                Tag(text: Engine.leadsToPR(path) ? "通往永居" : "不通往永居",
                    icon: "house", tint: Engine.leadsToPR(path) ? .green : .secondary)
            }
        }
    }

    // MARK: 我的缺口

    private func gapSection(_ r: MatchResult) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("你还差什么").font(.headline)
                Spacer()
                Text(r.status.title)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Color.orange.opacity(0.15), in: Capsule())
                    .foregroundStyle(.orange)
            }
            ForEach(r.hardGaps) { g in
                gapLine(g, tint: .red, icon: "xmark.octagon.fill")
            }
            ForEach(r.softGaps) { g in
                gapLine(g, tint: .orange, icon: "exclamationmark.circle.fill")
            }
            if let e = r.effort {
                Text(Fmt.effortLine(e))
                    .font(.caption).foregroundStyle(.secondary)
                    .padding(.top, 2)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 14))
    }

    private func gapLine(_ g: Gap, tint: Color, icon: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon).font(.caption).foregroundStyle(tint).padding(.top, 2)
            VStack(alignment: .leading, spacing: 1) {
                Text(g.text).font(.footnote)
                if let e = g.effort, g.kind == .soft {
                    Text("预估 " + Fmt.months(e.months) + (e.uncertain ? "（不确定）" : ""))
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: 是什么

    private var whatItIs: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("这条路是什么").font(.headline)
            if let notes = path.notes {
                Text(notes.replacingOccurrences(of: "**", with: ""))
                    .font(.footnote)
                    .fixedSize(horizontal: false, vertical: true)
            }
            VStack(spacing: 0) {
                ForEach(facts, id: \.0) { fact in
                    HStack(alignment: .top, spacing: 12) {
                        Text(fact.0).font(.caption).foregroundStyle(.secondary)
                            .frame(width: 62, alignment: .leading)
                        Text(fact.1).font(.footnote)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 7)
                    if fact.0 != facts.last?.0 { Divider() }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 16))
    }

    private var facts: [(String, String)] {
        var out: [(String, String)] = []
        if let d = path.duration { out.append(("签证时长", d)) }
        if let p = path.pr { out.append(("永居路径", p)) }
        if let c = path.cost { out.append(("费用", c)) }
        if let q = path.quota { out.append(("名额", q)) }
        if let t = path.detail?.timeline { out.append(("办理周期", t)) }
        return out
    }

    // MARK: 申请门槛

    private var requirements: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("申请门槛").font(.headline)
            ForEach(requirementRows, id: \.0) { row in
                HStack(alignment: .top, spacing: 12) {
                    Text(row.0).font(.caption).foregroundStyle(.secondary)
                        .frame(width: 62, alignment: .leading)
                    Text(row.1).font(.footnote)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 16))
    }

    private var requirementRows: [(String, String)] {
        let r = path.req
        var rows: [(String, String)] = []
        if let age = r.age, age.count == 2 {
            rows.append(("年龄", "\(age[0]) – \(age[1] == 99 ? "不限" : "\(age[1])") 岁"))
        }
        if let deg = r.minDeg {
            let base = "\(Lexicon.degreeLabels[min(deg, 5)])及以上"
            rows.append(("学历", r.allowCurrentStudent == true ? "\(base)，或当前本科在读" : base))
        }
        if let rank = r.uniRank { rows.append(("院校", "世界排名前 \(rank)")) }
        if let rank = r.ugRank {
            rows.append(("本科院校", "世界排名前 \(rank)（QS\(rank)），只看本科，硕博院校不算"))
        }
        if let s = r.studyIn { rows.append(("学位取得地", "必须在\(Lexicon.studyLoc[s] ?? s)的院校取得")) }
        if let any = r.studyInAny, !any.isEmpty {
            rows.append(("院校所在地", "需在以下地区之一的院校就读或毕业："
                         + any.map { Lexicon.studyLoc[$0] ?? $0 }.joined(separator: " / ")))
        }
        if let within = r.gradWithin { rows.append(("毕业年限", "毕业 \(within) 年内")) }
        if let e = r.minEng { rows.append(("英语", Lexicon.engLabels[min(e, 4)])) }
        if let f = r.minFrench { rows.append(("法语", Lexicon.fraLabels[min(f, 3)])) }
        if let ol = r.otherLang { rows.append(("其他语言", ol.label)) }
        if let w = r.workExp { rows.append(("工作经验", "\(w) 年以上")) }
        if r.jobOffer == true { rows.append(("雇主", "需先拿到当地的工作 / 培训合同")) }
        if let f = r.fundsUSD { rows.append(("资金", "约 $\(f.formatted())（资金证明或存款）")) }
        if let income = r.income {
            let mode: String
            switch income.mode {
            case "remote": mode = "可长期在境外进行的远程主动收入"
            case "passive": mode = "稳定被动收入"
            default: mode = "远程主动收入或稳定被动收入"
            }
            var parts = [mode, "约 $\(income.minMonthlyUSD.formatted())/月以上"]
            if income.foreignSource == true { parts.append("主要收入需来自目标国家 / 地区以外") }
            rows.append(("持续收入", parts.joined(separator: "；")))
        }
        if let skills = r.skills {
            rows.append(("偏好背景", skills.map { Lexicon.skillNames[$0] ?? $0 }.joined(separator: " / ")))
        }
        if rows.isEmpty { rows.append(("门槛", "无硬性门槛")) }
        return rows
    }

    // MARK: 步骤 / 材料 / 坑

    private func listSection(_ title: String, _ items: [String], icon: String,
                             ordered: Bool, warn: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundStyle(warn ? AnyShapeStyle(Color.orange) : AnyShapeStyle(Color.primary))
            ForEach(Array(items.enumerated()), id: \.offset) { idx, item in
                HStack(alignment: .top, spacing: 8) {
                    if ordered {
                        Text("\(idx + 1)")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 18, height: 18)
                            .background(Color.accentColor, in: Circle())
                    } else {
                        Text("•").font(.caption).foregroundStyle(.secondary).frame(width: 8)
                    }
                    Text(item.replacingOccurrences(of: "**", with: ""))
                        .font(.footnote)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: 链接

    private var links: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("官方与延伸链接").font(.headline).padding(.bottom, 8)
            linkRow("官方页面（以此为准）", path.official, primary: true)
            ForEach(path.detail?.links ?? []) { l in
                Divider().padding(.leading, 16)
                linkRow(l.t, l.u, primary: false)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 16))
    }

    private func linkRow(_ title: String, _ urlString: String, primary: Bool) -> some View {
        let url = urlString.hasPrefix("//") ? URL(string: "https:" + urlString) : URL(string: urlString)
        return Button {
            if let url { openURL(url) }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: primary ? "checkmark.shield" : "link")
                    .font(.caption).foregroundStyle(primary ? Color.green : Color.secondary)
                Text(title).font(.footnote).foregroundStyle(primary ? Color.primary : Color.accentColor)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 4)
                Image(systemName: "arrow.up.right").font(.caption2).foregroundStyle(.tertiary)
            }
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
