import SwiftUI

// Sample district data used by the previews below. Every school name and figure is illustrative.

enum NexusSamples {
    static let levels = ["Level 1", "Level 2", "Level 3", "Level 4"]
    static let levelRows: [NexusLevelRow] = [
        NexusLevelRow(label: "Artondale", n: 412, values: [14, 22, 38, 26]),
        NexusLevelRow(label: "Discovery", n: 388, values: [18, 25, 35, 22]),
        NexusLevelRow(label: "Evergreen", n: 301, values: [22, 28, 33, 17]),
        NexusLevelRow(label: "Harbor Heights", n: 356, values: [11, 20, 40, 29]),
        NexusLevelRow(label: "Vaughn", n: 8, values: [0, 0, 0, 0], suppressed: true),
    ]
    static let gaps: [NexusGapRow] = [
        NexusGapRow(label: "Grade 3", a: 64, b: 49), NexusGapRow(label: "Grade 4", a: 61, b: 52),
        NexusGapRow(label: "Grade 5", a: 66, b: 50), NexusGapRow(label: "Grade 6", a: 58, b: 51),
    ]
    static let slopes: [NexusSlopeItem] = [
        NexusSlopeItem(label: "Kopachuck", from: 88, to: 92), NexusSlopeItem(label: "Goodman", from: 91, to: 89),
        NexusSlopeItem(label: "Key Peninsula", from: 86, to: 82, watch: true), NexusSlopeItem(label: "Harbor Ridge", from: 90, to: 93),
    ]
    static let scatter: [NexusScatterPoint] = (0..<18).map { i in
        let x = 80 + Double((i * 37) % 19), y = 40 + Double((i * 53) % 45)
        return NexusScatterPoint(label: "School \(i + 1)", x: x, y: y, size: 40 + Double(i % 5) * 20, watch: x < 86 && y < 55, showLabel: i % 6 == 0)
    }
    static let bins: [NexusBin] = {
        let counts: [Int] = [2, 6, 14, 22, 31, 38, 29, 17, 6]
        return counts.indices.map { i in NexusBin(from: 55 + Double(i) * 5, to: 60 + Double(i) * 5, count: counts[i]) }
    }()
    static var calendar: (Date, [NexusCalendarDay]) {
        let cal = Calendar(identifier: .gregorian)
        let start = cal.date(from: DateComponents(year: 2026, month: 9, day: 7)) ?? .now
        let days = (0..<(14 * 7)).map { i -> NexusCalendarDay in
            let d = cal.date(byAdding: .day, value: i, to: start) ?? start
            let wd = cal.component(.weekday, from: d)
            if wd == 1 || wd == 7 { return NexusCalendarDay(date: d, off: true) }
            return NexusCalendarDay(date: d, value: 89 + Double((i * 7) % 9))
        }
        return (start, days)
    }
    static let area: [NexusSeries] = [
        NexusSeries(label: "Gen ed", values: [62, 63, 63, 64, 64, 65]),
        NexusSeries(label: "Special ed", values: [14, 14, 15, 15, 16, 16]),
        NexusSeries(label: "Transportation", values: [8, 8, 9, 9, 9, 10]),
        NexusSeries(label: "Facilities", values: [10, 9, 9, 9, 8, 8]),
    ]
    static let waterfall: [NexusWaterfallStep] = [
        NexusWaterfallStep("2025–26", 142.0, total: true), NexusWaterfallStep("Enrollment", -1.8), NexusWaterfallStep("Levy", 3.2),
        NexusWaterfallStep("Staffing", -2.6), NexusWaterfallStep("ESSER end", -1.4), NexusWaterfallStep("2026–27", 139.4, total: true),
    ]
    static let bullets: [NexusBulletRow] = [
        NexusBulletRow(label: "Attendance", sub: "Goal 95%", value: 93.1, compare: 92.4),
        NexusBulletRow(label: "9th on track", sub: "Goal 90%", value: 87.5, compare: 84.0),
        NexusBulletRow(label: "FAFSA", sub: "Goal 70%", value: 58.0, compare: 61.0),
    ]
    static let regions: [NexusMapRegion] = [
        NexusMapRegion(id: "n", label: "Gig Harbor North", points: [CGPoint(x: 260, y: 20), CGPoint(x: 420, y: 40), CGPoint(x: 400, y: 170), CGPoint(x: 250, y: 150)], value: 95.4),
        NexusMapRegion(id: "c", label: "Gig Harbor", points: [CGPoint(x: 250, y: 150), CGPoint(x: 400, y: 170), CGPoint(x: 380, y: 260), CGPoint(x: 230, y: 250)], value: 93.2),
        NexusMapRegion(id: "w", label: "Fox Island", points: [CGPoint(x: 120, y: 200), CGPoint(x: 210, y: 190), CGPoint(x: 220, y: 260), CGPoint(x: 130, y: 270)], value: 94.6),
        NexusMapRegion(id: "k", label: "Key Peninsula", points: [CGPoint(x: 40, y: 240), CGPoint(x: 200, y: 280), CGPoint(x: 170, y: 400), CGPoint(x: 30, y: 380)], value: 89.7),
    ]
    static let schools: [NexusMapSchool] = [
        NexusMapSchool(label: "Harbor Ridge", position: CGPoint(x: 330, y: 100), kind: .middle),
        NexusMapSchool(label: "Gig Harbor HS", position: CGPoint(x: 310, y: 210), kind: .high),
        NexusMapSchool(label: "Evergreen", position: CGPoint(x: 100, y: 330), kind: .elementary, watch: true),
    ]

