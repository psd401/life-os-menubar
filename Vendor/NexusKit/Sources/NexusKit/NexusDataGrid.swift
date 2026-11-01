import SwiftUI

// MARK: - Model

public enum NexusCellValue: Sendable, Hashable {
    case text(String)
    case number(Double)
    case series([Double])
    case none

    public var number: Double? { if case .number(let v) = self { return v } else { return nil } }
    public var text: String? {
        switch self {
        case .text(let s): return s
        case .number(let v): return NexusFormat.number(v, decimals: 1)
        default: return nil
        }
    }
}

public struct NexusStatusStyle: Sendable {
    public enum Tone: Sendable { case ok, watch, alert, off }
    public var label: String
    public var tone: Tone
    public init(_ label: String, tone: Tone = .ok) { self.label = label; self.tone = tone }
}

public struct NexusGridColumn: Identifiable, Sendable {
    public enum Kind: Sendable { case text, number, percent, delta, bar, heat, spark, status }
    public enum Aggregate: Sendable { case none, sum, average, weighted(by: String) }

    public var key: String
    public var label: String
    public var kind: Kind
    public var width: CGFloat
    public var decimals: Int
    public var unit: String
    public var isPrivate: Bool
    public var aggregate: Aggregate
    public var definition: String?
    public var barMax: Double
    public var watchBelow: Double?
    public var heatSteps: [Double]
    public var goodUp: Bool
    public var statuses: [String: NexusStatusStyle]
    public var id: String { key }

    public init(_ key: String, _ label: String, kind: Kind = .text, width: CGFloat = 120, decimals: Int? = nil, unit: String = "",
                isPrivate: Bool = false, aggregate: Aggregate = .none, definition: String? = nil, barMax: Double = 100,
                watchBelow: Double? = nil, heatSteps: [Double] = [20, 40, 60, 80], goodUp: Bool = true, statuses: [String: NexusStatusStyle] = [:]) {
        self.key = key; self.label = label; self.kind = kind; self.width = width
        self.decimals = decimals ?? ((kind == .percent || kind == .delta || kind == .bar || kind == .heat) ? 1 : 0)
        self.unit = unit; self.isPrivate = isPrivate; self.aggregate = aggregate; self.definition = definition
        self.barMax = barMax; self.watchBelow = watchBelow; self.heatSteps = heatSteps; self.goodUp = goodUp; self.statuses = statuses
    }

    var isNumeric: Bool { kind == .number || kind == .percent || kind == .delta || kind == .bar || kind == .heat }

    func format(_ v: Double) -> String {
        NexusFormat.number(v, decimals: decimals) + (kind == .percent || kind == .bar || kind == .heat ? (unit.isEmpty ? "%" : unit) : unit)
    }
}

public struct NexusGridRow: Identifiable, Sendable {
    public var id: String
    public var n: Int?
    public var values: [String: NexusCellValue]
    public init(id: String, n: Int? = nil, values: [String: NexusCellValue]) { self.id = id; self.n = n; self.values = values }
    public subscript(key: String) -> NexusCellValue { values[key] ?? .none }
}

public enum NexusGridDensity: String, CaseIterable, Sendable {
    case compact = "Compact", regular = "Regular", comfortable = "Comfortable"
    var rowHeight: CGFloat { switch self { case .compact: return 32; case .regular: return 44; case .comfortable: return 56 } }
}

func nexusIsSuppressed(_ row: NexusGridRow, _ column: NexusGridColumn, threshold: Int?) -> Bool {
    guard column.isPrivate, let threshold, let n = row.n else { return false }
    return n < threshold
}

func nexusAggregate(_ rows: [NexusGridRow], _ c: NexusGridColumn) -> Double? {
    switch c.aggregate {
    case .none: return nil
    case .sum:
        let v = rows.compactMap { $0[c.key].number }
        return v.isEmpty ? nil : v.reduce(0, +)
    case .average:
        let v = rows.compactMap { $0[c.key].number }
        return v.isEmpty ? nil : v.reduce(0, +) / Double(v.count)
    case .weighted(let key):
        var total = 0.0, weight = 0.0
        for r in rows { if let v = r[c.key].number, let w = r[key].number { total += v * w; weight += w } }
        return weight > 0 ? total / weight : nil
    }
}

// MARK: - Cell

