import SwiftUI
import Charts

// MARK: - Data

public struct NexusLevelRow: Identifiable, Sendable {
    public var label: String
    public var n: Int?
    public var values: [Double]
    public var suppressed: Bool
    public var id: String { label }
    public init(label: String, n: Int? = nil, values: [Double], suppressed: Bool = false) {
        self.label = label; self.n = n; self.values = values; self.suppressed = suppressed
    }
}

public struct NexusGapRow: Identifiable, Sendable {
    public var label: String
    public var a: Double
    public var b: Double
    public var id: String { label }
    public init(label: String, a: Double, b: Double) { self.label = label; self.a = a; self.b = b }
}

public struct NexusSlopeItem: Identifiable, Sendable {
    public var label: String
    public var from: Double
    public var to: Double
    public var watch: Bool?
    public var id: String { label }
    public init(label: String, from: Double, to: Double, watch: Bool? = nil) { self.label = label; self.from = from; self.to = to; self.watch = watch }
}

public struct NexusScatterPoint: Identifiable, Sendable {
    public var label: String
    public var x: Double
    public var y: Double
    public var size: Double
    public var watch: Bool
    public var showLabel: Bool
    public var id: String { label }
    public init(label: String, x: Double, y: Double, size: Double = 60, watch: Bool = false, showLabel: Bool = false) {
        self.label = label; self.x = x; self.y = y; self.size = size; self.watch = watch; self.showLabel = showLabel
    }
}

public struct NexusBin: Identifiable, Sendable {
    public var from: Double
    public var to: Double
    public var count: Int
    public var id: Double { from }
    public init(from: Double, to: Double, count: Int) { self.from = from; self.to = to; self.count = count }
}

public struct NexusSeries: Identifiable, Sendable {
    public var label: String
    public var values: [Double]
    public var id: String { label }
    public init(label: String, values: [Double]) { self.label = label; self.values = values }
}

public struct NexusWaterfallStep: Identifiable, Sendable {
    public var label: String
    public var value: Double
    public var isTotal: Bool
    public var id: String { label }
    public init(_ label: String, _ value: Double, total: Bool = false) { self.label = label; self.value = value; self.isTotal = total }
}

public struct NexusBulletRow: Identifiable, Sendable {
    public var label: String
    public var sub: String?
    public var value: Double
    public var compare: Double?
    public var id: String { label }
    public init(label: String, sub: String? = nil, value: Double, compare: Double? = nil) {
        self.label = label; self.sub = sub; self.value = value; self.compare = compare
    }
}

// MARK: - Stacked bar (proficiency) / diverging (Likert)

public struct NexusStackedBarChart: View {
    public enum Mode: Sendable { case stacked, diverging }
    @Environment(\.nexus) private var p
    let title: String
    let subtitle: String?
    let rows: [NexusLevelRow]
    let levels: [String]
    let mode: Mode
    let goodFrom: Int
    let summaryLabel: String

    public init(title: String, subtitle: String? = nil, rows: [NexusLevelRow], levels: [String],
                mode: Mode = .stacked, goodFrom: Int = 2, summaryLabel: String = "Meets + exceeds") {
        self.title = title; self.subtitle = subtitle; self.rows = rows; self.levels = levels
        self.mode = mode; self.goodFrom = goodFrom; self.summaryLabel = summaryLabel
    }

    struct Segment: Identifiable {
        let row: String
        let level: Int
        let start: Double
        let end: Double
        var id: String { row + "-\(level)" }
    }

    private var segments: [Segment] {
        var out: [Segment] = []
        let mid = Double(levels.count) / 2
        for r in rows where !r.suppressed {
            let total = max(1, r.values.reduce(0, +))
            let pcts = r.values.map { $0 / total * 100 }
            var x: Double = 0
            if mode == .diverging {
                var left: Double = 0
                for (i, v) in pcts.enumerated() {
                    if Double(i) + 1 <= mid { left += v } else if Double(i) < mid { left += v / 2 }
                }
                x = -left
            }
            for (i, v) in pcts.enumerated() {
                out.append(Segment(row: r.label, level: i, start: x, end: x + v))
                x += v
            }
        }
        return out
    }