    static let gridColumns: [NexusGridColumn] = [
        NexusGridColumn("school", "School", width: 160),
        NexusGridColumn("level", "Level", width: 90),
        NexusGridColumn("n", "Students", kind: .number, width: 90, aggregate: .sum),
        NexusGridColumn("att", "Attendance", kind: .bar, width: 150, aggregate: .weighted(by: "n"), definition: "Days present ÷ days enrolled", watchBelow: 90),
        NexusGridColumn("chg", "Δ vs LY", kind: .delta, width: 90),
        NexusGridColumn("trend", "Trend", kind: .spark, width: 100),
        NexusGridColumn("status", "Status", kind: .status, width: 110, statuses: [
            "ok": NexusStatusStyle("On track"), "watch": NexusStatusStyle("Watch", tone: .watch), "alert": NexusStatusStyle("Below goal", tone: .alert)]),
    ]
    private static func gridRow(_ school: String, _ level: String, _ n: Int, _ att: Double, _ chg: Double, _ status: String) -> NexusGridRow {
        let trend: [Double] = [att - 1.2, att - 0.4, att - 0.9, att + 0.2, att]
        let values: [String: NexusCellValue] = [
            "school": .text(school), "level": .text(level), "n": .number(Double(n)), "att": .number(att),
            "chg": .number(chg), "trend": .series(trend), "status": .text(status),
        ]
        return NexusGridRow(id: school, n: n, values: values)
    }
    static let gridRows: [NexusGridRow] = [
        gridRow("Artondale", "Elem", 412, 94.1, 0.8, "ok"),
        gridRow("Discovery", "Elem", 388, 92.6, -0.4, "watch"),
        gridRow("Evergreen", "Elem", 301, 89.2, -1.9, "alert"),
        gridRow("Harbor Ridge", "Middle", 702, 93.4, 0.2, "ok"),
        gridRow("Key Peninsula", "Middle", 455, 90.8, -0.7, "watch"),
        gridRow("Gig Harbor HS", "High", 1480, 91.9, 0.5, "ok"),
        gridRow("Vaughn", "Elem", 7, 88.0, 0, "watch"),
    ]