public struct NexusGridCell: View {
    @Environment(\.nexus) private var p
    let column: NexusGridColumn
    let row: NexusGridRow
    let suppressBelow: Int?

    public init(column: NexusGridColumn, row: NexusGridRow, suppressBelow: Int? = nil) { self.column = column; self.row = row; self.suppressBelow = suppressBelow }

    public var body: some View {
        if nexusIsSuppressed(row, column, threshold: suppressBelow) {
            Text("n<\(suppressBelow ?? 10)")
                .font(NexusFont.caption1).italic()
                .underline(pattern: .dot)
                .foregroundStyle(p.inkMuted)
                .help("Hidden: group under \(suppressBelow ?? 10) students")
                .accessibilityLabel("Hidden: group under \(suppressBelow ?? 10) students")
        } else {
            content
        }
    }

    @ViewBuilder private var content: some View {
        let value = row[column.key]
        switch column.kind {
        case .bar:
            if let v = value.number {
                HStack(spacing: 8) {
                    Text(column.format(v)).monospacedDigit()
                    ZStack(alignment: .leading) {
                        Capsule().fill(p.surfaceSunken)
                        Capsule().fill(column.watchBelow.map { v < $0 } == true ? p.chart3 : p.chart1)
                            .frame(width: 70 * max(0, min(1, v / column.barMax)))
                    }
                    .frame(width: 70, height: 8)
                }
            } else { Text("—").foregroundStyle(p.inkMuted) }
        case .heat:
            if let v = value.number {
                let step = column.heatSteps.filter { v >= $0 }.count
                Text(column.format(v)).monospacedDigit()
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(p.sequential(step), in: RoundedRectangle(cornerRadius: 6))
                    .foregroundStyle(step >= 4 ? p.surfaceRaised : p.ink)
                    .fontWeight(step >= 4 ? .semibold : .regular)
            } else { Text("—").foregroundStyle(p.inkMuted) }
        case .delta:
            if let v = value.number {
                let good = (v > 0) == column.goodUp
                let flat = abs(v) < 0.05
                Label(NexusFormat.signed(v, decimals: column.decimals, unit: column.unit), systemImage: flat ? "minus" : (v > 0 ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill"))
                    .labelStyle(.titleAndIcon)
                    .monospacedDigit()
                    .fontWeight(flat ? .regular : .semibold)
                    .foregroundStyle(flat ? p.inkMuted : (good ? p.successInk : p.attentionInk))
            } else { Text("—").foregroundStyle(p.inkMuted) }
        case .spark:
            if case .series(let values) = value, values.count > 1 {
                NexusSparkline(values: values).stroke(p.chart1, lineWidth: 1.6).frame(width: 72, height: 22)
                    .accessibilityLabel("Trend")
            } else { Text("—").foregroundStyle(p.inkMuted) }
        case .status:
            let key = value.text ?? ""
            let style = column.statuses[key] ?? NexusStatusStyle(key)
            HStack(spacing: 6) {
                Circle().fill(statusColor(style.tone)).frame(width: 8, height: 8)
                Text(style.label)
            }
        case .number, .percent:
            if let v = value.number { Text(column.format(v)).monospacedDigit() } else { Text("—").foregroundStyle(p.inkMuted) }
        case .text:
            Text(value.text ?? "—")
        }
    }

    private func statusColor(_ tone: NexusStatusStyle.Tone) -> Color {
        switch tone { case .ok: return p.success; case .watch: return p.attention; case .alert: return p.danger; case .off: return p.inkDisabled }
    }
}

public struct NexusSparkline: Shape {
    let values: [Double]
    public init(values: [Double]) { self.values = values }
    public func path(in rect: CGRect) -> Path {
        var path = Path()
        guard values.count > 1, let lo = values.min(), let hi = values.max() else { return path }
        let span = hi - lo == 0 ? 1 : hi - lo
        for (i, v) in values.enumerated() {
            let pt = CGPoint(x: rect.minX + CGFloat(i) / CGFloat(values.count - 1) * rect.width,
                             y: rect.maxY - 2 - CGFloat((v - lo) / span) * (rect.height - 4))
            if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
        }
        return path
    }
}

// MARK: - Data grid

/// The full Nexus data grid: search, sort, group with subtotals, totals, selection, density, export, suppression.
/// On compact width (iPhone) it shows `NexusDataCards` instead.
public struct NexusDataGrid: View {
    @Environment(\.nexus) private var p
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    #endif
    let title: String
    let source: String?
    let freshness: String?
    let stale: Bool
    let columns: [NexusGridColumn]
    let rows: [NexusGridRow]
    let suppressBelow: Int?
    let selectable: Bool
    let showTotals: Bool
    let totalsLabel: String
    let onAsk: (() -> Void)?

    @State private var sortKey: String?
    @State private var ascending = true
    @State private var search = ""
    @State private var groupBy: String?
    @State private var collapsed: Set<String> = []
    @State private var selection: Set<String> = []
    @State private var density: NexusGridDensity = .regular

    public init(title: String, source: String? = nil, freshness: String? = nil, stale: Bool = false, columns: [NexusGridColumn], rows: [NexusGridRow],
                suppressBelow: Int? = 10, selectable: Bool = false, showTotals: Bool = false, totalsLabel: String = "Total",
                sortKey: String? = nil, ascending: Bool = true, groupBy: String? = nil, onAsk: (() -> Void)? = nil) {
        self.title = title; self.source = source; self.freshness = freshness; self.stale = stale; self.columns = columns; self.rows = rows
        self.suppressBelow = suppressBelow; self.selectable = selectable; self.showTotals = showTotals; self.totalsLabel = totalsLabel; self.onAsk = onAsk
        self._sortKey = State(initialValue: sortKey); self._ascending = State(initialValue: ascending); self._groupBy = State(initialValue: groupBy)
    }

    private var visibleRows: [NexusGridRow] {
        var out = rows
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        if !q.isEmpty {
            out = out.filter { r in columns.contains { c in (r[c.key].text ?? "").lowercased().contains(q) } }
        }
        if let key = sortKey, let col = columns.first(where: { $0.key == key }) {
            out.sort { a, b in
                let sa = nexusIsSuppressed(a, col, threshold: suppressBelow), sb = nexusIsSuppressed(b, col, threshold: suppressBelow)
                if sa != sb { return sb }
                if let x = a[key].number, let y = b[key].number { return ascending ? x < y : x > y }
                let x = a[key].text ?? "", y = b[key].text ?? ""
                return ascending ? x < y : x > y
            }
        }
        return out
    }

    private var groups: [(key: String, rows: [NexusGridRow])] {
        guard let g = groupBy else { return [] }
        var order: [String] = []
        var dict: [String: [NexusGridRow]] = [:]
        for r in visibleRows {
            let k = r[g].text ?? "—"
            if dict[k] == nil { order.append(k) }
            dict[k, default: []].append(r)
        }
        return order.map { (key: $0, rows: dict[$0] ?? []) }
    }

    private var csv: String {
        func esc(_ s: String) -> String { s.contains(",") || s.contains("\"") ? "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\"" : s }
        let cols = columns.filter { $0.kind != .spark }
        var lines = [cols.map { esc($0.label) }.joined(separator: ",")]
        for r in visibleRows {
            lines.append(cols.map { c in
                if nexusIsSuppressed(r, c, threshold: suppressBelow) { return "suppressed" }
                return esc(r[c.key].text ?? "")
            }.joined(separator: ","))
        }
        return lines.joined(separator: "\n")
    }

    public var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            #if os(iOS)
            if sizeClass == .compact {
                ScrollView {
                    NexusDataCards(columns: columns, rows: visibleRows, titleKey: columns.first?.key ?? "", figureKey: sortKey, suppressBelow: suppressBelow)
                        .padding(12)
                }
            } else {
                table
            }
            #else
            table
            #endif
            footer
        }
        .background(p.surfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: NexusRadius.lg))
        .overlay(RoundedRectangle(cornerRadius: NexusRadius.lg).stroke(p.line, lineWidth: 1))
    }

    private var toolbar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(NexusFont.title3).foregroundStyle(p.ink)
                    HStack(spacing: 6) {
                        if let source { Text(source) }
                        if let freshness {
                            Circle().fill(stale ? p.attention : p.success).frame(width: 7, height: 7)
                            Text(freshness)
                        }
                        Text("\(visibleRows.count) rows")
                    }
                    .font(NexusFont.caption1).foregroundStyle(p.inkMuted)
                }
                Spacer(minLength: 12)
                if let onAsk {
                    Button("Ask about this table", systemImage: "sparkles", action: onAsk).buttonStyle(.bordered).tint(p.flowInk)
                }
            }
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass").foregroundStyle(p.inkMuted)
                    TextField("Search rows", text: $search).textFieldStyle(.plain)
                }
                .padding(.horizontal, 10).padding(.vertical, 6)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(p.lineStrong, lineWidth: 1))
                .frame(maxWidth: 220)
                Menu {
                    Picker("Density", selection: $density) {
                        ForEach(NexusGridDensity.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    Picker("Group by", selection: $groupBy) {
                        Text("No grouping").tag(String?.none)
                        ForEach(columns.filter { $0.kind == .text || $0.kind == .status }) { c in Text(c.label).tag(Optional(c.key)) }
                    }
                } label: {
                    Label("View", systemImage: "slider.horizontal.3")
                }
                .fixedSize()
                ShareLink(item: csv) {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                Spacer()
                if !selection.isEmpty {
                    Text("\(selection.count) selected").font(NexusFont.caption1.weight(.semibold))
                    Button("Clear") { selection.removeAll() }.buttonStyle(.borderless)
                }
            }
            .font(NexusFont.footnote)
        }
        .padding(12)
    }

    private var table: some View {
        ScrollView([.horizontal, .vertical]) {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                Section {
                    if groupBy != nil {
                        ForEach(groups, id: \.key) { g in
                            groupHeader(g.key, rows: g.rows)
                            if !collapsed.contains(g.key) {
                                ForEach(g.rows) { r in rowView(r) }
                            }
                        }
                    } else {
                        ForEach(visibleRows) { r in rowView(r) }
                    }
                    if showTotals { totalsRow }
                } header: {
                    headerRow
                }
            }
        }
    }

    private var headerRow: some View {
        HStack(spacing: 0) {
            if selectable {
                checkbox(visibleRows.allSatisfy { selection.contains($0.id) } && !visibleRows.isEmpty) {
                    if visibleRows.allSatisfy({ selection.contains($0.id) }) { selection.removeAll() } else { selection = Set(visibleRows.map(\.id)) }
                }
                .accessibilityLabel("Select all rows")
            }
            ForEach(columns) { c in
                Button {
                    if sortKey == c.key { ascending.toggle() } else { sortKey = c.key; ascending = true }
                } label: {
                    HStack(spacing: 4) {
                        Text(c.label)
                        if sortKey == c.key { Image(systemName: ascending ? "chevron.up" : "chevron.down").font(.caption2) }
                    }
                    .frame(width: c.width, alignment: c.isNumeric ? .trailing : .leading)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .help(c.definition ?? c.label)
                .contextMenu {
                    if let d = c.definition { Text(d) }
                    Button("Sort ascending") { sortKey = c.key; ascending = true }
                    Button("Sort descending") { sortKey = c.key; ascending = false }
                    Button(groupBy == c.key ? "Stop grouping" : "Group by \(c.label)") { groupBy = groupBy == c.key ? nil : c.key }
                }
                .accessibilityAddTraits(sortKey == c.key ? .isSelected : [])
                .accessibilityHint(sortKey == c.key ? (ascending ? "Sorted ascending" : "Sorted descending") : "Double-tap to sort")
            }
        }
        .font(NexusFont.caption1.weight(.semibold))
        .foregroundStyle(p.inkMuted)
        .frame(height: 40)
        .background(p.surfaceSunken)
        .overlay(alignment: .bottom) { Rectangle().fill(p.line).frame(height: 1) }
    }

    private func rowView(_ r: NexusGridRow) -> some View {
        let selected = selection.contains(r.id)
        return HStack(spacing: 0) {
            if selectable {
                checkbox(selected) { if selected { selection.remove(r.id) } else { selection.insert(r.id) } }
                    .accessibilityLabel("Select \(r[columns.first?.key ?? ""].text ?? r.id)")
            }
            ForEach(columns) { c in
                NexusGridCell(column: c, row: r, suppressBelow: suppressBelow)
                    .lineLimit(1)
                    .frame(width: c.width, alignment: c.isNumeric ? .trailing : .leading)
                    .padding(.horizontal, 12)
            }
        }
        .font(NexusFont.subheadline)
        .foregroundStyle(p.ink)
        .frame(height: density.rowHeight)
        .background(selected ? p.surfaceSelected : p.surfaceRaised)
        .overlay(alignment: .bottom) { Rectangle().fill(p.line).frame(height: 1) }
        .accessibilityElement(children: .combine)
    }

    private func groupHeader(_ key: String, rows: [NexusGridRow]) -> some View {
        let closed = collapsed.contains(key)
        return HStack(spacing: 0) {
            if selectable { Color.clear.frame(width: 40) }
            ForEach(Array(columns.enumerated()), id: \.element.id) { pair in
                let c = pair.element
                Group {
                    if pair.offset == 0 {
                        Button {
                            if closed { collapsed.remove(key) } else { collapsed.insert(key) }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: closed ? "chevron.right" : "chevron.down")
                                Text(key).fontWeight(.semibold)
                                Text("\(rows.count) rows").font(NexusFont.caption1).foregroundStyle(p.inkMuted)
                            }
                        }
                        .buttonStyle(.plain)
                    } else if let a = nexusAggregate(rows, c) {
                        Text(c.format(a)).fontWeight(.semibold).monospacedDigit()
                    } else {
                        Text("")
                    }
                }
                .frame(width: c.width, alignment: c.isNumeric ? .trailing : .leading)
                .padding(.horizontal, 12)
            }
        }
        .font(NexusFont.subheadline)
        .foregroundStyle(p.ink)
        .frame(height: 38)
        .background(p.surfaceSunken)
        .overlay(alignment: .bottom) { Rectangle().fill(p.line).frame(height: 1) }
    }

    private var totalsRow: some View {
        HStack(spacing: 0) {
            if selectable { Color.clear.frame(width: 40) }
            ForEach(Array(columns.enumerated()), id: \.element.id) { pair in
                let c = pair.element
                Group {
                    if pair.offset == 0 { Text(totalsLabel) } else if let a = nexusAggregate(visibleRows, c) { Text(c.format(a)).monospacedDigit() } else { Text("") }
                }
                .fontWeight(.semibold)
                .frame(width: c.width, alignment: c.isNumeric ? .trailing : .leading)
                .padding(.horizontal, 12)
            }
        }
        .font(NexusFont.subheadline)
        .foregroundStyle(p.ink)
        .frame(height: 42)
        .background(p.surfaceSunken)
        .overlay(alignment: .top) { Rectangle().fill(p.lineStrong).frame(height: 2) }
    }

    private var footer: some View {
        HStack {
            if let suppressBelow { Text("Groups under \(suppressBelow) students are hidden.") }
            Spacer()
            Text("\(visibleRows.count) of \(rows.count) rows")
        }
        .font(NexusFont.caption1)
        .foregroundStyle(p.inkMuted)
        .padding(.horizontal, 14).padding(.vertical, 8)
        .overlay(alignment: .top) { Rectangle().fill(p.line).frame(height: 1) }
    }

    private func checkbox(_ on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: on ? "checkmark.square.fill" : "square")
                .foregroundStyle(on ? p.accent : p.inkMuted)
                .frame(width: 40)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Mobile cards