    private func summary(_ r: NexusLevelRow) -> Double {
        let total = max(1, r.values.reduce(0, +))
        return r.values.enumerated().filter { $0.offset >= goodFrom }.map(\.element).reduce(0, +) / total * 100
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            NexusSectionHeader(title, subtitle: subtitle)
            NexusLegend(levels.enumerated().map { (label: $0.element, color: p.ordinal($0.offset, of: levels.count)) })
            Chart {
                ForEach(segments) { s in
                    BarMark(xStart: .value("Start", s.start), xEnd: .value("End", s.end), y: .value("Group", s.row), height: .fixed(22))
                        .foregroundStyle(p.ordinal(s.level, of: levels.count))
                        .annotation(position: .overlay) {
                            if s.end - s.start >= 7 {
                                Text(NexusFormat.number(s.end - s.start))
                                    .font(NexusFont.caption2)
                                    .foregroundStyle(p.onOrdinal(s.level, of: levels.count))
                            }
                        }
                }
                ForEach(rows.filter(\.suppressed)) { r in
                    BarMark(xStart: .value("Start", mode == .diverging ? -50.0 : 0.0), xEnd: .value("End", mode == .diverging ? 50.0 : 100.0),
                            y: .value("Group", r.label), height: .fixed(22))
                        .foregroundStyle(p.surfaceSunken)
                        .annotation(position: .overlay, alignment: .leading) {
                            Text("Hidden: group under 10").font(NexusFont.caption1).foregroundStyle(p.inkMuted).padding(.leading, 8)
                        }
                }
                if mode == .diverging {
                    RuleMark(x: .value("Neutral", 0)).foregroundStyle(p.inkSubtle).lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                }
            }
            .chartXScale(domain: mode == .diverging ? -100.0...100.0 : 0.0...100.0)
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        if let label = value.as(String.self) {
                            Text(label).font(NexusFont.footnote).foregroundStyle(p.ink)
                        }
                    }
                }
            }
            .frame(height: CGFloat(rows.count) * 34 + 8)
            .overlay(alignment: .trailing) {
                VStack(alignment: .trailing, spacing: 0) {
                    ForEach(rows) { r in
                        Text(r.suppressed ? "" : NexusFormat.number(summary(r)) + "%")
                            .font(NexusFont.footnote.weight(.semibold))
                            .foregroundStyle(p.ink)
                            .frame(height: 34)
                    }
                }
                .padding(.vertical, 4)
                .offset(x: 46)
            }
            .padding(.trailing, 50)
            Text(summaryLabel).font(NexusFont.caption1).foregroundStyle(p.inkMuted).frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
}

// MARK: - Dumbbell (gaps)

public struct NexusDumbbellChart: View {
    @Environment(\.nexus) private var p
    let title: String, subtitle: String?, rows: [NexusGapRow], aLabel: String, bLabel: String
    let domain: ClosedRange<Double>, unit: String, watchAbove: Double

    public init(title: String, subtitle: String? = nil, rows: [NexusGapRow], aLabel: String, bLabel: String,
                domain: ClosedRange<Double>, unit: String = " pts", watchAbove: Double = 10) {
        self.title = title; self.subtitle = subtitle; self.rows = rows; self.aLabel = aLabel; self.bLabel = bLabel
        self.domain = domain; self.unit = unit; self.watchAbove = watchAbove
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            NexusSectionHeader(title, subtitle: subtitle)
            NexusLegend([(aLabel, p.chart4), (bLabel, p.chart1)])
            Chart {
                ForEach(rows) { r in
                    let watch = abs(r.a - r.b) >= watchAbove
                    RuleMark(xStart: .value(aLabel, r.a), xEnd: .value(bLabel, r.b), y: .value("Group", r.label))
                        .foregroundStyle(watch ? p.chart3 : p.lineStrong)
                        .lineStyle(StrokeStyle(lineWidth: watch ? 2.5 : 2))
                    PointMark(x: .value(aLabel, r.a), y: .value("Group", r.label))
                        .symbol {
                            Circle().strokeBorder(p.chart4, lineWidth: 2.5).background(Circle().fill(p.surfaceRaised)).frame(width: 12, height: 12)
                        }
                    PointMark(x: .value(bLabel, r.b), y: .value("Group", r.label))
                        .foregroundStyle(p.chart1)
                        .symbolSize(110)
                        .annotation(position: .trailing, spacing: 12) {
                            Text(NexusFormat.signed(r.a - r.b, decimals: 1, unit: unit))
                                .font(NexusFont.caption1.weight(watch ? .bold : .regular))
                                .foregroundStyle(watch ? p.ink : p.inkMuted)
                        }
                }
            }
            .chartXScale(domain: domain)
            .frame(height: CGFloat(rows.count) * 34 + 30)
            .accessibilityLabel(title)
        }
    }
}

