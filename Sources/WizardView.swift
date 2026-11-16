import SwiftUI

// MARK: - 风格 C：新版 iOS 向导 —— 一屏一问，逐步推进

struct WizardView: View {
    @EnvironmentObject private var model: AppModel
    @State private var step = 0
    @State private var showSettings = false

    private var b: ProfileFieldBindings { ProfileFieldBindings(model: model) }
    private let total = 6

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                progressBar
                TabView(selection: $step) {
                    stepBasic.tag(0)
                    stepLanguage.tag(1)
                    stepExperience.tag(2)
                    stepIncome.tag(3)
                    stepSkill.tag(4)
                    stepGoal.tag(5)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.snappy(duration: 0.25), value: step)
                bottomBar
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(stepTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if step > 0 {
                        Button("上一步") { step -= 1 }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: { Image(systemName: "slider.horizontal.3") }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsSheet(showReset: .constant(false))
            }
        }
    }

    private var stepTitle: String {
        ["基本情况", "语言", "经验与资金", "收入情况", "技能方向", "你的目标"][step]
    }

    private var progressBar: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(.tertiarySystemFill))
                    Capsule().fill(Color.accentColor)
                        .frame(width: geo.size.width * CGFloat(step + 1) / CGFloat(total))
                }
            }
            .frame(height: 4)
            HStack {
                Text("第 \(step + 1) / \(total) 步").font(.caption2).foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(Double(step + 1) / Double(total) * 100))%")
                    .font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var bottomBar: some View {
        VStack(spacing: 10) {
            if step < total - 1 {
                PrimaryButton(title: "下一步", icon: "arrow.right") { step += 1 }
            } else {
                PrimaryButton(title: "看看我能走哪些路径", icon: "sparkle.magnifyingglass") {
                    model.page = .results
                }
            }
            Text("数据更新 \(Lexicon.updated) · 全部离线运行 · 初筛参考，请以官网为准")
                .font(.caption2).foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    // MARK: 各步

    private func stepCard<C: View>(_ title: String, subtitle: String,
                                   @ViewBuilder content: () -> C) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(title).font(.title2.bold())
                Text(subtitle).font(.footnote).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                VStack(spacing: 12) { content() }
                    .padding(16)
                    .background(Color(.secondarySystemGroupedBackground),
                                in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .padding(16)
        }
    }

    private var stepBasic: some View {
        stepCard("先说说你自己", subtitle: "年龄、学历和院校档位决定了一半的门槛 —— 也是唯一补不了的那部分。") {
            BasicFields(b: b)
        }
    }

    private var stepLanguage: some View {
        stepCard("语言能到哪一档", subtitle: "语言是绝大多数路径的开关，也是最快能补上的一项。") {
            LanguageFields(b: b)
        }
    }

    private var stepExperience: some View {
        stepCard("经验和预算", subtitle: "工作年限能替代部分学历要求；预算决定要不要看打工度假和职教路径。") {
            ExperienceFields(b: b)
        }
    }

    private var stepIncome: some View {
        stepCard("有没有持续收入", subtitle: "这类问题只影响数字游民、被动收入签证 —— 没有的话直接跳过。") {
            IncomeFields(b: b)
        }
    }

    private var stepSkill: some View {
        stepCard("你的专业方向", subtitle: "选了会优先推荐对应紧缺职业清单的路径，不选也没关系。") {
            SkillFields(b: b)
        }
    }

    private var stepGoal: some View {
        stepCard("你最想要什么", subtitle: "同样的条件下，目标不同排序完全不同：奔永居的和想尽快出去的不是同一批路径。") {
            GoalFields(b: b)
        }
    }
}