public struct NexusDataCards: View {
    @Environment(\.nexus) private var p
    let columns: [NexusGridColumn]
    let rows: [NexusGridRow]
    let titleKey: String
    let figureKey: String?
    let suppressBelow: Int?

    public init(columns: [NexusGridColumn], rows: [NexusGridRow], titleKey: String, figureKey: String? = nil, suppressBelow: Int? = 10) {
        self.columns = columns; self.rows = rows; self.titleKey = titleKey; self.figureKey = figureKey; self.suppressBelow = suppressBelow
    }

    public var body: some View {
        LazyVStack(spacing: 10) {
            ForEach(rows) { r in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(r[titleKey].text ?? r.id).font(NexusFont.headline).foregroundStyle(p.ink)
                        Spacer()
                        if let fk = figureKey, let fc = columns.first(where: { $0.key == fk }) {
                            NexusGridCell(column: fc, row: r, suppressBelow: suppressBelow).font(NexusFont.title2)
                        }
                    }
                    Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
                        ForEach(columns.filter { $0.key != titleKey && $0.key != figureKey }) { c in
                            GridRow {
                                Text(c.label).font(NexusFont.caption1).foregroundStyle(p.inkMuted)
                                NexusGridCell(column: c, row: r, suppressBelow: suppressBelow).font(NexusFont.subheadline)
                            }
                        }
                    }
                }
                .padding(14)
                .background(p.surfaceRaised, in: RoundedRectangle(cornerRadius: 18))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(p.line))
                .accessibilityElement(children: .combine)
            }
        }
    }
}