// MARK: - Slope

public struct NexusSlopeChart: View {
    @Environment(\.nexus) private var p
    let title: String, subtitle: String?, items: [NexusSlopeItem], fromLabel: String, toLabel: String, domain: ClosedRange<Double>

    public init(title: String, subtitle: String? = nil, items: [NexusSlopeItem], fromLabel: String, toLabel: String, domain: ClosedRange<Double>) {
        self.title = title; self.subtitle = subtitle; self.items = items; self.fromLabel = fromLabel; self.toLabel = toLabel; self.domain = domain
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            NexusSectionHeader(title, subtitle: subtitle)
            Chart {
                ForEach(items) { it in
                    let watch = it.watch ?? (it.to < it.from)
                    let color = watch ? p.chart3 : p.chart1
                    LineMark(x: .value("When", fromLabel), y: .value("Value", it.from), series: .value("Item", it.label))
                        .foregroundStyle(color)
                        .lineStyle(StrokeStyle(lineWidth: watch ? 2.5 : 2))
                    LineMark(x: .value("When", toLabel), y: .value("Value", it.to), series: .value("Item", it.label))
                        .foregroundStyle(color)
                        .lineStyle(StrokeStyle(lineWidth: watch ? 2.5 : 2))
                    PointMark(x: .value("When", fromLabel), y: .value("Value", it.from))
                        .foregroundStyle(color)
                        .annotation(position: .leading) {
                            Text("\(it.label)  \(NexusFormat.number(it.from, decimals: 1))")
                                .font(NexusFont.caption1.weight(watch ? .semibold : .regular)).foregroundStyle(p.ink)
                        }
                    PointMark(x: .value("When", toLabel), y: .value("Value", it.to))
                        .foregroundStyle(color)
                        .annotation(position: .trailing) {
                            Text("\(NexusFormat.number(it.to, decimals: 1))  \(NexusFormat.signed(it.to - it.from, decimals: 1))")
                                .font(NexusFont.caption1.weight(watch ? .semibold : .regular)).foregroundStyle(p.ink)
                        }
                }
            }
            .chartYScale(domain: domain)
            .chartYAxis(.hidden)
            .chartXScale(range: .plotDimension(startPadding: 150, endPadding: 110))
            .frame(height: 300)
        }
    }
}

// MARK: - Scatter with quadrants

public struct NexusScatterQuadrant: View {
    @Environment(\.nexus) private var p
    let title: String, subtitle: String?, points: [NexusScatterPoint]
    let xLabel: String, yLabel: String, xDomain: ClosedRange<Double>, yDomain: ClosedRange<Double>, xMid: Double, yMid: Double
    let quadrants: (topLeft: String, topRight: String, bottomLeft: String, bottomRight: String)?

