import SwiftUI

// MARK: - Color ramps (mirror the web --ord-* and --seq-* tokens)

public extension NexusPalette {
    /// Ordinal ramp for ordered levels (proficiency, Likert). Low → high.
    func ordinal(_ index: Int, of count: Int) -> Color {
        let four: [Color] = [
            attention.mix(with: ink, by: 0.22),
            attention.mix(with: surfaceRaised, by: 0.58),
            chart1.mix(with: surfaceRaised, by: 0.55),
            chart1.mix(with: ink, by: 0.26),
        ]
        if count == 5 {
            let five: [Color] = [four[0], four[1], chart4.mix(with: surfaceRaised, by: 0.6), four[2], four[3]]
            return five[max(0, min(4, index))]
        }
        return four[max(0, min(3, index))]
    }
    /// Text color that reads on `ordinal(index, of:)`.
    func onOrdinal(_ index: Int, of count: Int) -> Color {
        let isEnd = index == 0 || index == count - 1
        return isEnd ? surfaceRaised : ink
    }
    /// Five sequential steps of chart-1 (0 = faint, 4 = strongest).
    func sequential(_ step: Int) -> Color {
        switch max(0, min(4, step)) {
        case 0: return chart1.mix(with: surfaceRaised, by: 0.90)
        case 1: return chart1.mix(with: surfaceRaised, by: 0.72)
        case 2: return chart1.mix(with: surfaceRaised, by: 0.50)
        case 3: return chart1.mix(with: surfaceRaised, by: 0.26)
        default: return chart1.mix(with: ink, by: 0.26)
        }
    }
}

// MARK: - Shared building blocks

/// A wrapping row layout for chips and tokens.
public struct NexusFlowLayout: Layout {
    public var spacing: CGFloat
    public init(spacing: CGFloat = 6) { self.spacing = spacing }

    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, widest: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > maxWidth { x = 0; y += rowHeight + spacing; rowHeight = 0 }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            widest = max(widest, x - spacing)
        }
        return CGSize(width: min(widest, maxWidth), height: y + rowHeight)
    }

    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX { x = bounds.minX; y += rowHeight + spacing; rowHeight = 0 }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

/// A rounded panel on paper (not glass).
public struct NexusPanel<Content: View>: View {
    @Environment(\.nexus) private var p
    let content: Content
    public init(@ViewBuilder content: () -> Content) { self.content = content() }
    public var body: some View {
        VStack(alignment: .leading, spacing: 14) { content }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(p.surfaceRaised, in: RoundedRectangle(cornerRadius: NexusRadius.lg))
            .overlay(RoundedRectangle(cornerRadius: NexusRadius.lg).stroke(p.line, lineWidth: 1))
    }
}

/// Title + subtitle above a chart or table.
public struct NexusSectionHeader: View {
    @Environment(\.nexus) private var p
    let title: String
    let subtitle: String?
    public init(_ title: String, subtitle: String? = nil) { self.title = title; self.subtitle = subtitle }
    public var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(NexusFont.title2).foregroundStyle(p.ink)
            if let subtitle { Text(subtitle).font(NexusFont.footnote).foregroundStyle(p.inkMuted) }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

/// Legend swatches.
public struct NexusLegend: View {
    @Environment(\.nexus) private var p
    let items: [(label: String, color: Color)]
    public init(_ items: [(label: String, color: Color)]) { self.items = items }
    public var body: some View {
        NexusFlowLayout(spacing: 14) {
            ForEach(Array(items.enumerated()), id: \.offset) { pair in
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 3).fill(pair.element.color).frame(width: 12, height: 12)
                    Text(pair.element.label).font(NexusFont.caption1).foregroundStyle(p.inkMuted)
                }
            }
        }
    }
}

/// What a step or tool touches.
public enum NexusScopeKind: Sendable { case read, write, neutral }

public struct NexusScopeChip: View {
    @Environment(\.nexus) private var p
    let kind: NexusScopeKind
    let label: String
    public init(_ label: String, kind: NexusScopeKind = .neutral) { self.label = label; self.kind = kind }
    public var body: some View {
        HStack(spacing: 4) {
            if kind == .read { Image(systemName: "eye") }
            if kind == .write { Image(systemName: "pencil") }
            Text(label)
        }
        .font(NexusFont.caption2)
        .padding(.horizontal, 8).padding(.vertical, 3)
        .foregroundStyle(kind == .read ? p.successInk : kind == .write ? p.attentionInk : p.inkMuted)
        .background(kind == .read ? p.successSoft : kind == .write ? p.attentionSoft : p.surfaceSunken, in: Capsule())
    }
}

/// Small status badge.
public struct NexusBadge: View {
    @Environment(\.nexus) private var p
    public enum Tone: Sendable { case info, flow, success, attention, danger, neutral }
    let text: String
    let tone: Tone
    public init(_ text: String, tone: Tone = .neutral) { self.text = text; self.tone = tone }
    public var body: some View {
        let colors: (Color, Color) = {
            switch tone {
            case .info: return (p.infoInk, p.infoSoft)
            case .flow: return (p.flowInk, p.flowSoft)
            case .success: return (p.successInk, p.successSoft)
            case .attention: return (p.attentionInk, p.attentionSoft)
            case .danger: return (p.dangerInk, p.dangerSoft)
            case .neutral: return (p.inkMuted, p.surfaceSunken)
            }
        }()
        Text(text).font(NexusFont.caption2)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .foregroundStyle(colors.0)
            .background(colors.1, in: Capsule())
    }
}

/// Diagonal hatching for "no data" and "no school" cells.
public struct NexusHatch: Shape {
    public var spacing: CGFloat
    public init(spacing: CGFloat = 5) { self.spacing = spacing }
    public func path(in rect: CGRect) -> Path {
        var path = Path()
        var x = rect.minX - rect.height
        while x < rect.maxX {
            path.move(to: CGPoint(x: x, y: rect.maxY))
            path.addLine(to: CGPoint(x: x + rect.height, y: rect.minY))
            x += spacing
        }
        return path
    }
}

/// The Nexus three-dot mark.
public struct NexusMark: Shape {
    public init() {}
    public func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 24
        var path = Path()
        func dot(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat) {
            path.addEllipse(in: CGRect(x: rect.minX + (x - r) * s, y: rect.minY + (y - r) * s, width: 2 * r * s, height: 2 * r * s))
        }
        dot(8, 8, 3.2); dot(16.5, 10, 2.6); dot(9.5, 16.5, 2.6)
        return path
    }
}

/// Number formatting used across charts and tables.
public enum NexusFormat {
    public static func number(_ value: Double, decimals: Int = 0) -> String {
        value.formatted(.number.precision(.fractionLength(decimals)))
    }
    public static func signed(_ value: Double, decimals: Int = 1, unit: String = "") -> String {
        let magnitude = number(abs(value), decimals: decimals)
        if value > 0 { return "+" + magnitude + unit }
        if value < 0 { return "−" + magnitude + unit }
        return magnitude + unit
    }
}
