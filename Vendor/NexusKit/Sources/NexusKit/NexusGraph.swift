import SwiftUI

// MARK: - Model

public enum NexusColorToken: Sendable, Hashable {
    case chart1, chart2, chart3, chart4, chart5, chart6, flow, attention, agent, inkSubtle
    public func color(_ p: NexusPalette) -> Color {
        switch self {
        case .chart1: return p.chart1
        case .chart2: return p.chart2
        case .chart3: return p.chart3
        case .chart4: return p.chart4
        case .chart5: return p.chart5
        case .chart6: return p.chart6
        case .flow: return p.flow
        case .attention: return p.attention
        case .agent: return p.agent
        case .inkSubtle: return p.inkSubtle
        }
    }
}

public struct NexusGraphType: Sendable {
    public var label: String
    public var symbol: String
    public var token: NexusColorToken
    public var isAgent: Bool
    public init(_ label: String, symbol: String, token: NexusColorToken, isAgent: Bool = false) {
        self.label = label; self.symbol = symbol; self.token = token; self.isAgent = isAgent
    }

    /// Defaults for district graphs; mirrors `Nexus.GRAPH_TYPES` on the web.
    public static let defaults: [String: NexusGraphType] = [
        "school": NexusGraphType("School", symbol: "house", token: .chart1),
        "person": NexusGraphType("Person", symbol: "person", token: .chart5),
        "cohort": NexusGraphType("Cohort", symbol: "person.2", token: .chart6),
        "system": NexusGraphType("System", symbol: "cylinder.split.1x2", token: .chart2),
        "route": NexusGraphType("Route", symbol: "bus", token: .chart3),
        "fact": NexusGraphType("Fact", symbol: "checkmark.circle", token: .flow),
        "decision": NexusGraphType("Decision", symbol: "scale.3d", token: .attention),
        "run": NexusGraphType("Agent run", symbol: "circle.grid.cross.fill", token: .agent, isAgent: true),
        "doc": NexusGraphType("Document", symbol: "doc.text", token: .inkSubtle),
        "dept": NexusGraphType("Department", symbol: "folder", token: .chart6),
    ]
}

public struct NexusGraphNode: Identifiable, Sendable, Hashable {
    public var id: String
    public var label: String
    public var type: String
    public var sub: String?
    public var more: Int
    public var suggested: Bool
    public var stale: Bool
    public var restricted: Bool
    public init(id: String, label: String, type: String, sub: String? = nil, more: Int = 0, suggested: Bool = false, stale: Bool = false, restricted: Bool = false) {
        self.id = id; self.label = label; self.type = type; self.sub = sub; self.more = more
        self.suggested = suggested; self.stale = stale; self.restricted = restricted
    }
}

public struct NexusGraphEdge: Identifiable, Sendable, Hashable {
    public enum Kind: Sendable, Hashable { case normal, inferred, evidence, path }
    public var source: String
    public var target: String
    public var label: String
    public var kind: Kind
    public var id: String { source + "→" + target + ":" + label }
    public init(_ source: String, _ target: String, _ label: String, kind: Kind = .normal) {
        self.source = source; self.target = target; self.label = label; self.kind = kind
    }
}

// MARK: - Layout (force simulation seeded by hop distance from the focus)

public enum NexusGraphLayout {
    static func halfSize(_ n: NexusGraphNode, focus: Bool, types: [String: NexusGraphType]) -> CGSize {
        let sub = n.sub ?? types[n.type]?.label ?? ""
        let w = max(Double(n.label.count) * (focus ? 8.2 : 7.4), Double(sub.count) * 6.2) + (focus ? 60 : 50) + (n.more > 0 ? 26 : 0)
        return CGSize(width: w / 2, height: focus ? 24 : 18)
    }