    public init(title: String, subtitle: String? = nil, points: [NexusScatterPoint], xLabel: String, yLabel: String,
                xDomain: ClosedRange<Double>, yDomain: ClosedRange<Double>, xMid: Double, yMid: Double,
                quadrants: (topLeft: String, topRight: String, bottomLeft: String, bottomRight: String)? = nil) {
        self.title = title; self.subtitle = subtitle; self.points = points; self.xLabel = xLabel; self.yLabel = yLabel
        self.xDomain = xDomain; self.yDomain = yDomain; self.xMid = xMid; self.yMid = yMid; self.quadrants = quadrants
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            NexusSectionHeader(title, subtitle: subtitle)
            Chart {
                RectangleMark(xStart: .value("x", xDomain.lowerBound), xEnd: .value("x", xMid), yStart: .value("y", yDomain.lowerBound), yEnd: .value("y", yMid))
                    .foregroundStyle(p.chart3.opacity(0.08))
                    .annotation(position: .overlay, alignment: .bottomLeading) { quadLabel(quadrants?.bottomLeft) }
                RectangleMark(xStart: .value("x", xMid), xEnd: .value("x", xDomain.upperBound), yStart: .value("y", yMid), yEnd: .value("y", yDomain.upperBound))
                    .foregroundStyle(p.chart1.opacity(0.05))
                    .annotation(position: .overlay, alignment: .topTrailing) { quadLabel(quadrants?.topRight) }
                RectangleMark(xStart: .value("x", xDomain.lowerBound), xEnd: .value("x", xMid), yStart: .value("y", yMid), yEnd: .value("y", yDomain.upperBound))
                    .foregroundStyle(p.chart1.opacity(0.05))
                    .annotation(position: .overlay, alignment: .topLeading) { quadLabel(quadrants?.topLeft) }
                RectangleMark(xStart: .value("x", xMid), xEnd: .value("x", xDomain.upperBound), yStart: .value("y", yDomain.lowerBound), yEnd: .value("y", yMid))
                    .foregroundStyle(p.chart1.opacity(0.05))
                    .annotation(position: .overlay, alignment: .bottomTrailing) { quadLabel(quadrants?.bottomRight) }
                RuleMark(x: .value("Mid", xMid)).foregroundStyle(p.inkSubtle).lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                RuleMark(y: .value("Mid", yMid)).foregroundStyle(p.inkSubtle).lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                ForEach(points) { pt in
                    PointMark(x: .value(xLabel, pt.x), y: .value(yLabel, pt.y))
                        .symbolSize(pt.size)
                        .foregroundStyle(pt.watch ? p.chart3 : p.chart1.opacity(0.7))
                        .annotation(position: .trailing) {
                            if pt.showLabel { Text(pt.label).font(NexusFont.caption1).foregroundStyle(p.ink) }
                        }
                        .accessibilityLabel(pt.label)
                        .accessibilityValue("\(xLabel) \(NexusFormat.number(pt.x)), \(yLabel) \(NexusFormat.number(pt.y))")
                }
            }
            .chartXScale(domain: xDomain)
            .chartYScale(domain: yDomain)
            .chartXAxisLabel(xLabel, alignment: .center)
            .chartYAxisLabel(yLabel)
            .frame(height: 360)
        }
    }

    @ViewBuilder private func quadLabel(_ text: String?) -> some View {
        if let text {
            Text(text.uppercased()).font(NexusFont.caption2).tracking(0.6).foregroundStyle(p.inkMuted).padding(6)
        }
    }
}

// MARK: - Histogram

public struct NexusHistogram: View {
    @Environment(\.nexus) private var p
    let title: String, subtitle: String?, bins: [NexusBin], cut: Double?, cutLabel: String?, xLabel: String

    public init(title: String, subtitle: String? = nil, bins: [NexusBin], cut: Double? = nil, cutLabel: String? = nil, xLabel: String = "") {
        self.title = title; self.subtitle = subtitle; self.bins = bins; self.cut = cut; self.cutLabel = cutLabel; self.xLabel = xLabel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            NexusSectionHeader(title, subtitle: subtitle)
            Chart {
                ForEach(bins) { b in
                    BarMark(xStart: .value("From", b.from), xEnd: .value("To", b.to), y: .value("Students", b.count))
                        .foregroundStyle((cut.map { b.from >= $0 } ?? true) ? p.chart1 : p.chart4)
                        .cornerRadius(2)
                }
                if let cut {
                    RuleMark(x: .value("Cut", cut))
                        .foregroundStyle(p.ink)
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                        .annotation(position: .top, alignment: .trailing) {
                            if let cutLabel { Text(cutLabel).font(NexusFont.caption1.weight(.semibold)).foregroundStyle(p.ink) }
                        }
                }
            }
            .chartXAxisLabel(xLabel, alignment: .center)
            .frame(height: 220)
        }
    }
}

// MARK: - Calendar heatmap

public struct NexusCalendarDay: Sendable {
    public var date: Date
    public var value: Double?
    public var off: Bool
    public var note: String?
    public init(date: Date, value: Double? = nil, off: Bool = false, note: String? = nil) {
        self.date = date; self.value = value; self.off = off; self.note = note
    }
}

public struct NexusCalendarHeatmap: View {
    @Environment(\.nexus) private var p
    let title: String, subtitle: String?, start: Date, weeks: Int, days: [NexusCalendarDay], cell: CGFloat
    let step: @Sendable (Double) -> Int
    let stepLabels: [String]