// MARK: - Pivot

public struct NexusPivotTable: View {
    @Environment(\.nexus) private var p
    let title: String, subtitle: String?, rowKeys: [String], columnKeys: [String]
    let value: (String, String) -> Double?
    let n: (String, String) -> Int?
    let rowLabel: String, decimals: Int, heat: Bool, suppressBelow: Int?

    public init(title: String, subtitle: String? = nil, rowKeys: [String], columnKeys: [String], rowLabel: String,
                decimals: Int = 1, heat: Bool = true, suppressBelow: Int? = 10,
                value: @escaping (String, String) -> Double?, n: @escaping (String, String) -> Int? = { _, _ in nil }) {
        self.title = title; self.subtitle = subtitle; self.rowKeys = rowKeys; self.columnKeys = columnKeys; self.rowLabel = rowLabel
        self.decimals = decimals; self.heat = heat; self.suppressBelow = suppressBelow; self.value = value; self.n = n
    }

    public var body: some View {
        let all = rowKeys.flatMap { r in columnKeys.compactMap { value(r, $0) } }
        let lo = all.min() ?? 0, hi = all.max() ?? 1
        NexusPanel {
            NexusSectionHeader(title, subtitle: subtitle)
            ScrollView(.horizontal) {
                Grid(horizontalSpacing: 0, verticalSpacing: 0) {
                    GridRow {
                        Text(rowLabel).frame(width: 140, alignment: .leading)
                        ForEach(columnKeys, id: \.self) { c in Text(c).frame(width: 72, alignment: .trailing) }
                    }
                    .font(NexusFont.caption1.weight(.semibold)).foregroundStyle(p.inkMuted)
                    .frame(height: 36)
                    ForEach(rowKeys, id: \.self) { r in
                        Divider().gridCellUnsizedAxes(.horizontal)
                        GridRow {
                            Text(r).fontWeight(.semibold).frame(width: 140, alignment: .leading)
                            ForEach(columnKeys, id: \.self) { c in cell(r, c, lo: lo, hi: hi).frame(width: 72, alignment: .trailing) }
                        }
                        .font(NexusFont.subheadline).frame(height: 40)
                    }
                }
            }
        }
    }