    public static func layout(nodes: [NexusGraphNode], edges: [NexusGraphEdge], focus: String?, previous: [String: CGPoint] = [:],
                              types: [String: NexusGraphType] = NexusGraphType.defaults) -> [String: CGPoint] {
        guard !nodes.isEmpty else { return [:] }
        var adjacency: [String: [String]] = [:]
        for n in nodes { adjacency[n.id] = [] }
        let live = edges.filter { adjacency[$0.source] != nil && adjacency[$0.target] != nil }
        for e in live { adjacency[e.source]?.append(e.target); adjacency[e.target]?.append(e.source) }
        let root = focus.flatMap { f in nodes.contains { $0.id == f } ? f : nil } ?? nodes[0].id
        var depth: [String: Int] = [root: 0]
        var queue = [root]
        while !queue.isEmpty {
            let u = queue.removeFirst()
            for v in adjacency[u] ?? [] where depth[v] == nil { depth[v] = (depth[u] ?? 0) + 1; queue.append(v) }
        }
        var rings: [Int: [String]] = [:]
        for n in nodes { let d = depth[n.id] ?? 3; depth[n.id] = d; rings[d, default: []].append(n.id) }

        var pos: [String: CGPoint] = [:]
        var half: [String: CGSize] = [:]
        let warm = !previous.isEmpty
        for (d, ids) in rings {
            for (i, id) in ids.enumerated() {
                let a = Double(i) / Double(ids.count) * 2 * .pi + Double(d) * 0.7
                let r = Double(d) * 175
                var pt = CGPoint(x: cos(a) * r * 1.35, y: sin(a) * r * 0.85)
                if let prev = previous[id] { pt = prev }
                else if warm, let nb = (adjacency[id] ?? []).first(where: { previous[$0] != nil }), let base = previous[nb] {
                    pt = CGPoint(x: base.x + cos(Double(i) * 2.4) * 140, y: base.y + sin(Double(i) * 2.4) * 90)
                }
                pos[id] = pt
                if let node = nodes.first(where: { $0.id == id }) { half[id] = halfSize(node, focus: id == root, types: types) }
            }
        }
        let ids = nodes.map(\.id)
        let iterations = warm ? 160 : 320
        for it in 0..<iterations {
            let alpha = (warm ? 0.5 : 1.0) * (1 - Double(it) / Double(iterations))
            for i in 0..<ids.count {
                for j in (i + 1)..<max(i + 1, ids.count) where j < ids.count {
                    guard var a = pos[ids[i]], var b = pos[ids[j]], let ha = half[ids[i]], let hb = half[ids[j]] else { continue }
                    let dx = b.x - a.x, dy = b.y - a.y
                    let d2 = dx * dx + dy * dy + 0.01, d = sqrt(d2), f = 26000 * alpha / d2
                    a.x -= dx / d * f; a.y -= dy / d * f; b.x += dx / d * f; b.y += dy / d * f
                    let ox = (ha.width + hb.width + 18) - abs(dx), oy = (ha.height + hb.height + 16) - abs(dy)
                    if ox > 0 && oy > 0 {
                        if ox / (ha.width + hb.width) < oy / (ha.height + hb.height) {
                            let s = (dx < 0 ? -1.0 : 1.0) * ox * 0.5; a.x -= s; b.x += s
                        } else {
                            let s = (dy < 0 ? -1.0 : 1.0) * oy * 0.5; a.y -= s; b.y += s
                        }
                    }
                    pos[ids[i]] = a; pos[ids[j]] = b
                }
            }
            for e in live {
                guard var a = pos[e.source], var b = pos[e.target], let ha = half[e.source], let hb = half[e.target] else { continue }
                let dx = b.x - a.x, dy = b.y - a.y, d = max(1, sqrt(dx * dx + dy * dy))
                let length = 110 + (ha.width + hb.width) * 0.6, k = (d - length) * 0.05 * alpha
                a.x += dx / d * k; a.y += dy / d * k; b.x -= dx / d * k; b.y -= dy / d * k
                pos[e.source] = a; pos[e.target] = b
            }
            for id in ids where id != root {
                guard var pt = pos[id] else { continue }
                let rx = pt.x / 1.55, r = max(1, sqrt(rx * rx + pt.y * pt.y))
                let target = Double(min(depth[id] ?? 3, 3)) * 165, k = (target - r) / r * 0.12 * alpha
                pt.x += pt.x * k; pt.y += pt.y * k
                pos[id] = pt
            }
            if var r = pos[root] { r.x *= 0.85; r.y *= 0.85; pos[root] = r }
        }
        return pos
    }
}