    static let graphNodes: [NexusGraphNode] = [
        NexusGraphNode(id: "evergreen", label: "Evergreen Elementary", type: "school", sub: "K–5 · 301 students"),
        NexusGraphNode(id: "p1", label: "Dana Whitfield", type: "person", sub: "Principal"),
        NexusGraphNode(id: "c1", label: "Grade 3 cohort", type: "cohort", more: 4),
        NexusGraphNode(id: "r1", label: "Route 14", type: "route"),
        NexusGraphNode(id: "s1", label: "Skyward", type: "system"),
        NexusGraphNode(id: "f1", label: "Attendance 89.2%", type: "fact", stale: true),
        NexusGraphNode(id: "run", label: "Attendance check", type: "run"),
        NexusGraphNode(id: "d1", label: "Bell time change", type: "decision", suggested: true),
        NexusGraphNode(id: "doc", label: "SIP 2026", type: "doc"),
    ]
    static let graphEdges: [NexusGraphEdge] = [
        NexusGraphEdge("p1", "evergreen", "LEADS"), NexusGraphEdge("c1", "evergreen", "ENROLLED_AT"),
        NexusGraphEdge("r1", "evergreen", "SERVES"), NexusGraphEdge("evergreen", "s1", "RECORDED_IN"),
        NexusGraphEdge("f1", "evergreen", "ABOUT", kind: .evidence), NexusGraphEdge("run", "f1", "PRODUCED"),
        NexusGraphEdge("d1", "r1", "MAY_AFFECT", kind: .inferred), NexusGraphEdge("doc", "evergreen", "PLANS_FOR"),
    ]
}

// MARK: - Previews

#Preview("Agent avatar · 12 states") {
    ScrollView {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 96))], spacing: 20) {
            ForEach(NexusAgentState.allCases, id: \.self) { s in
                VStack(spacing: 10) { NexusAgentAvatar(state: s, size: 52); Text(s.label).font(NexusFont.caption1) }
            }
        }
        .padding(24)
        NexusAgentStatusLine(state: .reading, now: "Reading 14 attendance reports", sub: "Evergreen · Sept", progress: 0.4).padding(24)
    }
    .nexusTheme(family: .nexus)
}

#Preview("Charts II") {
    let cal = NexusSamples.calendar
    return ScrollView {
        VStack(alignment: .leading, spacing: 28) {
            NexusStackedBarChart(title: "Spring ELA by school", rows: NexusSamples.levelRows, levels: NexusSamples.levels)
            NexusStackedBarChart(title: "Same, diverging", rows: NexusSamples.levelRows, levels: NexusSamples.levels, mode: .diverging)
            NexusDumbbellChart(title: "Opportunity gap", rows: NexusSamples.gaps, aLabel: "Not low-income", bLabel: "Low-income", domain: 40...70)
            NexusSlopeChart(title: "Attendance, last year → this year", items: NexusSamples.slopes, fromLabel: "2024–25", toLabel: "2025–26", domain: 80...95)
            NexusScatterQuadrant(title: "Attendance vs proficiency", points: NexusSamples.scatter, xLabel: "Attendance %", yLabel: "Meets standard %",
                                 xDomain: 78...100, yDomain: 35...90, xMid: 90, yMid: 60,
                                 quadrants: (topLeft: "Beating odds", topRight: "Strong", bottomLeft: "Look closer", bottomRight: "Instruction"))
            NexusHistogram(title: "Attendance rate, all students", bins: NexusSamples.bins, cut: 90, cutLabel: "Chronic absence", xLabel: "Attendance %")
            NexusCalendarHeatmap(title: "Daily attendance", start: cal.0, weeks: 14, days: cal.1)
            NexusStackedAreaChart(title: "Spending mix, %", series: NexusSamples.area, xLabels: ["21", "22", "23", "24", "25", "26"])
            NexusWaterfallChart(title: "General fund, $M", steps: NexusSamples.waterfall, domain: 130...150)
            NexusBulletChart(title: "Strategic plan goals", rows: NexusSamples.bullets, bands: [60, 80, 90], domain: 40...100)
            NexusSchoolMap(title: "Attendance by area", regions: NexusSamples.regions, schools: NexusSamples.schools)
        }
        .padding(24)
    }
    .nexusTheme(family: .nexus)
}