    @ViewBuilder private func cell(_ r: String, _ c: String, lo: Double, hi: Double) -> some View {
        if let suppressBelow, let count = n(r, c), count < suppressBelow {
            Text("n<\(suppressBelow)").font(NexusFont.caption1).italic().foregroundStyle(p.inkMuted)
        } else if let v = value(r, c) {
            let step = min(4, Int((v - lo) / max(0.0001, hi - lo) * 5))
            Text(NexusFormat.number(v, decimals: decimals)).monospacedDigit()
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(heat ? p.sequential(step) : Color.clear, in: RoundedRectangle(cornerRadius: 6))
                .foregroundStyle(heat && step >= 4 ? p.surfaceRaised : p.ink)
        } else {
            Text("—").foregroundStyle(p.inkMuted)
        }
    }
}

// MARK: - Diff table

public struct NexusDiffRow: Identifiable, Sendable {
    public enum Op: Sendable { case change, add, remove }
    public var id: String
    public var op: Op
    public var values: [String]
    public var old: [Int: String]
    public init(id: String, op: Op = .change, values: [String], old: [Int: String] = [:]) { self.id = id; self.op = op; self.values = values; self.old = old }
}

public struct NexusDiffTable<Actions: View>: View {
    @Environment(\.nexus) private var p
    let title: String, subtitle: String?, headers: [String], rows: [NexusDiffRow], unchanged: Int
    let actions: Actions