// MARK: - Node chip

public struct NexusGraphNodeChip: View {
    @Environment(\.nexus) private var p
    let node: NexusGraphNode
    let type: NexusGraphType
    let focus: Bool
    let selected: Bool
    let dimmed: Bool

    public init(node: NexusGraphNode, type: NexusGraphType? = nil, focus: Bool = false, selected: Bool = false, dimmed: Bool = false) {
        self.node = node
        self.type = type ?? NexusGraphType.defaults[node.type] ?? NexusGraphType(node.type, symbol: "circle", token: .inkSubtle)
        self.focus = focus; self.selected = selected; self.dimmed = dimmed
    }

    public var body: some View {
        let c = node.stale || node.restricted ? p.inkDisabled : type.token.color(p)
        HStack(spacing: 8) {
            ZStack {
                if type.isAgent { NexusAgentAvatar(state: .idle, size: focus ? 36 : 28) }
                else {
                    Circle().fill(c)
                    Image(systemName: type.symbol).font(.system(size: focus ? 17 : 13, weight: .semibold)).foregroundStyle(p.surfaceRaised)
                }
            }
            .frame(width: focus ? 36 : 28, height: focus ? 36 : 28)
            VStack(alignment: .leading, spacing: 1) {
                Text(node.label).font(focus ? NexusFont.headline : NexusFont.footnote.weight(.semibold)).foregroundStyle(node.stale ? p.inkMuted : p.ink)
                Text((node.sub ?? type.label).uppercased()).font(NexusFont.caption2).tracking(0.4).foregroundStyle(p.inkMuted)
            }
            if node.more > 0 {
                Text("+\(node.more)").font(NexusFont.caption2.weight(.bold)).foregroundStyle(p.inkMuted)
                    .padding(.horizontal, 6).padding(.vertical, 2).background(p.surfaceSunken, in: Capsule())
            }
        }
        .padding(.leading, 4).padding(.trailing, focus ? 16 : 12).padding(.vertical, 4)
        .background(node.suggested ? p.flowSoft : p.surfaceRaised, in: Capsule())
        .overlay(Capsule().stroke(selected ? p.focus : (node.suggested ? p.flow : c.opacity(focus ? 1 : 0.55)),
                                  style: StrokeStyle(lineWidth: selected ? 3 : (focus ? 2 : 1.5), dash: node.suggested ? [4, 3] : [])))
        .shadow(color: focus ? c.opacity(0.25) : .clear, radius: 10)
        .opacity(dimmed ? 0.32 : 1)
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(node.label), \(type.label)" + (node.more > 0 ? ", \(node.more) more" : "") + (focus ? ", focus" : ""))
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - Canvas

/// One neighbourhood at a time: focus in the middle, connections around it. Pan, pinch, tap to select, double-tap to expand.
public struct NexusGraphView: View {
    @Environment(\.nexus) private var p
    let nodes: [NexusGraphNode]
    let edges: [NexusGraphEdge]
    let focus: String?
    let types: [String: NexusGraphType]
    @Binding var selection: String?
    let onExpand: (String) -> Void

    @State private var positions: [String: CGPoint] = [:]
    @State private var scale: CGFloat = 1
    @State private var pan: CGSize = .zero
    @GestureState private var dragDelta: CGSize = .zero
    @GestureState private var pinch: CGFloat = 1

    public init(nodes: [NexusGraphNode], edges: [NexusGraphEdge], focus: String?, selection: Binding<String?>,
                types: [String: NexusGraphType] = NexusGraphType.defaults, onExpand: @escaping (String) -> Void = { _ in }) {
        self.nodes = nodes; self.edges = edges; self.focus = focus; self._selection = selection; self.types = types; self.onExpand = onExpand
    }

    private var lit: Set<String>? {
        guard let s = selection else { return nil }
        var out: Set<String> = [s]
        for e in edges { if e.source == s { out.insert(e.target) }; if e.target == s { out.insert(e.source) } }
        return out
    }

    public var body: some View {
        GeometryReader { geo in
            let k = scale * pinch
            let center = CGPoint(x: geo.size.width / 2 + pan.width + dragDelta.width, y: geo.size.height / 2 + pan.height + dragDelta.height)
            let toScreen: (CGPoint) -> CGPoint = { w in CGPoint(x: center.x + w.x * k, y: center.y + w.y * k) }
            let litSet = lit
            ZStack {
                Canvas { ctx, _ in
                    for e in edges {
                        guard let a = positions[e.source], let b = positions[e.target] else { continue }
                        let pa = toScreen(a), pb = toScreen(b)
                        let incident = selection != nil && (e.source == selection || e.target == selection)
                        let dim = litSet != nil && !incident && e.kind != .path
                        var path = Path(); path.move(to: pa); path.addLine(to: pb)
                        let color: Color
                        switch e.kind {
                        case .inferred: color = p.flow
                        case .evidence: color = p.success
                        case .path: color = p.accent
                        case .normal: color = incident ? p.inkSubtle : p.lineStrong
                        }
                        ctx.stroke(path, with: .color(color.opacity(dim ? 0.18 : 0.85)),
                                   style: StrokeStyle(lineWidth: (e.kind == .path ? 3.5 : incident ? 2 : 1.5) * min(1.2, k),
                                                      lineCap: .round, dash: e.kind == .inferred ? [5, 5] : e.kind == .path ? [2, 9] : []))
                    }
                }
                ForEach(edges.filter { e in e.kind == .inferred || e.kind == .path || e.source == (selection ?? focus) || e.target == (selection ?? focus) }) { e in
                    if let a = positions[e.source], let b = positions[e.target] {
                        Text(e.label)
                            .font(NexusFont.caption2.monospaced())
                            .foregroundStyle(e.kind == .inferred ? p.flowInk : p.inkMuted)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(p.surfaceRaised, in: Capsule())
                            .overlay(Capsule().stroke(e.kind == .inferred ? p.flow : p.line, style: StrokeStyle(lineWidth: 1, dash: e.kind == .inferred ? [3, 2] : [])))
                            .position(toScreen(CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)))
                            .allowsHitTesting(false)
                    }
                }
                ForEach(nodes) { n in
                    if let w = positions[n.id] {
                        NexusGraphNodeChip(node: n, type: types[n.type], focus: n.id == focus, selected: n.id == selection,
                                           dimmed: litSet.map { !$0.contains(n.id) } ?? false)
                            .scaleEffect(min(1.15, max(0.6, k)))
                            .position(toScreen(w))
                            .onTapGesture(count: 2) { onExpand(n.id) }
                            .onTapGesture { selection = n.id }
                            .animation(NexusMotion.spring, value: w)
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .updating($dragDelta) { v, s, _ in s = v.translation }
                    .onEnded { v in pan.width += v.translation.width; pan.height += v.translation.height }
                    .simultaneously(with: MagnifyGesture()
                        .updating($pinch) { v, s, _ in s = v.magnification }
                        .onEnded { v in scale = max(0.3, min(2.5, scale * v.magnification)) })
            )
            .onTapGesture { selection = nil }
            .onAppear { relayout(fit: geo.size) }
            .onChange(of: nodes.map(\.id)) { relayout(fit: nil) }
        }
        .background(p.surfaceCanvas)
        .overlay(alignment: .bottomTrailing) { controls }
        .clipShape(RoundedRectangle(cornerRadius: NexusRadius.lg))
        .overlay(RoundedRectangle(cornerRadius: NexusRadius.lg).stroke(p.line))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Graph")
    }

    private var controls: some View {
        VStack(spacing: 2) {
            Button { withAnimation(NexusMotion.spring) { scale = min(2.5, scale * 1.2) } } label: { Image(systemName: "plus").frame(width: 32, height: 32) }
                .accessibilityLabel("Zoom in")
            Button { withAnimation(NexusMotion.spring) { scale = max(0.3, scale / 1.2) } } label: { Image(systemName: "minus").frame(width: 32, height: 32) }
                .accessibilityLabel("Zoom out")
            Button { withAnimation(NexusMotion.spring) { pan = .zero; scale = 1 } } label: { Image(systemName: "arrow.up.left.and.arrow.down.right").frame(width: 32, height: 32) }
                .accessibilityLabel("Fit to view")
        }
        .buttonStyle(.plain)
        .foregroundStyle(p.ink)
        .padding(4)
        .nexusGlass(in: RoundedRectangle(cornerRadius: 16))
        .padding(12)
    }

    private func relayout(fit size: CGSize?) {
        let next = NexusGraphLayout.layout(nodes: nodes, edges: edges, focus: focus, previous: positions, types: types)
        withAnimation(NexusMotion.spring) { positions = next }
        if let size, let minX = next.values.map(\.x).min(), let maxX = next.values.map(\.x).max(),
           let minY = next.values.map(\.y).min(), let maxY = next.values.map(\.y).max() {
            let w = maxX - minX + 220, h = maxY - minY + 120
            scale = max(0.4, min(1.2, min(size.width / w, size.height / h)))
            pan = CGSize(width: -(minX + maxX) / 2 * scale, height: -(minY + maxY) / 2 * scale)
        }
    }
}

// MARK: - Inspector

public struct NexusGraphRelation: Identifiable, Sendable {
    public var type: String
    public var outgoing: Bool
    public var items: [NexusGraphNode]
    public var id: String { type + (outgoing ? "→" : "←") }
    public init(type: String, outgoing: Bool, items: [NexusGraphNode]) { self.type = type; self.outgoing = outgoing; self.items = items }
}

public struct NexusGraphInspector: View {
    @Environment(\.nexus) private var p
    let node: NexusGraphNode
    let properties: [(String, String)]
    let relations: [NexusGraphRelation]
    let suggestion: (title: String, evidence: String)?
    let source: String?
    let onNavigate: (String) -> Void
    let onConfirm: () -> Void
    let onDismiss: () -> Void

    public init(node: NexusGraphNode, properties: [(String, String)] = [], relations: [NexusGraphRelation] = [],
                suggestion: (title: String, evidence: String)? = nil, source: String? = nil,
                onNavigate: @escaping (String) -> Void = { _ in }, onConfirm: @escaping () -> Void = {}, onDismiss: @escaping () -> Void = {}) {
        self.node = node; self.properties = properties; self.relations = relations; self.suggestion = suggestion; self.source = source
        self.onNavigate = onNavigate; self.onConfirm = onConfirm; self.onDismiss = onDismiss
    }

    public var body: some View {
        let type = NexusGraphType.defaults[node.type] ?? NexusGraphType(node.type, symbol: "circle", token: .inkSubtle)
        NexusPanel {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(type.token.color(p))
                    Image(systemName: type.symbol).font(.system(size: 18, weight: .semibold)).foregroundStyle(p.surfaceRaised)
                }
                .frame(width: 40, height: 40)
                VStack(alignment: .leading, spacing: 0) {
                    Text(type.label.uppercased()).font(NexusFont.caption2).tracking(0.8).foregroundStyle(p.inkMuted)
                    Text(node.label).font(NexusFont.title2).foregroundStyle(p.ink)
                }
            }
            if !properties.isEmpty {
                Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 6) {
                    ForEach(properties.indices, id: \.self) { i in
                        GridRow {
                            Text(properties[i].0).font(NexusFont.code).foregroundStyle(p.inkMuted)
                            Text(properties[i].1).font(NexusFont.subheadline).foregroundStyle(p.ink)
                        }
                    }
                }
            }
            if !relations.isEmpty {
                Text("RELATIONSHIPS · \(relations.reduce(0) { $0 + $1.items.count })").font(NexusFont.caption2).tracking(0.8).foregroundStyle(p.inkMuted)
                VStack(spacing: 0) {
                    ForEach(relations) { r in
                        HStack {
                            Text(r.outgoing ? "\(r.type) →" : "← \(r.type)").font(NexusFont.caption2.monospaced().weight(.semibold))
                            Spacer()
                            Text("\(r.items.count)").font(NexusFont.caption2.monospaced())
                        }
                        .foregroundStyle(p.inkMuted)
                        .padding(.horizontal, 12).frame(height: 34).background(p.surfaceSunken)
                        ForEach(r.items) { it in
                            Button { onNavigate(it.id) } label: {
                                HStack(spacing: 10) {
                                    let t = NexusGraphType.defaults[it.type] ?? NexusGraphType(it.type, symbol: "circle", token: .inkSubtle)
                                    ZStack { Circle().fill(t.token.color(p)); Image(systemName: t.symbol).font(.system(size: 10, weight: .bold)).foregroundStyle(p.surfaceRaised) }
                                        .frame(width: 20, height: 20)
                                    Text(it.label).font(NexusFont.subheadline).foregroundStyle(p.ink)
                                    if let sub = it.sub { Text("· " + sub).font(NexusFont.caption1).foregroundStyle(p.inkMuted) }
                                    Spacer()
                                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(p.inkSubtle)
                                }
                                .padding(.horizontal, 12).frame(height: 40).contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            Divider()
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(p.line))
            }
            if let suggestion {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) { NexusAgentAvatar(state: .idle, size: 24); Text(suggestion.title).font(NexusFont.subheadline.weight(.semibold)) }
                    Text(suggestion.evidence).font(NexusFont.footnote).foregroundStyle(p.inkMuted)
                    HStack {
                        Button("Dismiss", action: onDismiss).buttonStyle(.bordered)
                        Button("Confirm link", action: onConfirm).buttonStyle(NexusPrimaryButtonStyle())
                    }
                }
                .padding(12)
                .background(p.flowSoft.opacity(0.6), in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(p.flow, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])))
            }
            if let source { NexusTrustFooter([source]) }
        }
    }
}