#Preview("Agent control") {
    @Previewable @State var enabled = true
    ScrollView {
        VStack(alignment: .leading, spacing: 24) {
            NexusPlanPreview(title: "Before I start", subtitle: "4 steps · about 3 minutes", steps: [
                NexusPlanStep(text: "Pull September attendance for all 17 schools", scopes: [.init("Skyward", read: true)], time: "40s"),
                NexusPlanStep(text: "Flag schools under 90%", time: "5s"),
                NexusPlanStep(text: "Draft a note to each flagged principal", scopes: [.init("Email drafts", write: true)], needs: "Your review"),
                NexusPlanStep(text: "Post summary to #attendance", scopes: [.init("Slack", write: true)], skip: true),
            ])
            NexusSteerQueue(now: "Reading Evergreen's attendance", nowSub: "3 of 17 schools", queued: ["Leave out Vaughn — it's too small"])
            NexusTakeoverBar(driver: .agent, detail: "Filling the transportation request form")
            NexusTakeoverBar(driver: .human, detail: "You're driving · the agent is watching", initials: "KH")
            NexusToolCallCard(name: "skyward.query", summary: "Read 4,812 attendance rows", duration: "1.2s",
                              inputs: [("school", "all"), ("month", "2026-09")], result: "4,812 rows · 17 schools", open: true)
            NexusAgentErrorRecovery(title: "I couldn't reach Skyward", detail: "The request timed out twice.", options: [
                NexusRecoveryOption("Try again in 5 minutes", detail: "I'll keep the rest of the plan", recommended: true),
                NexusRecoveryOption("Use Friday's export", detail: "3 days old"),
            ], technical: "HTTP 504 · skyward.psd401.net")
            NexusStandingTask(title: "Monday attendance check", next: "Mon 6:30 AM", day: "MON", date: "12",
                              understood: [(icon: "calendar", text: "Every Monday before school"), (icon: "bell", text: "Tell me only if a school drops under 90%")],
                              runs: [.ok(0.3), .ok(0.4), .found(0.8), .ok(0.2), .failed, .next], lastRun: "Last run Mon 6:31 AM · nothing to report",
                              enabled: $enabled)
            NexusOutputFeedback(meta: "Attendance summary · 2 min ago")
        }
        .padding(24)
    }
    .nexusTheme(family: .nexus)
}

#Preview("Memory & activity") {
    ScrollView {
        VStack(alignment: .leading, spacing: 24) {
            NexusActivityLog(entries: [
                NexusLogEntry(id: "1", day: "Today", time: "9:14", kind: .change, verb: "Updated", object: "Route 14 stop time", scope: "Transportation", undoUntil: "until 9:44"),
                NexusLogEntry(id: "2", day: "Today", time: "9:02", state: .reading, kind: .read, verb: "Read", object: "September attendance", scope: "Skyward"),
                NexusLogEntry(id: "3", day: "Yesterday", time: "4:40", state: .talking, kind: .message, verb: "Drafted", object: "Note to Evergreen principal", by: "Approved by you"),
                NexusLogEntry(id: "4", day: "Yesterday", time: "2:10", state: .waiting, kind: .permission, verb: "Asked for", object: "Write access to email drafts"),
            ])
            NexusMemoryGoals(memory: [
                NexusMemoryItem(text: "Leave schools under 10 students out of charts", source: "You, Sept 22"),
                NexusMemoryItem(text: "Board packets go out Thursdays", source: "Learned from calendar", pending: true),
            ], goals: [
                NexusGoal(title: "Chronic absence under 15%", status: "On track", tone: .success, progress: 0.62, state: .calculating, next: "Next check Monday"),
                NexusGoal(title: "All IEP meetings on time", status: "Watch", tone: .attention, progress: 0.4, next: "3 due this week"),
            ])
        }
        .padding(24)
    }
    .nexusTheme(family: .nexus)
}

#Preview("Data grid") {
    NexusDataGrid(title: "Attendance by school", source: "Skyward", freshness: "Updated 6:30 AM",
                  columns: NexusSamples.gridColumns, rows: NexusSamples.gridRows, selectable: true, showTotals: true, sortKey: "att")
        .padding(24)
        .nexusTheme(family: .nexus)
}

#Preview("Grouped · dark") {
    NexusDataGrid(title: "By level", columns: NexusSamples.gridColumns, rows: NexusSamples.gridRows, showTotals: true, groupBy: "level")
        .padding(24)
        .nexusTheme(family: .nexus)
        .preferredColorScheme(.dark)
}