    public init(title: String, subtitle: String? = nil, headers: [String], rows: [NexusDiffRow], unchanged: Int = 0, @ViewBuilder actions: () -> Actions) {
        self.title = title; self.subtitle = subtitle; self.headers = headers; self.rows = rows; self.unchanged = unchanged; self.actions = actions()
    }

    public var body: some View {
        NexusPanel {
            HStack(alignment: .top) { NexusSectionHeader(title, subtitle: subtitle); Spacer(); actions }
            HStack(spacing: 14) {
                legend(p.flow, "\(rows.filter { $0.op == .change }.count) changed")
                legend(p.success, "\(rows.filter { $0.op == .add }.count) added")
                legend(p.danger, "\(rows.filter { $0.op == .remove }.count) removed")
                Text("\(unchanged) unchanged, hidden").foregroundStyle(p.inkMuted)
            }
            .font(NexusFont.footnote)
            Grid(alignment: .leading, horizontalSpacing: 0, verticalSpacing: 0) {
                GridRow { ForEach(headers, id: \.self) { Text($0).padding(10) } }
                    .font(NexusFont.caption1.weight(.semibold)).foregroundStyle(p.inkMuted).background(p.surfaceSunken)
                ForEach(rows) { r in
                    GridRow {
                        ForEach(r.values.indices, id: \.self) { i in
                            HStack(spacing: 6) {
                                if let o = r.old[i] { Text(o).strikethrough().foregroundStyle(p.inkMuted) }
                                Text(r.values[i]).fontWeight(r.old[i] != nil ? .semibold : .regular).strikethrough(r.op == .remove)
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(r.old[i] != nil ? p.flowSoft : Color.clear)
                        }
                    }
                    .font(NexusFont.subheadline)
                    .foregroundStyle(r.op == .remove ? p.inkMuted : p.ink)
                    .background(r.op == .add ? p.successSoft.opacity(0.7) : r.op == .remove ? p.dangerSoft.opacity(0.6) : Color.clear)
                    .overlay(alignment: .leading) {
                        if r.op != .change { Rectangle().fill(r.op == .add ? p.success : p.danger).frame(width: 3) }
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(p.line))
        }
    }

    private func legend(_ c: Color, _ text: String) -> some View {
        HStack(spacing: 6) { RoundedRectangle(cornerRadius: 3).fill(c).frame(width: 10, height: 10); Text(text) }
    }
}

// MARK: - Column profile

public struct NexusColumnProfileItem: Identifiable, Sendable {
    public var name: String, type: String, missing: Double, distinct: Int?, top: [String], range: String?, histogram: [Double], warning: String?
    public var id: String { name }
    public init(name: String, type: String, missing: Double = 0, distinct: Int? = nil, top: [String] = [], range: String? = nil, histogram: [Double] = [], warning: String? = nil) {
        self.name = name; self.type = type; self.missing = missing; self.distinct = distinct; self.top = top; self.range = range; self.histogram = histogram; self.warning = warning
    }
}

public struct NexusColumnProfile: View {
    @Environment(\.nexus) private var p
    let title: String, subtitle: String?, columns: [NexusColumnProfileItem]
    public init(title: String, subtitle: String? = nil, columns: [NexusColumnProfileItem]) { self.title = title; self.subtitle = subtitle; self.columns = columns }

    public var body: some View {
        NexusPanel {
            NexusSectionHeader(title, subtitle: subtitle)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 10)], spacing: 10) {
                ForEach(columns) { c in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack { Text(c.name).font(NexusFont.subheadline.weight(.semibold)); Spacer(); Text(c.type).font(NexusFont.code).foregroundStyle(p.inkMuted) }
                        GeometryReader { geo in
                            HStack(spacing: 0) {
                                Rectangle().fill(p.chart1).frame(width: geo.size.width * (1 - c.missing))
                                Rectangle().fill(p.attention)
                            }
                        }
                        .frame(height: 6).clipShape(Capsule())
                        Text("\(Int(((1 - c.missing) * 100).rounded()))% filled" + (c.distinct.map { " · \($0) distinct" } ?? ""))
                        if !c.histogram.isEmpty {
                            HStack(alignment: .bottom, spacing: 2) {
                                ForEach(c.histogram.indices, id: \.self) { i in
                                    RoundedRectangle(cornerRadius: 2).fill(p.chart1.opacity(0.7)).frame(height: max(2, 34 * c.histogram[i]))
                                }
                            }
                            .frame(height: 34, alignment: .bottom)
                        }
                        if !c.top.isEmpty { Text("Top: " + c.top.joined(separator: ", ")) }
                        if let range = c.range { Text("Range " + range) }
                        if let w = c.warning { Label(w, systemImage: "exclamationmark.triangle.fill").foregroundStyle(p.attentionInk).fontWeight(.semibold) }
                    }
                    .font(NexusFont.caption1)
                    .foregroundStyle(p.inkMuted)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(p.line))
                }
            }
        }
    }
}
