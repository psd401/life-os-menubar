import SwiftUI

// MARK: - Plan preview

public struct NexusPlanStep: Identifiable, Sendable, Equatable {
    public var id: String
    public var text: String
    public var scopes: [Scope]
    public var time: String?
    public var needs: String?
    public var skip: Bool
    public var added: Bool

    public struct Scope: Sendable, Equatable {
        public var label: String
        public var isWrite: Bool
        public var isRead: Bool
        public init(_ label: String, read: Bool = false, write: Bool = false) { self.label = label; self.isRead = read; self.isWrite = write }
    }

    public init(id: String = UUID().uuidString, text: String, scopes: [Scope] = [], time: String? = nil, needs: String? = nil, skip: Bool = false, added: Bool = false) {
        self.id = id; self.text = text; self.scopes = scopes; self.time = time; self.needs = needs; self.skip = skip; self.added = added
    }
}

/// The agent's plan, editable before anything runs.
public struct NexusPlanPreview: View {
    @Environment(\.nexus) private var p
    let title: String
    let subtitle: String?
    @State private var steps: [NexusPlanStep]
    @State private var draft = ""
    let onRun: ([NexusPlanStep]) -> Void
    let onCancel: () -> Void

    public init(title: String, subtitle: String? = nil, steps: [NexusPlanStep],
                onRun: @escaping ([NexusPlanStep]) -> Void = { _ in }, onCancel: @escaping () -> Void = {}) {
        self.title = title; self.subtitle = subtitle; self._steps = State(initialValue: steps); self.onRun = onRun; self.onCancel = onCancel
    }

    private var active: [NexusPlanStep] { steps.filter { !$0.skip } }