    public init(title: String, subtitle: String? = nil, start: Date, weeks: Int, days: [NexusCalendarDay], cell: CGFloat = 16,
                stepLabels: [String] = ["< 90%", "90–92", "92–94", "94–96", "≥ 96%"],
                step: @escaping @Sendable (Double) -> Int = { v in v >= 96 ? 4 : v >= 94 ? 3 : v >= 92 ? 2 : v >= 90 ? 1 : 0 }) {
        self.title = title; self.subtitle = subtitle; self.start = start; self.weeks = weeks; self.days = days
        self.cell = cell; self.step = step; self.stepLabels = stepLabels
    }

    private var byDay: [DateComponents: NexusCalendarDay] {
        var out: [DateComponents: NexusCalendarDay] = [:]
        for d in days { out[Calendar.current.dateComponents([.year, .month, .day], from: d.date)] = d }
        return out
    }

    public var body: some View {
        let lookup = byDay
        let cal = Calendar.current
        VStack(alignment: .leading, spacing: 10) {
            NexusSectionHeader(title, subtitle: subtitle)
            NexusLegend(stepLabels.enumerated().map { (label: $0.element, color: p.sequential($0.offset)) } + [(label: "No school", color: p.surfaceSunken)])
            HStack(alignment: .top, spacing: 3) {
                VStack(spacing: 3) {
                    ForEach(["M", "T", "W", "T", "F"].indices, id: \.self) { i in
                        Text(["M", "T", "W", "T", "F"][i]).font(NexusFont.caption2).foregroundStyle(p.inkMuted).frame(width: 14, height: cell)
                    }
                }
                ForEach(0..<weeks, id: \.self) { w in
                    VStack(spacing: 3) {
                        ForEach(0..<5, id: \.self) { d in
                            let date = cal.date(byAdding: .day, value: w * 7 + d, to: start) ?? start
                            let entry = lookup[cal.dateComponents([.year, .month, .day], from: date)]
                            cellView(entry)
                                .accessibilityLabel(date.formatted(date: .abbreviated, time: .omitted))
                                .accessibilityValue(entry.map { $0.off ? ($0.note ?? "No school") : NexusFormat.number($0.value ?? 0, decimals: 1) + "%" } ?? "")
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder private func cellView(_ entry: NexusCalendarDay?) -> some View {
        let shape = RoundedRectangle(cornerRadius: 3)
        if let entry, entry.off {
            shape.fill(p.surfaceSunken)
                .overlay(NexusHatch(spacing: 4).stroke(p.lineStrong, lineWidth: 0.7).clipShape(shape))
                .frame(width: cell, height: cell)
        } else if let entry, let v = entry.value {
            shape.fill(p.sequential(step(v))).frame(width: cell, height: cell)
        } else {
            shape.fill(p.surfaceSunken).frame(width: cell, height: cell)
        }
    }
}

// MARK: - Stacked area

public struct NexusStackedAreaChart: View {
    @Environment(\.nexus) private var p
    let title: String, subtitle: String?, series: [NexusSeries], xLabels: [String]

    public init(title: String, subtitle: String? = nil, series: [NexusSeries], xLabels: [String]) {
        self.title = title; self.subtitle = subtitle; self.series = series; self.xLabels = xLabels
    }

    public var body: some View {
        let colors: [Color] = [p.chart1, p.chart2, p.chart6, p.chart5, p.chart3]
        VStack(alignment: .leading, spacing: 10) {
            NexusSectionHeader(title, subtitle: subtitle)
            Chart {
                ForEach(series) { s in
                    ForEach(Array(s.values.enumerated()), id: \.offset) { pair in
                        AreaMark(x: .value("Period", xLabels[min(pair.offset, xLabels.count - 1)]), y: .value("Count", pair.element), stacking: .standard)
                            .foregroundStyle(by: .value("Series", s.label))
                    }
                }
            }
            .chartForegroundStyleScale(domain: series.map(\.label), range: Array(colors.prefix(series.count)))
            .chartLegend(position: .bottom, alignment: .leading)
            .frame(height: 240)
        }
    }
}

// MARK: - Waterfall

public struct NexusWaterfallChart: View {
    @Environment(\.nexus) private var p
    let title: String, subtitle: String?, steps: [NexusWaterfallStep], domain: ClosedRange<Double>

    public init(title: String, subtitle: String? = nil, steps: [NexusWaterfallStep], domain: ClosedRange<Double>) {
        self.title = title; self.subtitle = subtitle; self.steps = steps; self.domain = domain
    }

    struct Bar: Identifiable { let step: NexusWaterfallStep; let y0: Double; let y1: Double; var id: String { step.id } }

    private var bars: [Bar] {
        var run = 0.0
        return steps.map { s in
            if s.isTotal { run = s.value; return Bar(step: s, y0: domain.lowerBound, y1: s.value) }
            let b = Bar(step: s, y0: run, y1: run + s.value); run += s.value; return b
        }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            NexusSectionHeader(title, subtitle: subtitle)
            Chart {
                ForEach(bars) { b in
                    BarMark(x: .value("Step", b.step.label), yStart: .value("From", b.y0), yEnd: .value("To", b.y1), width: .ratio(0.6))
                        .foregroundStyle(b.step.isTotal ? p.chart4 : (b.step.value >= 0 ? p.chart1 : p.chart3))
                        .cornerRadius(2)
                        .annotation(position: .top) {
                            Text(b.step.isTotal ? NexusFormat.number(b.step.value) : NexusFormat.signed(b.step.value, decimals: 0))
                                .font(NexusFont.caption1.weight(b.step.isTotal ? .semibold : .regular))
                                .foregroundStyle(p.ink)
                        }
                }
            }
            .chartYScale(domain: domain)
            .frame(height: 240)
        }
    }
}

// MARK: - Bullet

public struct NexusBulletChart: View {
    @Environment(\.nexus) private var p
    let title: String, subtitle: String?, rows: [NexusBulletRow], bands: [Double], domain: ClosedRange<Double>, unit: String
    let valueLabel: String, compareLabel: String

    public init(title: String, subtitle: String? = nil, rows: [NexusBulletRow], bands: [Double], domain: ClosedRange<Double>,
                unit: String = "%", valueLabel: String = "This year", compareLabel: String = "Last year") {
        self.title = title; self.subtitle = subtitle; self.rows = rows; self.bands = bands; self.domain = domain
        self.unit = unit; self.valueLabel = valueLabel; self.compareLabel = compareLabel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            NexusSectionHeader(title, subtitle: subtitle)
            NexusLegend([(valueLabel, p.ink), (compareLabel, p.chart3)])
            ForEach(rows) { r in
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(r.label).font(NexusFont.subheadline).foregroundStyle(p.ink)
                        if let sub = r.sub { Text(sub).font(NexusFont.caption1).foregroundStyle(p.inkMuted) }
                    }
                    .frame(width: 130, alignment: .leading)
                    GeometryReader { geo in
                        let w = geo.size.width
                        let x: (Double) -> CGFloat = { v in CGFloat((v - domain.lowerBound) / (domain.upperBound - domain.lowerBound)) * w }
                        ZStack(alignment: .leading) {
                            ForEach(Array(bands.enumerated()), id: \.offset) { pair in
                                let lower = pair.offset == 0 ? domain.lowerBound : bands[pair.offset - 1]
                                Rectangle().fill(p.chart4.mix(with: p.surfaceRaised, by: 0.82 - Double(pair.offset) * 0.15))
                                    .frame(width: max(0, x(pair.element) - x(lower)), height: 26)
                                    .offset(x: x(lower))
                            }
                            RoundedRectangle(cornerRadius: 2).fill(p.ink).frame(width: max(0, x(r.value)), height: 10)
                            if let c = r.compare {
                                Rectangle().fill(p.chart3).frame(width: 3, height: 30).offset(x: x(c) - 1.5)
                            }
                        }
                        .frame(height: 30)
                    }
                    .frame(height: 30)
                    Text(NexusFormat.number(r.value, decimals: 1) + unit)
                        .font(NexusFont.subheadline.weight(.semibold)).foregroundStyle(p.ink)
                        .frame(width: 56, alignment: .trailing)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(r.label)
                .accessibilityValue("\(NexusFormat.number(r.value, decimals: 1))\(unit)" + (r.compare.map { ", \(compareLabel) \(NexusFormat.number($0, decimals: 1))\(unit)" } ?? ""))
            }
        }
    }
}

// MARK: - School map (illustrative regions + schools)

public struct NexusMapRegion: Identifiable, Sendable {
    public var id: String
    public var label: String
    public var points: [CGPoint]
    public var value: Double?
    public init(id: String, label: String, points: [CGPoint], value: Double?) { self.id = id; self.label = label; self.points = points; self.value = value }
}

public struct NexusMapSchool: Identifiable, Sendable {
    public enum Kind: Sendable { case elementary, middle, high }
    public var label: String
    public var position: CGPoint
    public var kind: Kind
    public var watch: Bool
    public var id: String { label }
    public init(label: String, position: CGPoint, kind: Kind, watch: Bool = false) { self.label = label; self.position = position; self.kind = kind; self.watch = watch }
}

struct NexusPolygon: Shape {
    let points: [CGPoint]
    let design: CGSize
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width / design.width, rect.height / design.height)
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: CGPoint(x: first.x * s, y: first.y * s))
        for pt in points.dropFirst() { path.addLine(to: CGPoint(x: pt.x * s, y: pt.y * s)) }
        path.closeSubpath()
        return path
    }
}

