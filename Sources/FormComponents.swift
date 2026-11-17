import SwiftUI

// MARK: - 分组卡片

struct SectionCard<Content: View>: View {
    let title: String
    let systemImage: String
    var note: String? = nil
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.accentColor)
                    .frame(width: 22, height: 22)
                    .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
                Text(title).font(.headline)
                Spacer()
            }
            if let note {
                Text(note).font(.caption).foregroundStyle(.secondary)
            }
            VStack(spacing: 12) { content }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

// MARK: - 单行选择器（点开底部菜单，比 Menu 更稳、适配长列表）

struct PickerRow: View {
    let title: String
    @Binding var selection: Int
    let options: [(Int, String)]
    @State private var showSheet = false

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                showSheet = true
            } label: {
                HStack(spacing: 4) {
                    Text(currentLabel)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.accentColor)
                        .multilineTextAlignment(.trailing)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
        }
        .contentShape(Rectangle())
        .onTapGesture { showSheet = true }
        .sheet(isPresented: $showSheet) {
            OptionSheet(title: title, options: options, selection: $selection)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private var currentLabel: String {
        options.first { $0.0 == selection }?.1 ?? "—"
    }
}

/// 字符串版（用于地区、来源地等）
struct StringPickerRow: View {
    let title: String
    @Binding var selection: String
    let options: [(String, String)]
    @State private var showSheet = false

    var body: some View {
        HStack(spacing: 12) {
            Text(title).font(.subheadline).frame(maxWidth: .infinity, alignment: .leading)
            Button { showSheet = true } label: {
                HStack(spacing: 4) {
                    Text(options.first { $0.0 == selection }?.1 ?? selection)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.accentColor)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
        }
        .contentShape(Rectangle())
        .onTapGesture { showSheet = true }
        .sheet(isPresented: $showSheet) {
            StringOptionSheet(title: title, options: options, selection: $selection)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }
}

// MARK: - 选项面板

struct OptionSheet: View {
    let title: String
    let options: [(Int, String)]
    @Binding var selection: Int
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(options, id: \.0) { opt in
                Button {
                    selection = opt.0
                    UISelectionFeedbackGenerator().selectionChanged()
                    dismiss()
                } label: {
                    HStack {
                        Text(opt.1).foregroundStyle(.primary)
                        Spacer()
                        if opt.0 == selection {
                            Image(systemName: "checkmark").foregroundStyle(.accentColor)
                        }
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}

struct StringOptionSheet: View {
    let title: String
    let options: [(String, String)]
    @Binding var selection: String
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    var body: some View {
        NavigationStack {
            List {
                ForEach(options.filter { query.isEmpty || $0.1.localizedStandardContains(query) }, id: \.0) { opt in
                    Button {
                        selection = opt.0
                        dismiss()
                    } label: {
                        HStack {
                            Text(opt.1).foregroundStyle(.primary)
                            Spacer()
                            if opt.0 == selection {
                                Image(systemName: "checkmark").foregroundStyle(.accentColor)
                            }
                        }
                    }
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always))
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("完成") { dismiss() } }
            }
        }
    }
}

// MARK: - 标签多选

struct ChipRow: View {
    let title: String?
    let options: [(String, String)]
    @Binding var selection: [String]
    var exclusive: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title {
                Text(title).font(.subheadline)
            }
            FlowLayout(spacing: 8) {
                ForEach(options, id: \.0) { opt in
                    let on = selection.contains(opt.0)
                    Button {
                        toggle(opt.0)
                        UISelectionFeedbackGenerator().selectionChanged()
                    } label: {
                        Text(opt.1)
                            .font(.footnote.weight(on ? .semibold : .regular))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(on ? AnyShapeStyle(Color.accentColor.opacity(0.16))
                                          : AnyShapeStyle(Color(.tertiarySystemFill)),
                                        in: Capsule())
                            .overlay(Capsule().strokeBorder(on ? Color.accentColor.opacity(0.5)
                                                              : Color.clear, lineWidth: 1))
                            .foregroundStyle(on ? Color.accentColor : Color.primary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func toggle(_ key: String) {
        if let exclusive, key == exclusive, !selection.contains(key) {
            selection = [key]
            return
        }
        if selection.contains(key) {
            selection.removeAll { $0 == key }
        } else {
            if let exclusive { selection.removeAll { $0 == exclusive } }
            selection.append(key)
        }
    }
}

// MARK: - 年龄 / 毕业年份 特殊行

struct AgeRow: View {
    @Binding var value: Int

    var body: some View {
        HStack(spacing: 12) {
            Text("年龄").font(.subheadline)
            Spacer()
            Text("\(value) 岁")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.accentColor)
                .monospacedDigit()
            Stepper("", value: $value, in: 15...80)
                .labelsHidden()
        }
    }
}

struct GraduationRow: View {
    @Binding var value: Int?
    @State private var showSheet = false

    private let options: [(Int, String)] = [
        (-1, "还在读 / 尚未毕业"),
        (0, "今年刚毕业"),
        (2, "毕业 1–3 年"),
        (4, "毕业 3–5 年"),
        (7, "毕业 5–10 年"),
        (12, "毕业 10 年以上"),
    ]

    private var current: Int { value ?? -1 }
    private var label: String { options.first { $0.0 == current }?.1 ?? "—" }

    var body: some View {
        HStack(spacing: 12) {
            Text("毕业时间").font(.subheadline).frame(maxWidth: .infinity, alignment: .leading)
            Button { showSheet = true } label: {
                HStack(spacing: 4) {
                    Text(label).font(.subheadline.weight(.medium)).foregroundStyle(Color.accentColor)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10, weight: .semibold)).foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
        }
        .contentShape(Rectangle())
        .onTapGesture { showSheet = true }
        .sheet(isPresented: $showSheet) {
            NavigationStack {
                List(options, id: \.0) { opt in
                    Button {
                        value = opt.0 < 0 ? nil : opt.0
                        showSheet = false
                    } label: {
                        HStack {
                            Text(opt.1).foregroundStyle(.primary)
                            Spacer()
                            if opt.0 == current {
                                Image(systemName: "checkmark").foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                }
                .navigationTitle("毕业时间")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) { Button("完成") { showSheet = false } }
                }
            }
            .presentationDetents([.medium])
        }
    }
}

// MARK: - 自适应换行布局

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for sv in subviews {
            let size = sv.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth == .infinity ? x : maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for sv in subviews {
            let size = sv.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            sv.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// MARK: - 便利

extension ShapeStyle where Self == Color {
    static var accentColor: Color { .blue }
}
