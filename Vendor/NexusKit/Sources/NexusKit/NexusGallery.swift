import SwiftUI

/// A small showcase of NexusKit. Open this file in Xcode and use the canvas (⌥⌘↩) to see it.
public struct NexusGallery: View {
    @Environment(\.nexus) private var p
    public init() { NexusFonts.register() }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: NexusSpace.s4) {
                Text("Good morning, Liz").font(NexusFont.largeTitle)
                Text("Two things need you before 8:30.").font(NexusFont.body).foregroundStyle(p.inkMuted)

                NexusCard {
                    VStack(alignment: .leading, spacing: NexusSpace.s2) {
                        Text("NEEDS YOU · 2 MIN").font(NexusFont.code).foregroundStyle(p.attentionInk)
                        Text("Approve the SLP schedule for Tuesday").font(NexusFont.title2)
                        Text("18 moves, no conflicts.").font(NexusFont.body).foregroundStyle(p.inkMuted)
                        Button("Review") {}.buttonStyle(NexusPrimaryButtonStyle())
                    }
                }

                HStack(spacing: NexusSpace.s3) {
                    NexusAgentOrb()
                    Text("Nexus is checking route times…").font(NexusFont.body)
                }
                .padding(.vertical, 6).padding(.leading, 6).padding(.trailing, 14)
                .nexusGlass(in: Capsule())

                GlassEffectContainer(spacing: 12) {
                    HStack(spacing: 12) {
                        Button("Keep draft") {}.buttonStyle(.glass)
                        Button("Apply 18 moves") {}.buttonStyle(.glassProminent).tint(p.action)
                    }
                }

                NexusTrustFooter(["Read-only", "attendance (SIS)", "nothing sent"])
                Text("Thanks for building with us").font(NexusFont.tagline).foregroundStyle(p.flowInk)
            }
            .padding(NexusSpace.s6)
        }
        .background {
            LinearGradient(colors: [p.flowSoft, p.attentionSoft], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
        }
    }
}

#if os(iOS)
/// The iPhone shell: floating glass tab bar, search orb, companion accessory.
public struct NexusPhoneDemo: View {
    @State private var state: NexusCompanionState = .working(step: "Checking Westbrook HS…", detail: "Reading 9 of 14 · 40 s left")
    public init() { NexusFonts.register() }
    public var body: some View {
        NexusTabShell(companion: state, waitingCount: 2) {
            NavigationStack { NexusGallery().navigationTitle("Today") }
        } waiting: {
            NavigationStack { List(["SLP schedule", "Board memo"], id: \.self) { Text($0) }.navigationTitle("Waiting") }
        } work: {
            Text("Work")
        } people: {
            Text("People")
        } search: {
            NavigationStack { Text("Search") }
        }
        .nexusTheme(family: .nexus)
    }
}
#endif

#Preview("iPhone shell") {
    #if os(iOS)
    NexusPhoneDemo()
    #else
    Text("The tab shell is iPhone-only. Pick an iPhone simulator as the destination to see it.")
        .padding(40)
    #endif
}

#Preview("Companion states") {
    VStack(spacing: 12) {
        NexusCompanionAccessory(state: .idle, standalone: true)
        NexusCompanionAccessory(state: .working(step: "Checking Westbrook HS…", detail: "40 s left"), standalone: true)
        NexusCompanionAccessory(state: .needsYou(question: "Which baseline? · 1 of 3", count: 3), standalone: true)
        NexusCompanionAccessory(state: .suggesting(title: "Draft a note?", detail: "You review before sending", action: "Draft"), standalone: true)
        NexusCompanionAccessory(state: .done(title: "Applied 18 moves", detail: "Undo for 30 min"), standalone: true)
    }
    .padding(24)
    .frame(width: 380)
    .background(LinearGradient(colors: [.teal.opacity(0.35), .orange.opacity(0.25)], startPoint: .topLeading, endPoint: .bottomTrailing))
    .nexusTheme()
    .onAppear { NexusFonts.register() }
}

#Preview("Gallery · Nexus") { NexusGallery().nexusTheme(family: .nexus) }
#Preview("Gallery · Commons") { NexusGallery().nexusTheme(family: .commons) }
