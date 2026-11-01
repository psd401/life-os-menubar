import SwiftUI

// MARK: - Agent avatar (twelve states)

/// What the agent is doing right now. Mirrors `Nexus.AGENT_STATES` on the web.
public enum NexusAgentState: String, CaseIterable, Sendable {
    case idle, thinking, listening, reading, searching, writing, calculating, talking, waiting, done, error, paused

    public var label: String {
        switch self {
        case .idle: return "Ready"
        case .thinking: return "Thinking"
        case .listening: return "Listening"
        case .reading: return "Reading"
        case .searching: return "Searching"
        case .writing: return "Writing"
        case .calculating: return "Calculating"
        case .talking: return "Talking"
        case .waiting: return "Waiting on you"
        case .done: return "Done"
        case .error: return "Stuck"
        case .paused: return "Paused"
        }
    }

    var symbol: String {
        switch self {
        case .idle: return "circle.grid.cross.fill"
        case .thinking: return "ellipsis"
        case .listening: return "mic.fill"
        case .reading: return "book.fill"
        case .searching: return "magnifyingglass"
        case .writing: return "scribble"
        case .calculating: return "chart.bar.fill"
        case .talking: return "waveform"
        case .waiting: return "questionmark"
        case .done: return "checkmark"
        case .error: return "exclamationmark"
        case .paused: return "pause.fill"
        }
    }
}

/// The living Nexus orb. Shape and motion change with `state`; Reduce Motion shows the glyph without animation.
public struct NexusAgentAvatar: View {
    @Environment(\.nexus) private var p
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let state: NexusAgentState
    let size: CGFloat
    let hue: Color?
    let name: String

    public init(state: NexusAgentState = .idle, size: CGFloat = 40, hue: Color? = nil, name: String = "Nexus") {
        self.state = state
        self.size = size
        self.hue = hue
        self.name = name
    }

    private var tint: Color {
        switch state {
        case .waiting: return p.attention
        case .done: return p.success
        case .error: return p.danger
        default: return hue ?? p.flow
        }
    }

    public var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { context in
            let t = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate
            ZStack {
                if state == .listening || state == .talking { ripples(t) }
                ring(t)
                core(t)
                glyph
                if state == .thinking || state == .searching { orbit(t) }
            }
            .frame(width: size, height: size)
        }
        .animation(.easeOut(duration: NexusMotion.slow), value: state)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(name): \(state.label)")
    }

    private func core(_ t: Double) -> some View {
        let scale: Double
        switch state {
        case .idle: scale = 1 + 0.04 * sin(t * 2 * .pi / 4)
        case .thinking: scale = 1 + 0.035 * sin(t * 2.6)
        default: scale = 1
        }
        return Circle()
            .fill(RadialGradient(colors: [tint.mix(with: .white, by: 0.35), tint, p.agent],
                                 center: UnitPoint(x: 0.35, y: 0.3), startRadius: 0, endRadius: size * 0.75))
            .overlay {
                if state == .reading && !reduceMotion { scan(t) }
            }
            .clipShape(Circle())
            .saturation(state == .paused ? 0.25 : 1)
            .shadow(color: tint.opacity(0.35), radius: size * 0.12, y: size * 0.05)
            .scaleEffect(scale)
    }

    private func scan(_ t: Double) -> some View {
        let phase = t.truncatingRemainder(dividingBy: 1.6) / 1.6
        return LinearGradient(colors: [.clear, .white.opacity(0.45), .clear], startPoint: .top, endPoint: .bottom)
            .frame(height: size * 0.3)
            .offset(y: -size * 0.65 + phase * size * 1.3)
    }

    private func ring(_ t: Double) -> some View {
        let strong = state == .waiting || state == .done || state == .error
        let pulse = state == .waiting && !reduceMotion ? (sin(t * .pi) + 1) / 2 : 0
        return Circle()
            .strokeBorder(strong ? tint : tint.opacity(0.3),
                          style: StrokeStyle(lineWidth: max(1.5, size * 0.04), dash: state == .paused ? [3, 3] : []))
            .padding(-size * 0.08)
            .shadow(color: tint.opacity(0.4 * pulse), radius: 6 * pulse)
    }

    private func ripples(_ t: Double) -> some View {
        ZStack {
            ForEach(0..<3, id: \.self) { i in
                let phase = (t / 1.8 + Double(i) / 3).truncatingRemainder(dividingBy: 1)
                Circle()
                    .stroke(tint, lineWidth: 2)
                    .scaleEffect(1 + phase * 0.55)
                    .opacity(reduceMotion ? 0 : 0.55 * (1 - phase))
            }
        }
    }

    private func orbit(_ t: Double) -> some View {
        let period = state == .searching ? 1.1 : 2.4
        let angle = (t / period).truncatingRemainder(dividingBy: 1) * 2 * .pi - .pi / 2
        let radius = size / 2 + size * 0.08
        let dot = max(5, size * 0.12)
        return Circle()
            .fill(tint)
            .frame(width: dot, height: dot)
            .overlay(Circle().stroke(p.surfaceRaised, lineWidth: 2))
            .offset(x: cos(angle) * radius, y: sin(angle) * radius)
            .opacity(reduceMotion ? 0 : 1)
    }

    @ViewBuilder private var glyph: some View {
        if state == .idle {
            NexusMark().fill(p.onAgent).frame(width: size * 0.44, height: size * 0.44)
        } else {
            Image(systemName: state.symbol)
                .font(.system(size: size * 0.36, weight: .semibold))
                .foregroundStyle(p.onAgent)
                .symbolEffect(.variableColor.iterative, options: .repeating,
                              isActive: !reduceMotion && (state == .calculating || state == .talking))
                .symbolEffect(.pulse, options: .repeating, isActive: !reduceMotion && state == .writing)
                .contentTransition(.symbolEffect(.replace))
        }
    }
}

/// The avatar plus a live line of words: what the agent is doing, and how far along it is.
public struct NexusAgentStatusLine<Actions: View>: View {
    @Environment(\.nexus) private var p
    let state: NexusAgentState
    let now: String
    let sub: String?
    let progress: Double?
    let size: CGFloat
    let hue: Color?
    let actions: Actions

    public init(state: NexusAgentState, now: String, sub: String? = nil, progress: Double? = nil,
                size: CGFloat = 40, hue: Color? = nil, @ViewBuilder actions: () -> Actions) {
        self.state = state; self.now = now; self.sub = sub; self.progress = progress
        self.size = size; self.hue = hue; self.actions = actions()
    }

    public var body: some View {
        HStack(spacing: 14) {
            NexusAgentAvatar(state: state, size: size, hue: hue)
            VStack(alignment: .leading, spacing: 2) {
                Text(now)
                    .font(NexusFont.headline)
                    .foregroundStyle(p.ink)
                    .lineLimit(1)
                    .contentTransition(.opacity)
                if let sub {
                    Text(sub).font(NexusFont.footnote).foregroundStyle(p.inkMuted).lineLimit(1)
                }
                if let progress {
                    ProgressView(value: progress).tint(p.flow).padding(.top, 4)
                }
            }
            Spacer(minLength: 0)
            actions
        }
        .animation(NexusMotion.spring, value: now)
        .accessibilityElement(children: .contain)
    }
}

public extension NexusAgentStatusLine where Actions == EmptyView {
    init(state: NexusAgentState, now: String, sub: String? = nil, progress: Double? = nil, size: CGFloat = 40, hue: Color? = nil) {
        self.init(state: state, now: now, sub: sub, progress: progress, size: size, hue: hue) { EmptyView() }
    }
}