public struct NexusSchoolMap: View {
    @Environment(\.nexus) private var p
    let title: String, subtitle: String?, regions: [NexusMapRegion], schools: [NexusMapSchool], design: CGSize
    let step: @Sendable (Double) -> Int
    let stepLabels: [String]

    public init(title: String, subtitle: String? = nil, regions: [NexusMapRegion], schools: [NexusMapSchool], design: CGSize = CGSize(width: 600, height: 410),
                stepLabels: [String] = ["< 90%", "90–92", "92–94", "94–95", "≥ 95%"],
                step: @escaping @Sendable (Double) -> Int = { v in v >= 95 ? 4 : v >= 94 ? 3 : v >= 92 ? 2 : v >= 90 ? 1 : 0 }) {
        self.title = title; self.subtitle = subtitle; self.regions = regions; self.schools = schools; self.design = design
        self.step = step; self.stepLabels = stepLabels
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            NexusSectionHeader(title, subtitle: subtitle)
            NexusLegend(stepLabels.enumerated().map { (label: $0.element, color: p.sequential($0.offset)) })
            GeometryReader { geo in
                let s = min(geo.size.width / design.width, geo.size.height / design.height)
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 12).fill(p.chart2.mix(with: p.surfaceCanvas, by: 0.86))
                    ForEach(regions) { r in
                        NexusPolygon(points: r.points, design: design)
                            .fill(r.value.map { p.sequential(step($0)) } ?? p.surfaceSunken)
                            .overlay(NexusPolygon(points: r.points, design: design).stroke(p.surfaceRaised, lineWidth: 2))
                            .accessibilityLabel(r.label)
                            .accessibilityValue(r.value.map { NexusFormat.number($0, decimals: 1) + "%" } ?? "No data")
                    }
                    ForEach(schools) { sc in
                        HStack(spacing: 4) {
                            schoolMark(sc)
                            Text(sc.label).font(NexusFont.caption1.weight(sc.watch ? .semibold : .regular)).foregroundStyle(p.ink)
                                .padding(.horizontal, 3).background(p.surfaceRaised.opacity(0.75), in: RoundedRectangle(cornerRadius: 3))
                        }
                        .fixedSize()
                        .position(x: sc.position.x * s + 50, y: sc.position.y * s)
                    }
                }
            }
            .aspectRatio(design.width / design.height, contentMode: .fit)
            Text("Illustrative boundaries, not to scale").font(NexusFont.caption2).foregroundStyle(p.inkMuted)
        }
    }

    @ViewBuilder private func schoolMark(_ sc: NexusMapSchool) -> some View {
        let stroke = sc.watch ? p.chart3 : p.ink
        switch sc.kind {
        case .elementary: Circle().fill(p.surfaceRaised).overlay(Circle().stroke(stroke, lineWidth: sc.watch ? 3 : 2)).frame(width: 12, height: 12)
        case .middle: Image(systemName: "triangle").font(.system(size: 12, weight: .bold)).foregroundStyle(stroke)
        case .high: RoundedRectangle(cornerRadius: 2).fill(p.surfaceRaised).overlay(RoundedRectangle(cornerRadius: 2).stroke(stroke, lineWidth: sc.watch ? 3 : 2)).frame(width: 12, height: 12)
        }
    }
}