    public var body: some View {
        NexusPanel {
            HStack(spacing: 12) {
                NexusAgentAvatar(state: .idle, size: 36)
                NexusSectionHeader(title, subtitle: subtitle)
            }
            VStack(spacing: 0) {
                ForEach(Array(steps.enumerated()), id: \.element.id) { pair in
                    row(pair.element, index: pair.offset)
                    Divider()
                }
                HStack(spacing: 10) {
                    Image(systemName: "plus").foregroundStyle(p.inkMuted)
                    TextField("Add a step, e.g. \"also compare to last October\"", text: $draft)
                        .textFieldStyle(.plain)
                        .font(NexusFont.subheadline)
                        .onSubmit(addDraft)
                }
                .padding(12)
            }
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(p.line, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            HStack(spacing: 10) {
                Label("Nothing changes until you run it", systemImage: "checkmark.shield")
                    .font(NexusFont.caption1).foregroundStyle(p.inkSubtle)
                Spacer()
                Button("Cancel", action: onCancel).buttonStyle(.borderless)
                Button("Run \(active.count) steps") { onRun(active) }.buttonStyle(NexusPrimaryButtonStyle())
            }
        }
        .animation(NexusMotion.spring, value: steps)
    }

    private func row(_ s: NexusPlanStep, index: Int) -> some View {
        HStack(spacing: 10) {
            Text("\(index + 1)")
                .font(NexusFont.caption1.weight(.semibold))
                .frame(width: 26, height: 26)
                .background(s.needs != nil ? p.attentionSoft : p.surfaceSunken, in: Circle())
                .foregroundStyle(s.needs != nil ? p.attentionInk : p.inkMuted)
            VStack(alignment: .leading, spacing: 4) {
                Text(s.text).font(NexusFont.subheadline).strikethrough(s.skip).foregroundStyle(s.skip ? p.inkMuted : p.ink)
                NexusFlowLayout(spacing: 6) {
                    ForEach(s.scopes, id: \.label) { sc in
                        NexusScopeChip(sc.label, kind: sc.isWrite ? .write : sc.isRead ? .read : .neutral)
                    }
                    if let time = s.time { Text("≈ \(time)").font(NexusFont.caption1).foregroundStyle(p.inkMuted) }
                    if let needs = s.needs { Text(needs).font(NexusFont.caption1.weight(.semibold)).foregroundStyle(p.attentionInk) }
                }
            }
            Spacer(minLength: 8)
            Button {
                steps[index].skip.toggle()
            } label: {
                Image(systemName: s.skip ? "plus.circle" : "xmark.circle")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(p.inkMuted)
            .accessibilityLabel(s.skip ? "Include step" : "Skip step")
        }
        .padding(12)
        .background(s.added ? p.flowSoft.opacity(0.6) : Color.clear)
        .contextMenu {
            Button("Move up") { move(index, by: -1) }.disabled(index == 0)
            Button("Move down") { move(index, by: 1) }.disabled(index == steps.count - 1)
        }
    }

    private func move(_ i: Int, by d: Int) {
        let j = i + d
        guard steps.indices.contains(j) else { return }
        steps.swapAt(i, j)
    }

    private func addDraft() {
        let text = draft.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        steps.append(NexusPlanStep(text: text, added: true))
        draft = ""
    }
}

// MARK: - Steer while working

public struct NexusSteerQueue: View {
    @Environment(\.nexus) private var p
    let state: NexusAgentState
    let now: String
    let nowSub: String?
    @State private var queued: [String]
    @State private var draft = ""
    let onAdd: (String) -> Void
    let onPause: () -> Void

    public init(state: NexusAgentState = .reading, now: String, nowSub: String? = nil, queued: [String] = [],
                onAdd: @escaping (String) -> Void = { _ in }, onPause: @escaping () -> Void = {}) {
        self.state = state; self.now = now; self.nowSub = nowSub; self._queued = State(initialValue: queued); self.onAdd = onAdd; self.onPause = onPause
    }

    public var body: some View {
        NexusPanel {
            NexusAgentStatusLine(state: state, now: now, sub: nowSub) {
                Button("Pause", systemImage: "pause.fill", action: onPause).buttonStyle(.bordered)
            }
            .padding(12)
            .background(p.flowSoft.opacity(0.7), in: RoundedRectangle(cornerRadius: 14))
            if !queued.isEmpty {
                Text("QUEUED FOR NEXUS · \(queued.count)").font(NexusFont.caption2).tracking(0.8).foregroundStyle(p.inkMuted)
                ForEach(Array(queued.enumerated()), id: \.offset) { pair in
                    HStack(spacing: 10) {
                        Image(systemName: "arrow.right").foregroundStyle(p.inkMuted)
                        Text(pair.element).font(NexusFont.subheadline)
                        Spacer()
                        Text("after this step").font(NexusFont.caption1).foregroundStyle(p.inkMuted)
                        Button { queued.remove(at: pair.offset) } label: { Image(systemName: "xmark") }
                            .buttonStyle(.borderless).accessibilityLabel("Remove instruction")
                    }
                    .padding(10)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(p.lineStrong, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
                }
            }
            HStack {
                TextField("Steer without stopping: \"also check Westbrook\"", text: $draft)
                    .textFieldStyle(.plain).font(NexusFont.subheadline).onSubmit(add)
                Button(action: add) { Image(systemName: "arrow.up.circle.fill").font(.title2) }
                    .buttonStyle(.borderless).foregroundStyle(p.action).accessibilityLabel("Add instruction")
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .overlay(Capsule().stroke(p.lineStrong, lineWidth: 1))
        }
        .animation(NexusMotion.spring, value: queued)
    }

    private func add() {
        let text = draft.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        queued.append(text); onAdd(text); draft = ""
    }
}

// MARK: - Take over / hand back

public struct NexusTakeoverBar: View {
    public enum Driver: Sendable { case agent, human }
    @Environment(\.nexus) private var p
    let driver: Driver
    let detail: String
    let initials: String
    let onTakeOver: () -> Void
    let onHandBack: () -> Void

    public init(driver: Driver, detail: String, initials: String = "You", onTakeOver: @escaping () -> Void = {}, onHandBack: @escaping () -> Void = {}) {
        self.driver = driver; self.detail = detail; self.initials = initials; self.onTakeOver = onTakeOver; self.onHandBack = onHandBack
    }

    public var body: some View {
        HStack(spacing: 14) {
            if driver == .human {
                Text(initials).font(NexusFont.caption1.weight(.bold)).foregroundStyle(p.surfaceRaised)
                    .frame(width: 34, height: 34).background(p.attentionInk, in: Circle())
            } else {
                NexusAgentAvatar(state: .writing, size: 28)
            }
            Text("\(Text(driver == .human ? "You\u{2019}re driving. " : "Nexus is driving. ").bold())\(detail)")
                .font(NexusFont.subheadline).foregroundStyle(p.ink)
            Spacer(minLength: 8)
            if driver == .human {
                Button("Hand back to Nexus", action: onHandBack).buttonStyle(NexusPrimaryButtonStyle())
            } else {
                Button("Take over", action: onTakeOver).buttonStyle(.bordered).keyboardShortcut(".", modifiers: .command)
            }
        }
        .padding(.vertical, 10).padding(.horizontal, 14)
        .background(driver == .human ? p.attentionSoft : p.flowSoft, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(driver == .human ? p.attention : p.flow.opacity(0.4), lineWidth: driver == .human ? 1.5 : 1))
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Tool call card

public struct NexusToolCallCard: View {
    public enum Status: Sendable { case running, done, failed }
    @Environment(\.nexus) private var p
    let name: String
    let summary: String
    let status: Status
    let writes: Bool
    let duration: String?
    let inputs: [(String, String)]
    let result: String?
    let raw: String?
    @State private var open: Bool
    @State private var showRaw = false

    public init(name: String, summary: String, status: Status = .done, writes: Bool = false, duration: String? = nil,
                inputs: [(String, String)] = [], result: String? = nil, raw: String? = nil, open: Bool = false) {
        self.name = name; self.summary = summary; self.status = status; self.writes = writes; self.duration = duration
        self.inputs = inputs; self.result = result; self.raw = raw; self._open = State(initialValue: open)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button { withAnimation(NexusMotion.spring) { open.toggle() } } label: {
                HStack(spacing: 10) {
                    Group {
                        switch status {
                        case .running: ProgressView().controlSize(.small)
                        case .done: Image(systemName: "cylinder.split.1x2").foregroundStyle(p.successInk)
                        case .failed: Image(systemName: "exclamationmark.triangle").foregroundStyle(p.dangerInk)
                        }
                    }
                    .frame(width: 30, height: 30)
                    .background(status == .failed ? p.dangerSoft : status == .running ? p.flowSoft : p.successSoft, in: RoundedRectangle(cornerRadius: 9))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(name).font(NexusFont.code).foregroundStyle(p.ink)
                        Text(summary).font(NexusFont.caption1).foregroundStyle(p.inkMuted)
                    }
                    Spacer()
                    NexusScopeChip(writes ? "Changes data" : "Read-only", kind: writes ? .write : .read)
                    if let duration { Text(duration).font(NexusFont.code).foregroundStyle(p.inkMuted) }
                    Image(systemName: open ? "chevron.down" : "chevron.right").foregroundStyle(p.inkMuted)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(10)
            .accessibilityValue(open ? "Expanded" : "Collapsed")
            if open {
                Divider()
                VStack(alignment: .leading, spacing: 10) {
                    if !inputs.isEmpty {
                        Text("ASKED FOR").font(NexusFont.caption2).tracking(0.8).foregroundStyle(p.inkMuted)
                        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 4) {
                            ForEach(inputs.indices, id: \.self) { i in
                                GridRow {
                                    Text(inputs[i].0).foregroundStyle(p.inkMuted)
                                    Text(inputs[i].1).foregroundStyle(p.ink)
                                }
                                .font(NexusFont.code)
                            }
                        }
                    }
                    if let result {
                        Text(status == .failed ? "WHAT WENT WRONG" : "GOT BACK").font(NexusFont.caption2).tracking(0.8).foregroundStyle(p.inkMuted)
                        Text(result).font(NexusFont.subheadline).foregroundStyle(p.ink)
                    }
                    if let raw {
                        Button(showRaw ? "Hide raw response" : "Show raw response") { showRaw.toggle() }
                            .buttonStyle(.borderless).font(NexusFont.caption1.weight(.semibold))
                        if showRaw {
                            Text(raw).font(NexusFont.code).textSelection(.enabled)
                                .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                                .background(p.surfaceRaised, in: RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
                .padding(12)
                .background(p.surfaceSunken.opacity(0.5))
            }
        }
        .background(p.surfaceRaised, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(status == .failed ? p.danger.opacity(0.45) : p.line, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Error recovery

public struct NexusRecoveryOption: Identifiable, Sendable {
    public var label: String
    public var detail: String
    public var recommended: Bool
    public var id: String { label }
    public init(_ label: String, detail: String, recommended: Bool = false) { self.label = label; self.detail = detail; self.recommended = recommended }
}

public struct NexusAgentErrorRecovery: View {
    @Environment(\.nexus) private var p
    let title: String, detail: String, safe: String, options: [NexusRecoveryOption], technical: String?
    let onChoose: (NexusRecoveryOption) -> Void

    public init(title: String, detail: String, safe: String = "Nothing was changed.", options: [NexusRecoveryOption],
                technical: String? = nil, onChoose: @escaping (NexusRecoveryOption) -> Void = { _ in }) {
        self.title = title; self.detail = detail; self.safe = safe; self.options = options; self.technical = technical; self.onChoose = onChoose
    }

    public var body: some View {
        NexusPanel {
            HStack(spacing: 12) {
                NexusAgentAvatar(state: .error, size: 40)
                NexusSectionHeader(title, subtitle: detail)
            }
            Label(safe, systemImage: "checkmark.shield")
                .font(NexusFont.subheadline.weight(.medium))
                .foregroundStyle(p.successInk)
                .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                .background(p.successSoft, in: RoundedRectangle(cornerRadius: 12))
            ForEach(options) { o in
                Button { onChoose(o) } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 8) {
                                Text(o.label).font(NexusFont.subheadline.weight(.semibold)).foregroundStyle(p.ink)
                                if o.recommended { NexusBadge("Recommended", tone: .flow) }
                            }
                            Text(o.detail).font(NexusFont.caption1).foregroundStyle(p.inkMuted).multilineTextAlignment(.leading)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(p.inkSubtle)
                    }
                    .padding(12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(o.recommended ? p.accent : p.line, lineWidth: o.recommended ? 2 : 1))
            }
            if let technical {
                DisclosureGroup("Technical details") {
                    Text(technical).font(NexusFont.code).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                }
                .font(NexusFont.footnote)
                .foregroundStyle(p.inkMuted)
            }
        }
        .overlay(RoundedRectangle(cornerRadius: NexusRadius.lg).stroke(p.danger.opacity(0.35), lineWidth: 1))
    }
}

// MARK: - Standing (scheduled) task

public struct NexusStandingTask: View {
    public enum Run: Sendable { case ok(Double), found(Double), failed, next }
    @Environment(\.nexus) private var p
    let title: String, next: String, day: String, date: String, understood: [(icon: String, text: String)], runs: [Run], lastRun: String
    @Binding var enabled: Bool
    let onRunNow: () -> Void

    public init(title: String, next: String, day: String, date: String, understood: [(icon: String, text: String)], runs: [Run],
                lastRun: String, enabled: Binding<Bool>, onRunNow: @escaping () -> Void = {}) {
        self.title = title; self.next = next; self.day = day; self.date = date; self.understood = understood; self.runs = runs
        self.lastRun = lastRun; self._enabled = enabled; self.onRunNow = onRunNow
    }

    public var body: some View {
        NexusPanel {
            HStack(spacing: 12) {
                VStack(spacing: 0) {
                    Text(day.uppercased()).font(NexusFont.caption2.weight(.bold)).foregroundStyle(p.surfaceRaised)
                        .frame(maxWidth: .infinity).padding(.vertical, 2).background(p.attentionInk)
                    Text(date).font(NexusFont.title2).foregroundStyle(p.ink).frame(maxHeight: .infinity)
                }
                .frame(width: 52, height: 56)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(p.line))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(NexusFont.title2).foregroundStyle(p.ink)
                    Text(next).font(NexusFont.footnote).foregroundStyle(p.inkMuted)
                }
                Spacer()
                Toggle("On", isOn: $enabled).labelsHidden()
            }
            NexusFlowLayout(spacing: 6) {
                Text("Understood as").font(NexusFont.footnote).foregroundStyle(p.inkMuted)
                ForEach(understood.indices, id: \.self) { i in
                    Label(understood[i].text, systemImage: understood[i].icon).font(NexusFont.caption1.weight(.semibold))
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(p.surfaceSelected, in: Capsule())
                }
            }
            HStack(alignment: .bottom, spacing: 12) {
                HStack(alignment: .bottom, spacing: 4) {
                    ForEach(Array(runs.enumerated()), id: \.offset) { pair in runBar(pair.element) }
                }
                .frame(height: 28)
                .accessibilityLabel("Recent runs")
                Text(lastRun).font(NexusFont.caption1).foregroundStyle(p.inkMuted)
            }
            HStack {
                NexusScopeChip("Attendance (SIS)", kind: .read)
                Spacer()
                Button("Run now", action: onRunNow).buttonStyle(NexusPrimaryButtonStyle())
            }
        }
    }

    @ViewBuilder private func runBar(_ r: Run) -> some View {
        switch r {
        case .ok(let size): RoundedRectangle(cornerRadius: 3).fill(p.success).frame(width: 10, height: 10 + size * 18)
        case .found(let size): RoundedRectangle(cornerRadius: 3).fill(p.attention).frame(width: 10, height: 10 + size * 18)
        case .failed: RoundedRectangle(cornerRadius: 3).fill(p.danger).frame(width: 10, height: 14)
        case .next: RoundedRectangle(cornerRadius: 3).stroke(p.lineStrong, style: StrokeStyle(lineWidth: 1.5, dash: [3, 2])).frame(width: 10, height: 28)
        }
    }
}

// MARK: - Output feedback

public struct NexusOutputFeedback: View {
    public enum Vote: Sendable { case up, down }
    @Environment(\.nexus) private var p
    let reasons: [String]
    let meta: String?
    let thanks: String
    let onSubmit: ([String], Bool, String) -> Void
    @State private var vote: Vote?
    @State private var picked: Set<String> = []
    @State private var note = ""
    @State private var remember = true
    @State private var sent = false

    public init(reasons: [String] = ["Wrong numbers", "Missed something", "Too long", "Wrong tone", "Not what I asked"],
                meta: String? = nil, thanks: String = "Thanks. I\u{2019}ll use that next time.",
                onSubmit: @escaping ([String], Bool, String) -> Void = { _, _, _ in }) {
        self.reasons = reasons; self.meta = meta; self.thanks = thanks; self.onSubmit = onSubmit
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 4) {
                voteButton(.up, symbol: "hand.thumbsup", label: "Good response")
                voteButton(.down, symbol: "hand.thumbsdown", label: "Needs work")
                Button { } label: { Image(systemName: "doc.on.doc") }.buttonStyle(.borderless).accessibilityLabel("Copy")
                Button { } label: { Image(systemName: "arrow.counterclockwise") }.buttonStyle(.borderless).accessibilityLabel("Try again")
                Spacer()
                if let meta { Text(meta).font(NexusFont.caption1).foregroundStyle(p.inkMuted) }
            }
            .foregroundStyle(p.inkMuted)
            if vote == .down && !sent {
                VStack(alignment: .leading, spacing: 10) {
                    Text("What should be different?").font(NexusFont.subheadline.weight(.semibold))
                    NexusFlowLayout(spacing: 6) {
                        ForEach(reasons, id: \.self) { r in
                            Button(r) { if picked.contains(r) { picked.remove(r) } else { picked.insert(r) } }
                                .buttonStyle(.bordered)
                                .tint(picked.contains(r) ? p.accent : p.inkMuted)
                        }
                    }
                    TextField("Tell Nexus in your words (optional)", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                        .textFieldStyle(.roundedBorder)
                    Toggle("Remember this for next time", isOn: $remember).font(NexusFont.footnote)
                    HStack {
                        Spacer()
                        Button("Cancel") { vote = nil }.buttonStyle(.borderless)
                        Button("Send feedback") { sent = true; onSubmit(Array(picked), remember, note) }.buttonStyle(NexusPrimaryButtonStyle())
                    }
                }
                .padding(14)
                .background(p.surfaceRaised, in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(p.line))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            if sent {
                HStack(spacing: 10) {
                    NexusAgentAvatar(state: .done, size: 26)
                    Text(thanks).font(NexusFont.footnote).foregroundStyle(p.ink)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(p.flowSoft, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .animation(NexusMotion.spring, value: vote)
        .animation(NexusMotion.spring, value: sent)
    }

    private func voteButton(_ v: Vote, symbol: String, label: String) -> some View {
        Button { vote = v; sent = false } label: {
            Image(systemName: vote == v ? symbol + ".fill" : symbol).frame(width: 30, height: 30)
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(label)
        .accessibilityAddTraits(vote == v ? .isSelected : [])
    }
}

// MARK: - Activity log

public struct NexusLogEntry: Identifiable, Sendable {
    public enum Kind: String, Sendable, CaseIterable { case change = "Changes", read = "Reads", message = "Messages", permission = "Permissions" }
    public var id: String
    public var day: String
    public var time: String
    public var state: NexusAgentState
    public var kind: Kind
    public var verb: String
    public var object: String
    public var scope: String?
    public var by: String?
    public var undoUntil: String?
    public var undone: Bool
    public init(id: String, day: String, time: String, state: NexusAgentState = .done, kind: Kind, verb: String, object: String,
                scope: String? = nil, by: String? = nil, undoUntil: String? = nil, undone: Bool = false) {
        self.id = id; self.day = day; self.time = time; self.state = state; self.kind = kind; self.verb = verb; self.object = object
        self.scope = scope; self.by = by; self.undoUntil = undoUntil; self.undone = undone
    }
}

public struct NexusActivityLog: View {
    @Environment(\.nexus) private var p
    let entries: [NexusLogEntry]
    let onUndo: (NexusLogEntry) -> Void
    @State private var filter: NexusLogEntry.Kind?
    @State private var undone: Set<String> = []

    public init(entries: [NexusLogEntry], onUndo: @escaping (NexusLogEntry) -> Void = { _ in }) { self.entries = entries; self.onUndo = onUndo }

    private var days: [String] {
        var seen: [String] = []
        for e in entries where !seen.contains(e.day) { seen.append(e.day) }
        return seen
    }

    public var body: some View {
        NexusPanel {
            NexusSectionHeader("What Nexus did", subtitle: "Every action, with who allowed it. Changes can be undone while the window is open.")
            Picker("Filter", selection: $filter) {
                Text("All").tag(NexusLogEntry.Kind?.none)
                ForEach(NexusLogEntry.Kind.allCases, id: \.self) { k in Text(k.rawValue).tag(Optional(k)) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            ForEach(days, id: \.self) { day in
                Text(day.uppercased()).font(NexusFont.caption2).tracking(0.8).foregroundStyle(p.inkMuted).padding(.top, 6)
                ForEach(entries.filter { $0.day == day && (filter == nil || $0.kind == filter) }) { e in
                    let isUndone = e.undone || undone.contains(e.id)
                    HStack(spacing: 10) {
                        Text(e.time).font(NexusFont.code).foregroundStyle(p.inkMuted).frame(width: 44, alignment: .leading)
                        NexusAgentAvatar(state: e.state, size: 24)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("\(Text(e.verb + " ").bold())\(e.object)").font(NexusFont.subheadline).strikethrough(isUndone)
                            HStack(spacing: 6) {
                                if let scope = e.scope { NexusScopeChip(scope, kind: e.kind == .change ? .write : e.kind == .read ? .read : .neutral) }
                                if let by = e.by { Text("Allowed by \(by)").font(NexusFont.caption1).foregroundStyle(p.inkMuted) }
                                if isUndone { Text("Undone").font(NexusFont.caption1).foregroundStyle(p.inkMuted) }
                            }
                        }
                        .foregroundStyle(isUndone ? p.inkMuted : p.ink)
                        Spacer()
                        if let until = e.undoUntil, !isUndone {
                            Button("Undo · \(until)", systemImage: "arrow.uturn.backward") { undone.insert(e.id); onUndo(e) }
                                .buttonStyle(.bordered).controlSize(.small)
                        }
                    }
                    .padding(.vertical, 6)
                    Divider()
                }
            }
        }
    }
}

// MARK: - Memory & goals

public struct NexusMemoryItem: Identifiable, Sendable {
    public var id: String
    public var text: String
    public var source: String
    public var pending: Bool
    public init(id: String = UUID().uuidString, text: String, source: String, pending: Bool = false) { self.id = id; self.text = text; self.source = source; self.pending = pending }
}

public struct NexusGoal: Identifiable, Sendable {
    public var id: String { title }
    public var title: String
    public var status: String
    public var tone: NexusBadge.Tone
    public var progress: Double
    public var state: NexusAgentState
    public var next: String
    public init(title: String, status: String, tone: NexusBadge.Tone = .flow, progress: Double, state: NexusAgentState = .idle, next: String) {
        self.title = title; self.status = status; self.tone = tone; self.progress = progress; self.state = state; self.next = next
    }
}

public struct NexusMemoryGoals: View {
    @Environment(\.nexus) private var p
    @State private var memory: [NexusMemoryItem]
    let goals: [NexusGoal]
    @State private var tab = 0

    public init(memory: [NexusMemoryItem], goals: [NexusGoal]) { self._memory = State(initialValue: memory); self.goals = goals }

    public var body: some View {
        NexusPanel {
            HStack(spacing: 12) {
                NexusAgentAvatar(state: .idle, size: 36)
                NexusSectionHeader("What Nexus knows", subtitle: "You can see, edit or forget anything here.")
            }
            Picker("Section", selection: $tab) {
                Text("Memory · \(memory.count)").tag(0)
                Text("Goals · \(goals.count)").tag(1)
            }
            .pickerStyle(.segmented).labelsHidden()
            if tab == 0 {
                ForEach(memory) { m in
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(m.pending ? Text("Remember this? ").bold().foregroundStyle(p.flowInk) : Text(""))\(m.text)")
                            Text(m.source).font(NexusFont.caption1).foregroundStyle(p.inkMuted)
                        }
                        .font(NexusFont.subheadline)
                        Spacer()
                        if m.pending {
                            Button("No") { forget(m) }.buttonStyle(.bordered).controlSize(.small)
                            Button("Remember") { keep(m) }.buttonStyle(.borderedProminent).controlSize(.small).tint(p.action)
                        } else {
                            Button { forget(m) } label: { Image(systemName: "trash") }.buttonStyle(.borderless).accessibilityLabel("Forget")
                        }
                    }
                    .padding(12)
                    .background(m.pending ? p.flowSoft.opacity(0.6) : p.surfaceRaised, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(m.pending ? p.flow : p.line, style: StrokeStyle(lineWidth: 1, dash: m.pending ? [4, 3] : [])))
                }
            } else {
                ForEach(goals) { g in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 10) {
                            NexusAgentAvatar(state: g.state, size: 24)
                            Text(g.title).font(NexusFont.title3).foregroundStyle(p.ink)
                            Spacer()
                            NexusBadge(g.status, tone: g.tone)
                        }
                        ProgressView(value: g.progress).tint(p.flow)
                        Text(g.next).font(NexusFont.caption1).foregroundStyle(p.inkMuted)
                    }
                    .padding(14)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(p.line))
                }
            }
        }
        .animation(NexusMotion.spring, value: tab)
    }

    private func forget(_ m: NexusMemoryItem) { memory.removeAll { $0.id == m.id } }
    private func keep(_ m: NexusMemoryItem) {
        if let i = memory.firstIndex(where: { $0.id == m.id }) { memory[i].pending = false }
    }
}
