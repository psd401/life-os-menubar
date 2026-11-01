# NexusKit

SwiftUI tokens and components for the Nexus design system (iOS 26 / macOS 26).

## Build
1. Double-click `Package.swift` to open it in Xcode 26.
2. Pick **My Mac** as the run destination and press ⌘B.
3. Pick an **iPhone 17 simulator** and press ⌘B again.
4. Open `Sources/NexusKit/NexusGallery.swift` or `NexusGallery2.swift` and show the canvas (⌥⌘↩) to see the previews.

## Use in an app
- Add this package (File ▸ Add Package Dependencies ▸ Add Local…).
- At launch: `NexusFonts.register()`.
- At the root view: `.nexusTheme(family: .nexus)` (or `.commons`).

## What's in it
| File | Contents |
|---|---|
| `Nexus.swift` | Palette for all five themes, `.nexusTheme`, fonts, spacing, radius, size and motion constants, `.nexusGlass`, `NexusAgentOrb`, `NexusCompanionAccessory`, `NexusTabShell` (iOS) |
| `NexusFonts.swift` | `NexusFonts.register()` |
| `NexusSupport.swift` | Ordinal and sequential chart ramps, `NexusFlowLayout`, `NexusPanel`, `NexusSectionHeader`, `NexusLegend`, `NexusScopeChip`, `NexusBadge`, `NexusHatch`, `NexusMark`, `NexusFormat` |
| `NexusAvatar.swift` | `NexusAgentAvatar` (12 states, honors Reduce Motion), `NexusAgentStatusLine` |
| `NexusCharts.swift` | `NexusStackedBarChart`, `NexusDumbbellChart`, `NexusSlopeChart`, `NexusScatterQuadrant`, `NexusHistogram`, `NexusCalendarHeatmap`, `NexusStackedAreaChart`, `NexusWaterfallChart`, `NexusBulletChart`, `NexusSchoolMap` |
| `NexusAgentControl.swift` | `NexusPlanPreview`, `NexusSteerQueue`, `NexusTakeoverBar`, `NexusToolCallCard`, `NexusAgentErrorRecovery`, `NexusStandingTask`, `NexusOutputFeedback`, `NexusActivityLog`, `NexusMemoryGoals` |
| `NexusDataGrid.swift` | `NexusDataGrid`, `NexusGridCell`, `NexusDataCards`, `NexusPivotTable`, `NexusDiffTable`, `NexusColumnProfile` |
| `NexusGraph.swift` | `NexusGraphView`, `NexusGraphNodeChip`, `NexusGraphInspector`, `NexusGraphPathView`, `NexusGraphLayout` |
| `NexusGallery.swift`, `NexusGallery2.swift` | Xcode canvas previews with sample district data |

Small groups (n < 10) are suppressed by the charts and tables, the same way they are on the web.