// MARK: - Path ("how is A connected to B?")

public struct NexusGraphPath: Identifiable, Sendable {
    public enum Step: Sendable { case node(NexusGraphNode), edge(label: String, incoming: Bool, inferred: Bool) }
    public var title: String
    public var established: Bool
    public var meta: String
    public var steps: [Step]
    public var id: String { title }
    public init(title: String, established: Bool, meta: String, steps: [Step]) { self.title = title; self.established = established; self.meta = meta; self.steps = steps }
}

public struct NexusGraphPathView: View {
    @Environment(\.nexus) private var p
    let summary: String?
    let paths: [NexusGraphPath]
    public init(summary: String? = nil, paths: [NexusGraphPath]) { self.summary = summary; self.paths = paths }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let summary {
                HStack(alignment: .top, spacing: 10) {
                    NexusAgentAvatar(state: .done, size: 28)
                    Text(summary).font(NexusFont.body).foregroundStyle(p.ink)
                }
            }
            ForEach(paths) { path in
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        Text(path.title).font(NexusFont.title3).foregroundStyle(p.ink)
                        NexusBadge(path.established ? "Established" : "Needs review", tone: path.established ? .success : .attention)
                        Spacer()
                        Text(path.meta).font(NexusFont.caption1).foregroundStyle(p.inkMuted)
                    }
                    NexusFlowLayout(spacing: 4) {
                        ForEach(Array(path.steps.enumerated()), id: \.offset) { pair in
                            switch pair.element {
                            case .node(let n):
                                NexusGraphNodeChip(node: n)
                            case .edge(let label, let incoming, let inferred):
                                Text(incoming ? "← \(label)" : "\(label) →")
                                    .font(NexusFont.caption2.monospaced().weight(.semibold))
                                    .foregroundStyle(inferred ? p.flowInk : p.inkMuted)
                                    .padding(.horizontal, 6)
                                    .frame(height: 40)
                                    .overlay(alignment: .center) {
                                        Rectangle().fill(inferred ? p.flow : p.lineStrong).frame(height: 2).offset(y: -12)
                                    }
                            }
                        }
                    }
                }
                .padding(16)
                .background(p.surfaceRaised, in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(p.line))
            }
        }
    }
}