#Preview("Pivot, diff, profile, cards") {
    let schools = ["Artondale", "Discovery", "Evergreen", "Vaughn"], grades = ["K", "1", "2", "3", "4", "5"]
    return ScrollView {
        VStack(alignment: .leading, spacing: 28) {
            NexusPivotTable(title: "Attendance by school and grade", rowKeys: schools, columnKeys: grades, rowLabel: "School",
                            value: { r, c in
                                // Typed in steps: as one expression returned into `Double?`, Xcode 26's
                                // type checker gives up on it ("unable to type-check … in reasonable time").
                                let seed: Int = r.count * 3 + c.count * 7 + (Int(c) ?? 0) * 5
                                let percent: Double = 88 + Double(seed % 9)
                                return percent
                            },
                            n: { r, _ in r == "Vaughn" ? 4 : 60 })
            NexusDiffTable(title: "Proposed roster changes", subtitle: "From the agent · review before saving", headers: ["Student", "School", "Grade"], rows: [
                NexusDiffRow(id: "a", op: .change, values: ["A. Rivera", "Discovery", "4"], old: [1: "Artondale"]),
                NexusDiffRow(id: "b", op: .add, values: ["J. Okafor", "Evergreen", "2"]),
                NexusDiffRow(id: "c", op: .remove, values: ["M. Chen", "Discovery", "5"]),
            ], unchanged: 412) {
                Button("Reject") {}.buttonStyle(.bordered)
                Button("Apply 3 changes") {}.buttonStyle(NexusPrimaryButtonStyle())
            }
            NexusColumnProfile(title: "enrollment_2026.csv", subtitle: "4,812 rows", columns: [
                NexusColumnProfileItem(name: "student_id", type: "text", distinct: 4812),
                NexusColumnProfileItem(name: "grade", type: "category", top: ["K", "1", "2"]),
                NexusColumnProfileItem(name: "attendance", type: "number", missing: 0.03, range: "41 – 100", histogram: [1, 2, 4, 9, 18, 30, 22, 8]),
                NexusColumnProfileItem(name: "entry_date", type: "date", missing: 0.21, warning: "21% blank — check the export"),
            ])
            NexusDataCards(columns: NexusSamples.gridColumns, rows: NexusSamples.gridRows, titleKey: "school", figureKey: "att")
        }
        .padding(24)
    }
    .nexusTheme(family: .commons)
}

#Preview("Graph explorer") {
    @Previewable @State var selection: String? = "r1"
    HStack(alignment: .top, spacing: 16) {
        NexusGraphView(nodes: NexusSamples.graphNodes, edges: NexusSamples.graphEdges, focus: "evergreen", selection: $selection)
            .frame(minWidth: 360, minHeight: 480)
        #if os(macOS)
        NexusGraphInspector(node: NexusSamples.graphNodes[0],
                            properties: [("grades", "K–5"), ("enrollment", "301"), ("principal", "Dana Whitfield")],
                            relations: [NexusGraphRelation(type: "SERVES", outgoing: false, items: [NexusSamples.graphNodes[3]]),
                                        NexusGraphRelation(type: "LEADS", outgoing: false, items: [NexusSamples.graphNodes[1]])],
                            suggestion: (title: "Bell time change may affect Route 14", evidence: "Route 14 serves 3 schools whose bells move in January."),
                            source: "Skyward · Transportation")
            .frame(width: 320)
        #endif
    }
    .padding(16)
    .nexusTheme(family: .nexus)
}

#Preview("Graph path") {
    let n = NexusSamples.graphNodes
    ScrollView {
        NexusGraphPathView(summary: "Route 14 connects to Evergreen two ways.", paths: [
            NexusGraphPath(title: "Direct", established: true, meta: "1 hop", steps: [.node(n[3]), .edge(label: "SERVES", incoming: false, inferred: false), .node(n[0])]),
            NexusGraphPath(title: "Through the bell change", established: false, meta: "2 hops · inferred", steps: [
                .node(n[7]), .edge(label: "MAY_AFFECT", incoming: false, inferred: true), .node(n[3]),
                .edge(label: "SERVES", incoming: false, inferred: false), .node(n[0])]),
        ])
        .padding(24)
    }
    .nexusTheme(family: .nexus)
}
