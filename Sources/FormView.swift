import SwiftUI

// MARK: - 风格 A：卡片分组表单

struct FormView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showReset = false
    @State private var showSettings = false


    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    hero

                    SectionCard(title: "基本情况", systemImage: "person.text.rectangle") {
                        BasicFields(model: model)
                    }
                    SectionCard(title: "语言", systemImage: "character.bubble") {
                        LanguageFields(model: model)
                    }
                    SectionCard(title: "经验与资金", systemImage: "briefcase") {
                        ExperienceFields(model: model)
                    }
                    SectionCard(title: "收入情况", systemImage: "banknote",
                                note: "只用于判断数字游民 / 被动收入类路径") {
                        IncomeFields(model: model)
                    }
                    SectionCard(title: "技能方向", systemImage: "hammer",
                                note: "可不选；选了会优先推荐对口路径") {
                        SkillFields(model: model)
                    }
                    SectionCard(title: "你的目标", systemImage: "target") {
                        GoalFields(model: model)
                    }

                    PrimaryButton(title: "看看我能走哪些路径", icon: "sparkle.magnifyingglass") {
                        model.page = .results
                    }

                    footnote
                }
                .padding(.horizontal, 16)
            }
            .background(Color(.systemGroupedBackground))
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("润学导航")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: { Image(systemName: "slider.horizontal.3") }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsSheet(showReset: $showReset)
            }
            .confirmationDialog("清空已填信息？", isPresented: $showReset, titleVisibility: .visible) {
                Button("重置", role: .destructive) { model.resetProfile() }
            }
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("填几项基本信息").font(.largeTitle.bold())
            Text("从 \(Store.pathways.count) 条签证 / 移民路径里筛出适合你的，并告诉你还差什么。")
                .font(.subheadline).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }

    private var footnote: some View {
        Text("数据更新 \(Lexicon.updated) · 共 \(Store.pathways.count) 条路径 · 全部离线运行\n初筛工具，不是法律意见，任何决定前请以官网为准")
            .font(.caption2).foregroundStyle(.tertiary)
            .multilineTextAlignment(.center)
            .padding(.bottom, 24)
    }
}

// MARK: - 通用大按钮

struct PrimaryButton: View {
    let title: String
    var icon: String? = nil
    var gradient: Bool = true
    let action: () -> Void

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            action()
        } label: {
            HStack(spacing: 8) {
                if let icon { Image(systemName: icon) }
                Text(title).fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(colors: [Color.accentColor, Color.accentColor.opacity(0.78)],
                               startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .foregroundStyle(.white)
            .shadow(color: Color.accentColor.opacity(0.28), radius: 12, y: 6)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 设置（风格切换 / 重置 / 关于）

struct SettingsSheet: View {
    @EnvironmentObject private var model: AppModel
    @Binding var showReset: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(UIStyle.allCases) { style in
                        Button {
                            model.uiStyle = style
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: style.icon)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(Color.accentColor)
                                    .frame(width: 30, height: 30)
                                    .background(Color.accentColor.opacity(0.12),
                                                in: RoundedRectangle(cornerRadius: 8))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(style.title).foregroundStyle(.primary)
                                    Text(style.subtitle).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                if model.uiStyle == style {
                                    Image(systemName: "checkmark").foregroundStyle(Color.accentColor)
                                }
                            }
                        }
                    }
                } header: {
                    Text("界面风格")
                } footer: {
                    Text("三种风格数据与匹配结果完全一致，只换布局。可随时切回来对比。")
                }

                Section {
                    Button("清空已填信息", role: .destructive) {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { showReset = true }
                    }
                }

                Section("关于") {
                    LabeledContent("路径数据", value: "\(Store.pathways.count) 条 · \(Lexicon.updated)")
                    LabeledContent("数据来源", value: "RadishXN/run-abroad")
                    LabeledContent("运行方式", value: "完全离线，无网络请求")
                    if let url = URL(string: "https://github.com/RadishXN/run-abroad") {
                        Link("打开上游项目", destination: url)
                    }
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("完成") { dismiss() } }
            }
        }
    }
}
