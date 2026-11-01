// Nexus design tokens and components for SwiftUI (iOS 26 / macOS 26). Generated from tokens.json.
// Fonts ship inside this package; call `NexusFonts.register()` once at launch.

import SwiftUI

public enum NexusTheme: String, CaseIterable, Sendable {
    case nexus, commons, dark, commonsDark = "commons-dark", highContrast = "high-contrast"

    /// Picks the right theme for the family (Nexus or Commons), color scheme and contrast setting.
    public static func resolve(family: Family, scheme: ColorScheme, increasedContrast: Bool) -> NexusTheme {
        if increasedContrast && scheme == .light { return .highContrast }
        switch (family, scheme) {
        case (.nexus, .dark): return .dark
        case (.commons, .dark): return .commonsDark
        case (.commons, _): return .commons
        default: return .nexus
        }
    }
    public enum Family: Sendable { case nexus, commons }
}

public struct NexusPalette: Sendable {
    public let surfaceCanvas: Color
    public let surfaceRaised: Color
    public let surfaceSunken: Color
    public let surfaceHover: Color
    public let surfaceSelected: Color
    public let surfaceHeader: Color
    public let onHeader: Color
    public let onHeaderMuted: Color
    public let surfaceInverse: Color
    public let onInverse: Color
    public let scrim: Color
    public let ink: Color
    public let inkMuted: Color
    public let inkSubtle: Color
    public let inkDisabled: Color
    public let line: Color
    public let lineStrong: Color
    public let action: Color
    public let actionHover: Color
    public let onAction: Color
    public let accent: Color
    public let focus: Color
    public let focusOnHeader: Color
    public let flow: Color
    public let flowSoft: Color
    public let flowInk: Color
    public let agent: Color
    public let onAgent: Color
    public let attention: Color
    public let attentionSoft: Color
    public let attentionInk: Color
    public let success: Color
    public let successSoft: Color
    public let successInk: Color
    public let warning: Color
    public let warningSoft: Color
    public let warningInk: Color
    public let danger: Color
    public let dangerSoft: Color
    public let dangerInk: Color
    public let info: Color
    public let infoSoft: Color
    public let infoInk: Color
    public let chart1: Color
    public let chart2: Color
    public let chart3: Color
    public let chart4: Color
    public let chart5: Color
    public let chart6: Color
    public let chartGrid: Color
    public let person1: Color
    public let person2: Color
    public let person3: Color
    public let person4: Color

    public static func of(_ theme: NexusTheme) -> NexusPalette {
        switch theme {
        case .nexus: return NexusPalette(
            surfaceCanvas: Color(.sRGB, red: 0.9608, green: 0.9725, blue: 0.9765, opacity: 1),
            surfaceRaised: Color(.sRGB, red: 1.0000, green: 1.0000, blue: 1.0000, opacity: 1),
            surfaceSunken: Color(.sRGB, red: 0.9255, green: 0.9490, blue: 0.9569, opacity: 1),
            surfaceHover: Color(.sRGB, red: 0.9020, green: 0.9333, blue: 0.9451, opacity: 1),
            surfaceSelected: Color(.sRGB, red: 0.8627, green: 0.9255, blue: 0.9451, opacity: 1),
            surfaceHeader: Color(.sRGB, red: 0.1490, green: 0.2471, blue: 0.2863, opacity: 1),
            onHeader: Color(.sRGB, red: 0.9843, green: 0.9725, blue: 0.9412, opacity: 1),
            onHeaderMuted: Color(.sRGB, red: 0.7255, green: 0.7961, blue: 0.8196, opacity: 1),
            surfaceInverse: Color(.sRGB, red: 0.1098, green: 0.1686, blue: 0.1922, opacity: 1),
            onInverse: Color(.sRGB, red: 0.9608, green: 0.9725, blue: 0.9765, opacity: 1),
            scrim: Color(.sRGB, red: 0.0549, green: 0.1020, blue: 0.1255, opacity: 0.45),
            ink: Color(.sRGB, red: 0.1098, green: 0.1686, blue: 0.1922, opacity: 1),
            inkMuted: Color(.sRGB, red: 0.2745, green: 0.3529, blue: 0.3843, opacity: 1),
            inkSubtle: Color(.sRGB, red: 0.3412, green: 0.4196, blue: 0.4510, opacity: 1),
            inkDisabled: Color(.sRGB, red: 0.6039, green: 0.6706, blue: 0.6980, opacity: 1),
            line: Color(.sRGB, red: 0.8471, green: 0.8863, blue: 0.9020, opacity: 1),
            lineStrong: Color(.sRGB, red: 0.4980, green: 0.5765, blue: 0.6078, opacity: 1),
            action: Color(.sRGB, red: 0.6431, green: 0.3333, blue: 0.1804, opacity: 1),
            actionHover: Color(.sRGB, red: 0.5412, green: 0.2706, blue: 0.1412, opacity: 1),
            onAction: Color(.sRGB, red: 1.0000, green: 1.0000, blue: 1.0000, opacity: 1),
            accent: Color(.sRGB, red: 0.2039, green: 0.4039, blue: 0.5020, opacity: 1),
            focus: Color(.sRGB, red: 0.1216, green: 0.4353, blue: 0.5451, opacity: 1),
            focusOnHeader: Color(.sRGB, red: 0.9843, green: 0.9725, blue: 0.9412, opacity: 1),
            flow: Color(.sRGB, red: 0.1529, green: 0.5922, blue: 0.6902, opacity: 1),
            flowSoft: Color(.sRGB, red: 0.8863, green: 0.9529, blue: 0.9647, opacity: 1),
            flowInk: Color(.sRGB, red: 0.0706, green: 0.3922, blue: 0.4745, opacity: 1),
            agent: Color(.sRGB, red: 0.1490, green: 0.2471, blue: 0.2863, opacity: 1),
            onAgent: Color(.sRGB, red: 1.0000, green: 1.0000, blue: 1.0000, opacity: 1),
            attention: Color(.sRGB, red: 0.8000, green: 0.4431, blue: 0.2510, opacity: 1),
            attentionSoft: Color(.sRGB, red: 0.9843, green: 0.9294, blue: 0.8941, opacity: 1),
            attentionInk: Color(.sRGB, red: 0.5804, green: 0.2745, blue: 0.1216, opacity: 1),
            success: Color(.sRGB, red: 0.2392, green: 0.5412, blue: 0.3843, opacity: 1),
            successSoft: Color(.sRGB, red: 0.8941, green: 0.9490, blue: 0.9176, opacity: 1),
            successInk: Color(.sRGB, red: 0.1412, green: 0.3843, blue: 0.2471, opacity: 1),
            warning: Color(.sRGB, red: 0.7216, green: 0.5255, blue: 0.0431, opacity: 1),
            warningSoft: Color(.sRGB, red: 0.9843, green: 0.9451, blue: 0.8510, opacity: 1),
            warningInk: Color(.sRGB, red: 0.4784, green: 0.3333, blue: 0.0314, opacity: 1),
            danger: Color(.sRGB, red: 0.7216, green: 0.2510, blue: 0.1725, opacity: 1),
            dangerSoft: Color(.sRGB, red: 0.9765, green: 0.8980, blue: 0.8784, opacity: 1),
            dangerInk: Color(.sRGB, red: 0.5804, green: 0.1882, blue: 0.1216, opacity: 1),
            info: Color(.sRGB, red: 0.2471, green: 0.4510, blue: 0.6588, opacity: 1),
            infoSoft: Color(.sRGB, red: 0.9059, green: 0.9333, blue: 0.9725, opacity: 1),
            infoInk: Color(.sRGB, red: 0.1725, green: 0.3529, blue: 0.5255, opacity: 1),
            chart1: Color(.sRGB, red: 0.1529, green: 0.5922, blue: 0.6902, opacity: 1),
            chart2: Color(.sRGB, red: 0.2039, green: 0.4039, blue: 0.5020, opacity: 1),
            chart3: Color(.sRGB, red: 0.8000, green: 0.4431, blue: 0.2510, opacity: 1),
            chart4: Color(.sRGB, red: 0.6235, green: 0.7059, blue: 0.7373, opacity: 1),
            chart5: Color(.sRGB, red: 0.4784, green: 0.4157, blue: 0.6588, opacity: 1),
            chart6: Color(.sRGB, red: 0.3647, green: 0.5608, blue: 0.2471, opacity: 1),
            chartGrid: Color(.sRGB, red: 0.8902, green: 0.9176, blue: 0.9294, opacity: 1),
            person1: Color(.sRGB, red: 0.9529, green: 0.8627, blue: 0.8039, opacity: 1),
            person2: Color(.sRGB, red: 0.8392, green: 0.9098, blue: 0.9333, opacity: 1),
            person3: Color(.sRGB, red: 0.8980, green: 0.8745, blue: 0.9412, opacity: 1),
            person4: Color(.sRGB, red: 0.9137, green: 0.8941, blue: 0.8118, opacity: 1))
        case .commons: return NexusPalette(
            surfaceCanvas: Color(.sRGB, red: 0.9843, green: 0.9686, blue: 0.9333, opacity: 1),
            surfaceRaised: Color(.sRGB, red: 1.0000, green: 0.9922, blue: 0.9725, opacity: 1),
            surfaceSunken: Color(.sRGB, red: 0.9490, green: 0.9294, blue: 0.8863, opacity: 1),
            surfaceHover: Color(.sRGB, red: 0.9255, green: 0.9020, blue: 0.8510, opacity: 1),
            surfaceSelected: Color(.sRGB, red: 0.8902, green: 0.9255, blue: 0.8941, opacity: 1),
            surfaceHeader: Color(.sRGB, red: 0.9373, green: 0.9176, blue: 0.8745, opacity: 1),
            onHeader: Color(.sRGB, red: 0.1333, green: 0.2000, blue: 0.2275, opacity: 1),
            onHeaderMuted: Color(.sRGB, red: 0.3098, green: 0.3647, blue: 0.3451, opacity: 1),
            surfaceInverse: Color(.sRGB, red: 0.1216, green: 0.1647, blue: 0.1412, opacity: 1),
            onInverse: Color(.sRGB, red: 0.9843, green: 0.9686, blue: 0.9333, opacity: 1),
            scrim: Color(.sRGB, red: 0.1216, green: 0.1647, blue: 0.1412, opacity: 0.4),
            ink: Color(.sRGB, red: 0.1216, green: 0.1647, blue: 0.1412, opacity: 1),
            inkMuted: Color(.sRGB, red: 0.2941, green: 0.3412, blue: 0.3137, opacity: 1),
            inkSubtle: Color(.sRGB, red: 0.3725, green: 0.4078, blue: 0.3804, opacity: 1),
            inkDisabled: Color(.sRGB, red: 0.6627, green: 0.6471, blue: 0.5922, opacity: 1),
            line: Color(.sRGB, red: 0.8941, green: 0.8627, blue: 0.8039, opacity: 1),
            lineStrong: Color(.sRGB, red: 0.5843, green: 0.5529, blue: 0.4941, opacity: 1),
            action: Color(.sRGB, red: 0.2118, green: 0.3608, blue: 0.2941, opacity: 1),
            actionHover: Color(.sRGB, red: 0.1686, green: 0.2902, blue: 0.2353, opacity: 1),
            onAction: Color(.sRGB, red: 1.0000, green: 1.0000, blue: 1.0000, opacity: 1),
            accent: Color(.sRGB, red: 0.2039, green: 0.4039, blue: 0.5020, opacity: 1),
            focus: Color(.sRGB, red: 0.1216, green: 0.4353, blue: 0.5451, opacity: 1),
            focusOnHeader: Color(.sRGB, red: 0.1216, green: 0.4353, blue: 0.5451, opacity: 1),
            flow: Color(.sRGB, red: 0.3686, green: 0.5843, blue: 0.4941, opacity: 1),
            flowSoft: Color(.sRGB, red: 0.8980, green: 0.9373, blue: 0.9137, opacity: 1),
            flowInk: Color(.sRGB, red: 0.2275, green: 0.4157, blue: 0.3294, opacity: 1),
            agent: Color(.sRGB, red: 0.2118, green: 0.3608, blue: 0.2941, opacity: 1),
            onAgent: Color(.sRGB, red: 1.0000, green: 1.0000, blue: 1.0000, opacity: 1),
            attention: Color(.sRGB, red: 0.7059, green: 0.4784, blue: 0.1882, opacity: 1),
            attentionSoft: Color(.sRGB, red: 0.9725, green: 0.9255, blue: 0.8471, opacity: 1),
            attentionInk: Color(.sRGB, red: 0.5020, green: 0.3255, blue: 0.1020, opacity: 1),
            success: Color(.sRGB, red: 0.3098, green: 0.5412, blue: 0.3725, opacity: 1),
            successSoft: Color(.sRGB, red: 0.9020, green: 0.9412, blue: 0.8941, opacity: 1),
            successInk: Color(.sRGB, red: 0.1843, green: 0.3882, blue: 0.2510, opacity: 1),
            warning: Color(.sRGB, red: 0.6588, green: 0.4784, blue: 0.0706, opacity: 1),
            warningSoft: Color(.sRGB, red: 0.9765, green: 0.9333, blue: 0.8235, opacity: 1),
            warningInk: Color(.sRGB, red: 0.4510, green: 0.3137, blue: 0.0471, opacity: 1),
            danger: Color(.sRGB, red: 0.6902, green: 0.2667, blue: 0.1843, opacity: 1),
            dangerSoft: Color(.sRGB, red: 0.9686, green: 0.8941, blue: 0.8627, opacity: 1),
            dangerInk: Color(.sRGB, red: 0.5569, green: 0.2000, blue: 0.1333, opacity: 1),
            info: Color(.sRGB, red: 0.2902, green: 0.4235, blue: 0.5176, opacity: 1),
            infoSoft: Color(.sRGB, red: 0.9137, green: 0.9333, blue: 0.9490, opacity: 1),
            infoInk: Color(.sRGB, red: 0.2039, green: 0.3373, blue: 0.4314, opacity: 1),
            chart1: Color(.sRGB, red: 0.2118, green: 0.3608, blue: 0.2941, opacity: 1),
            chart2: Color(.sRGB, red: 0.2039, green: 0.4039, blue: 0.5020, opacity: 1),
            chart3: Color(.sRGB, red: 0.7059, green: 0.4784, blue: 0.1882, opacity: 1),
            chart4: Color(.sRGB, red: 0.7255, green: 0.6941, blue: 0.6353, opacity: 1),
            chart5: Color(.sRGB, red: 0.5412, green: 0.4353, blue: 0.6039, opacity: 1),
            chart6: Color(.sRGB, red: 0.4353, green: 0.5412, blue: 0.2275, opacity: 1),
            chartGrid: Color(.sRGB, red: 0.9255, green: 0.8980, blue: 0.8471, opacity: 1),
            person1: Color(.sRGB, red: 0.9451, green: 0.8627, blue: 0.7608, opacity: 1),
            person2: Color(.sRGB, red: 0.8588, green: 0.9059, blue: 0.8745, opacity: 1),
            person3: Color(.sRGB, red: 0.9098, green: 0.8745, blue: 0.9098, opacity: 1),
            person4: Color(.sRGB, red: 0.9255, green: 0.8902, blue: 0.7765, opacity: 1))
        case .dark: return NexusPalette(
            surfaceCanvas: Color(.sRGB, red: 0.0549, green: 0.1020, blue: 0.1255, opacity: 1),
            surfaceRaised: Color(.sRGB, red: 0.0824, green: 0.1451, blue: 0.1765, opacity: 1),
            surfaceSunken: Color(.sRGB, red: 0.0392, green: 0.0784, blue: 0.0941, opacity: 1),
            surfaceHover: Color(.sRGB, red: 0.1098, green: 0.1843, blue: 0.2196, opacity: 1),
            surfaceSelected: Color(.sRGB, red: 0.0941, green: 0.2275, blue: 0.2745, opacity: 1),
            surfaceHeader: Color(.sRGB, red: 0.0392, green: 0.0784, blue: 0.0941, opacity: 1),
            onHeader: Color(.sRGB, red: 0.9098, green: 0.9373, blue: 0.9451, opacity: 1),
            onHeaderMuted: Color(.sRGB, red: 0.6627, green: 0.7294, blue: 0.7569, opacity: 1),
            surfaceInverse: Color(.sRGB, red: 0.9098, green: 0.9373, blue: 0.9451, opacity: 1),
            onInverse: Color(.sRGB, red: 0.0549, green: 0.1020, blue: 0.1255, opacity: 1),
            scrim: Color(.sRGB, red: 0.0000, green: 0.0000, blue: 0.0000, opacity: 0.6),
            ink: Color(.sRGB, red: 0.9098, green: 0.9373, blue: 0.9451, opacity: 1),
            inkMuted: Color(.sRGB, red: 0.6627, green: 0.7294, blue: 0.7569, opacity: 1),
            inkSubtle: Color(.sRGB, red: 0.5412, green: 0.6196, blue: 0.6510, opacity: 1),
            inkDisabled: Color(.sRGB, red: 0.3020, green: 0.3804, blue: 0.4118, opacity: 1),
            line: Color(.sRGB, red: 0.1412, green: 0.2118, blue: 0.2471, opacity: 1),
            lineStrong: Color(.sRGB, red: 0.3569, green: 0.4627, blue: 0.5020, opacity: 1),
            action: Color(.sRGB, red: 0.9098, green: 0.5804, blue: 0.4157, opacity: 1),
            actionHover: Color(.sRGB, red: 0.9412, green: 0.6627, blue: 0.5137, opacity: 1),
            onAction: Color(.sRGB, red: 0.1333, green: 0.0706, blue: 0.0392, opacity: 1),
            accent: Color(.sRGB, red: 0.5255, green: 0.7490, blue: 0.8471, opacity: 1),
            focus: Color(.sRGB, red: 0.5255, green: 0.8392, blue: 0.9020, opacity: 1),
            focusOnHeader: Color(.sRGB, red: 0.5255, green: 0.8392, blue: 0.9020, opacity: 1),
            flow: Color(.sRGB, red: 0.2980, green: 0.7765, blue: 0.8667, opacity: 1),
            flowSoft: Color(.sRGB, red: 0.0745, green: 0.2118, blue: 0.2549, opacity: 1),
            flowInk: Color(.sRGB, red: 0.5255, green: 0.8392, blue: 0.9020, opacity: 1),
            agent: Color(.sRGB, red: 0.1686, green: 0.2745, blue: 0.3176, opacity: 1),
            onAgent: Color(.sRGB, red: 0.9098, green: 0.9373, blue: 0.9451, opacity: 1),
            attention: Color(.sRGB, red: 0.9098, green: 0.6039, blue: 0.4078, opacity: 1),
            attentionSoft: Color(.sRGB, red: 0.2275, green: 0.1412, blue: 0.0941, opacity: 1),
            attentionInk: Color(.sRGB, red: 0.9490, green: 0.7059, blue: 0.5569, opacity: 1),
            success: Color(.sRGB, red: 0.3608, green: 0.7490, blue: 0.5412, opacity: 1),
            successSoft: Color(.sRGB, red: 0.0902, green: 0.2000, blue: 0.1529, opacity: 1),
            successInk: Color(.sRGB, red: 0.5608, green: 0.8627, blue: 0.6824, opacity: 1),
            warning: Color(.sRGB, red: 0.8784, green: 0.7098, blue: 0.3059, opacity: 1),
            warningSoft: Color(.sRGB, red: 0.2275, green: 0.1843, blue: 0.0706, opacity: 1),
            warningInk: Color(.sRGB, red: 0.9255, green: 0.7882, blue: 0.4667, opacity: 1),
            danger: Color(.sRGB, red: 0.9373, green: 0.4980, blue: 0.4157, opacity: 1),
            dangerSoft: Color(.sRGB, red: 0.2392, green: 0.1020, blue: 0.0784, opacity: 1),
            dangerInk: Color(.sRGB, red: 0.9608, green: 0.6549, blue: 0.5882, opacity: 1),
            info: Color(.sRGB, red: 0.5412, green: 0.7059, blue: 0.8784, opacity: 1),
            infoSoft: Color(.sRGB, red: 0.0863, green: 0.1569, blue: 0.2275, opacity: 1),
            infoInk: Color(.sRGB, red: 0.6118, green: 0.7647, blue: 0.9176, opacity: 1),
            chart1: Color(.sRGB, red: 0.2980, green: 0.7765, blue: 0.8667, opacity: 1),
            chart2: Color(.sRGB, red: 0.5255, green: 0.7490, blue: 0.8471, opacity: 1),
            chart3: Color(.sRGB, red: 0.9098, green: 0.6039, blue: 0.4078, opacity: 1),
            chart4: Color(.sRGB, red: 0.3333, green: 0.4392, blue: 0.4745, opacity: 1),
            chart5: Color(.sRGB, red: 0.7020, green: 0.6431, blue: 0.8784, opacity: 1),
            chart6: Color(.sRGB, red: 0.6235, green: 0.8157, blue: 0.4980, opacity: 1),
            chartGrid: Color(.sRGB, red: 0.1137, green: 0.1804, blue: 0.2118, opacity: 1),
            person1: Color(.sRGB, red: 0.2902, green: 0.1843, blue: 0.1333, opacity: 1),
            person2: Color(.sRGB, red: 0.1137, green: 0.2353, blue: 0.2784, opacity: 1),
            person3: Color(.sRGB, red: 0.2000, green: 0.1608, blue: 0.2902, opacity: 1),
            person4: Color(.sRGB, red: 0.2314, green: 0.2118, blue: 0.1255, opacity: 1))
        case .commonsDark: return NexusPalette(
            surfaceCanvas: Color(.sRGB, red: 0.0824, green: 0.0941, blue: 0.0745, opacity: 1),
            surfaceRaised: Color(.sRGB, red: 0.1137, green: 0.1294, blue: 0.1059, opacity: 1),
            surfaceSunken: Color(.sRGB, red: 0.0627, green: 0.0706, blue: 0.0549, opacity: 1),
            surfaceHover: Color(.sRGB, red: 0.1490, green: 0.1686, blue: 0.1373, opacity: 1),
            surfaceSelected: Color(.sRGB, red: 0.1333, green: 0.2196, blue: 0.1725, opacity: 1),
            surfaceHeader: Color(.sRGB, red: 0.0627, green: 0.0706, blue: 0.0549, opacity: 1),
            onHeader: Color(.sRGB, red: 0.9373, green: 0.9137, blue: 0.8627, opacity: 1),
            onHeaderMuted: Color(.sRGB, red: 0.7098, green: 0.6784, blue: 0.6196, opacity: 1),
            surfaceInverse: Color(.sRGB, red: 0.9373, green: 0.9137, blue: 0.8627, opacity: 1),
            onInverse: Color(.sRGB, red: 0.0824, green: 0.0941, blue: 0.0745, opacity: 1),
            scrim: Color(.sRGB, red: 0.0000, green: 0.0000, blue: 0.0000, opacity: 0.6),
            ink: Color(.sRGB, red: 0.9373, green: 0.9137, blue: 0.8627, opacity: 1),
            inkMuted: Color(.sRGB, red: 0.7412, green: 0.7098, blue: 0.6510, opacity: 1),
            inkSubtle: Color(.sRGB, red: 0.6196, green: 0.5922, blue: 0.5412, opacity: 1),
            inkDisabled: Color(.sRGB, red: 0.3412, green: 0.3569, blue: 0.3216, opacity: 1),
            line: Color(.sRGB, red: 0.1725, green: 0.1922, blue: 0.1608, opacity: 1),
            lineStrong: Color(.sRGB, red: 0.4353, green: 0.4588, blue: 0.4078, opacity: 1),
            action: Color(.sRGB, red: 0.5608, green: 0.7765, blue: 0.6588, opacity: 1),
            actionHover: Color(.sRGB, red: 0.6510, green: 0.8314, blue: 0.7294, opacity: 1),
            onAction: Color(.sRGB, red: 0.0588, green: 0.1255, blue: 0.0941, opacity: 1),
            accent: Color(.sRGB, red: 0.6118, green: 0.7765, blue: 0.8667, opacity: 1),
            focus: Color(.sRGB, red: 0.6510, green: 0.8314, blue: 0.7294, opacity: 1),
            focusOnHeader: Color(.sRGB, red: 0.6510, green: 0.8314, blue: 0.7294, opacity: 1),
            flow: Color(.sRGB, red: 0.4980, green: 0.7490, blue: 0.6235, opacity: 1),
            flowSoft: Color(.sRGB, red: 0.1176, green: 0.2000, blue: 0.1569, opacity: 1),
            flowInk: Color(.sRGB, red: 0.6235, green: 0.8392, blue: 0.7216, opacity: 1),
            agent: Color(.sRGB, red: 0.1843, green: 0.2902, blue: 0.2392, opacity: 1),
            onAgent: Color(.sRGB, red: 0.9373, green: 0.9137, blue: 0.8627, opacity: 1),
            attention: Color(.sRGB, red: 0.8784, green: 0.6588, blue: 0.3608, opacity: 1),
            attentionSoft: Color(.sRGB, red: 0.2275, green: 0.1725, blue: 0.0824, opacity: 1),
            attentionInk: Color(.sRGB, red: 0.9373, green: 0.7569, blue: 0.5216, opacity: 1),
            success: Color(.sRGB, red: 0.4235, green: 0.7529, blue: 0.5412, opacity: 1),
            successSoft: Color(.sRGB, red: 0.1059, green: 0.1961, blue: 0.1333, opacity: 1),
            successInk: Color(.sRGB, red: 0.6196, green: 0.8627, blue: 0.6941, opacity: 1),
            warning: Color(.sRGB, red: 0.8902, green: 0.7333, blue: 0.3608, opacity: 1),
            warningSoft: Color(.sRGB, red: 0.2275, green: 0.1882, blue: 0.0784, opacity: 1),
            warningInk: Color(.sRGB, red: 0.9255, green: 0.7922, blue: 0.4706, opacity: 1),
            danger: Color(.sRGB, red: 0.9373, green: 0.5412, blue: 0.4471, opacity: 1),
            dangerSoft: Color(.sRGB, red: 0.2392, green: 0.1137, blue: 0.0824, opacity: 1),
            dangerInk: Color(.sRGB, red: 0.9608, green: 0.6667, blue: 0.5961, opacity: 1),
            info: Color(.sRGB, red: 0.6588, green: 0.7843, blue: 0.8706, opacity: 1),
            infoSoft: Color(.sRGB, red: 0.1098, green: 0.1647, blue: 0.2000, opacity: 1),
            infoInk: Color(.sRGB, red: 0.6588, green: 0.7843, blue: 0.8706, opacity: 1),
            chart1: Color(.sRGB, red: 0.4980, green: 0.7490, blue: 0.6235, opacity: 1),
            chart2: Color(.sRGB, red: 0.6118, green: 0.7765, blue: 0.8667, opacity: 1),
            chart3: Color(.sRGB, red: 0.8784, green: 0.6588, blue: 0.3608, opacity: 1),
            chart4: Color(.sRGB, red: 0.3608, green: 0.3882, blue: 0.3373, opacity: 1),
            chart5: Color(.sRGB, red: 0.7647, green: 0.6667, blue: 0.8157, opacity: 1),
            chart6: Color(.sRGB, red: 0.6902, green: 0.8000, blue: 0.5176, opacity: 1),
            chartGrid: Color(.sRGB, red: 0.1451, green: 0.1647, blue: 0.1333, opacity: 1),
            person1: Color(.sRGB, red: 0.2902, green: 0.2157, blue: 0.1255, opacity: 1),
            person2: Color(.sRGB, red: 0.1373, green: 0.2235, blue: 0.1765, opacity: 1),
            person3: Color(.sRGB, red: 0.2275, green: 0.1725, blue: 0.2392, opacity: 1),
            person4: Color(.sRGB, red: 0.2392, green: 0.2196, blue: 0.1255, opacity: 1))
        case .highContrast: return NexusPalette(
            surfaceCanvas: Color(.sRGB, red: 1.0000, green: 1.0000, blue: 1.0000, opacity: 1),
            surfaceRaised: Color(.sRGB, red: 1.0000, green: 1.0000, blue: 1.0000, opacity: 1),
            surfaceSunken: Color(.sRGB, red: 0.9294, green: 0.9294, blue: 0.9294, opacity: 1),
            surfaceHover: Color(.sRGB, red: 0.8784, green: 0.8784, blue: 0.8784, opacity: 1),
            surfaceSelected: Color(.sRGB, red: 0.8392, green: 0.9020, blue: 1.0000, opacity: 1),
            surfaceHeader: Color(.sRGB, red: 0.0000, green: 0.0000, blue: 0.0000, opacity: 1),
            onHeader: Color(.sRGB, red: 1.0000, green: 1.0000, blue: 1.0000, opacity: 1),
            onHeaderMuted: Color(.sRGB, red: 0.9020, green: 0.9020, blue: 0.9020, opacity: 1),
            surfaceInverse: Color(.sRGB, red: 0.0000, green: 0.0000, blue: 0.0000, opacity: 1),
            onInverse: Color(.sRGB, red: 1.0000, green: 1.0000, blue: 1.0000, opacity: 1),
            scrim: Color(.sRGB, red: 0.0000, green: 0.0000, blue: 0.0000, opacity: 0.7),
            ink: Color(.sRGB, red: 0.0000, green: 0.0000, blue: 0.0000, opacity: 1),
            inkMuted: Color(.sRGB, red: 0.1216, green: 0.1216, blue: 0.1216, opacity: 1),
            inkSubtle: Color(.sRGB, red: 0.2000, green: 0.2000, blue: 0.2000, opacity: 1),
            inkDisabled: Color(.sRGB, red: 0.4627, green: 0.4627, blue: 0.4627, opacity: 1),
            line: Color(.sRGB, red: 0.3490, green: 0.3490, blue: 0.3490, opacity: 1),
            lineStrong: Color(.sRGB, red: 0.0000, green: 0.0000, blue: 0.0000, opacity: 1),
            action: Color(.sRGB, red: 0.4784, green: 0.1804, blue: 0.0471, opacity: 1),
            actionHover: Color(.sRGB, red: 0.3608, green: 0.1255, blue: 0.0314, opacity: 1),
            onAction: Color(.sRGB, red: 1.0000, green: 1.0000, blue: 1.0000, opacity: 1),
            accent: Color(.sRGB, red: 0.0431, green: 0.2392, blue: 0.5686, opacity: 1),
            focus: Color(.sRGB, red: 0.0000, green: 0.0000, blue: 0.0000, opacity: 1),
            focusOnHeader: Color(.sRGB, red: 1.0000, green: 1.0000, blue: 1.0000, opacity: 1),
            flow: Color(.sRGB, red: 0.0000, green: 0.3765, blue: 0.4784, opacity: 1),
            flowSoft: Color(.sRGB, red: 0.8784, green: 0.9490, blue: 0.9686, opacity: 1),
            flowInk: Color(.sRGB, red: 0.0000, green: 0.2902, blue: 0.3686, opacity: 1),
            agent: Color(.sRGB, red: 0.0000, green: 0.0000, blue: 0.0000, opacity: 1),
            onAgent: Color(.sRGB, red: 1.0000, green: 1.0000, blue: 1.0000, opacity: 1),
            attention: Color(.sRGB, red: 0.5412, green: 0.2275, blue: 0.0627, opacity: 1),
            attentionSoft: Color(.sRGB, red: 0.9922, green: 0.9216, blue: 0.8784, opacity: 1),
            attentionInk: Color(.sRGB, red: 0.4196, green: 0.1647, blue: 0.0314, opacity: 1),
            success: Color(.sRGB, red: 0.0431, green: 0.3647, blue: 0.1647, opacity: 1),
            successSoft: Color(.sRGB, red: 0.8902, green: 0.9569, blue: 0.9098, opacity: 1),
            successInk: Color(.sRGB, red: 0.0392, green: 0.2902, blue: 0.1333, opacity: 1),
            warning: Color(.sRGB, red: 0.4196, green: 0.2902, blue: 0.0000, opacity: 1),
            warningSoft: Color(.sRGB, red: 1.0000, green: 0.9490, blue: 0.8000, opacity: 1),
            warningInk: Color(.sRGB, red: 0.3529, green: 0.2392, blue: 0.0000, opacity: 1),
            danger: Color(.sRGB, red: 0.6078, green: 0.1098, blue: 0.0471, opacity: 1),
            dangerSoft: Color(.sRGB, red: 0.9922, green: 0.8941, blue: 0.8745, opacity: 1),
            dangerInk: Color(.sRGB, red: 0.4784, green: 0.0863, blue: 0.0314, opacity: 1),
            info: Color(.sRGB, red: 0.0431, green: 0.2392, blue: 0.5686, opacity: 1),
            infoSoft: Color(.sRGB, red: 0.8902, green: 0.9255, blue: 0.9765, opacity: 1),
            infoInk: Color(.sRGB, red: 0.0431, green: 0.2392, blue: 0.5686, opacity: 1),
            chart1: Color(.sRGB, red: 0.0000, green: 0.3765, blue: 0.4784, opacity: 1),
            chart2: Color(.sRGB, red: 0.0431, green: 0.2392, blue: 0.5686, opacity: 1),
            chart3: Color(.sRGB, red: 0.5412, green: 0.2275, blue: 0.0627, opacity: 1),
            chart4: Color(.sRGB, red: 0.4627, green: 0.4627, blue: 0.4627, opacity: 1),
            chart5: Color(.sRGB, red: 0.2941, green: 0.1647, blue: 0.4784, opacity: 1),
            chart6: Color(.sRGB, red: 0.1843, green: 0.3529, blue: 0.0706, opacity: 1),
            chartGrid: Color(.sRGB, red: 0.7686, green: 0.7686, blue: 0.7686, opacity: 1),
            person1: Color(.sRGB, red: 1.0000, green: 0.8784, blue: 0.8000, opacity: 1),
            person2: Color(.sRGB, red: 0.8118, green: 0.9098, blue: 0.9490, opacity: 1),
            person3: Color(.sRGB, red: 0.9020, green: 0.8627, blue: 0.9608, opacity: 1),
            person4: Color(.sRGB, red: 0.9412, green: 0.9098, blue: 0.7843, opacity: 1))
        }
    }
}

private struct NexusPaletteKey: EnvironmentKey { static let defaultValue = NexusPalette.of(.nexus) }
public extension EnvironmentValues {
    var nexus: NexusPalette { get { self[NexusPaletteKey.self] } set { self[NexusPaletteKey.self] = newValue } }
}

/// Apply at the root: `.nexusTheme(family: .commons)`; reads color scheme and contrast automatically.
public struct NexusThemeModifier: ViewModifier {
    let family: NexusTheme.Family
    @Environment(\.colorScheme) private var scheme
    @Environment(\.colorSchemeContrast) private var contrast
    public func body(content: Content) -> some View {
        let p = NexusPalette.of(.resolve(family: family, scheme: scheme, increasedContrast: contrast == .increased))
        content.environment(\.nexus, p).tint(p.accent).foregroundStyle(p.ink).background(p.surfaceCanvas)
    }
}
public extension View { func nexusTheme(family: NexusTheme.Family = .nexus) -> some View { modifier(NexusThemeModifier(family: family)) } }

public enum NexusFont {
    // Display (Newsreader) scales with Dynamic Type via relativeTo:
    #if os(iOS)
    public static let largeTitle = Font.custom("Newsreader-Regular", size: 34, relativeTo: .largeTitle)
    public static let title1 = Font.custom("Newsreader-Regular", size: 28, relativeTo: .title)
    public static let title2 = Font.custom("Newsreader-Regular", size: 22, relativeTo: .title2)
    public static let title3 = Font.custom("PublicSans-Medium", size: 20, relativeTo: .title3)
    public static let headline = Font.custom("PublicSans-SemiBold", size: 17, relativeTo: .headline)
    public static let body = Font.custom("PublicSans-Regular", size: 17, relativeTo: .body)
    public static let callout = Font.custom("PublicSans-Regular", size: 16, relativeTo: .callout)
    public static let subheadline = Font.custom("PublicSans-Regular", size: 15, relativeTo: .subheadline)
    public static let footnote = Font.custom("PublicSans-Regular", size: 13, relativeTo: .footnote)
    public static let caption1 = Font.custom("PublicSans-Regular", size: 12, relativeTo: .caption)
    public static let caption2 = Font.custom("PublicSans-Medium", size: 11, relativeTo: .caption2)
    #endif
    #if os(macOS)
    public static let largeTitle = Font.custom("Newsreader-Regular", size: 26, relativeTo: .largeTitle)
    public static let title1 = Font.custom("Newsreader-Regular", size: 22, relativeTo: .title)
    public static let title2 = Font.custom("Newsreader-Regular", size: 17, relativeTo: .title2)
    public static let title3 = Font.custom("PublicSans-Medium", size: 15, relativeTo: .title3)
    public static let headline = Font.custom("PublicSans-SemiBold", size: 13, relativeTo: .headline)
    public static let body = Font.custom("PublicSans-Regular", size: 13, relativeTo: .body)
    public static let callout = Font.custom("PublicSans-Regular", size: 12, relativeTo: .callout)
    public static let subheadline = Font.custom("PublicSans-Regular", size: 11, relativeTo: .subheadline)
    public static let footnote = Font.custom("PublicSans-Regular", size: 10, relativeTo: .footnote)
    public static let caption1 = Font.custom("PublicSans-Regular", size: 10, relativeTo: .caption)
    public static let caption2 = Font.custom("PublicSans-Medium", size: 10, relativeTo: .caption2)
    #endif
    public static let code = Font.custom("IBMPlexMono-Regular", size: 13, relativeTo: .body)
    public static let tagline = Font.custom("Caveat-Medium", size: 22, relativeTo: .title3)
}

public enum NexusSpace {
    public static let s0_5: CGFloat = 2
    public static let s1: CGFloat = 4
    public static let s2: CGFloat = 8
    public static let s3: CGFloat = 12
    public static let s4: CGFloat = 16
    public static let s5: CGFloat = 20
    public static let s6: CGFloat = 24
    public static let s8: CGFloat = 32
    public static let s10: CGFloat = 40
    public static let s12: CGFloat = 48
    public static let s16: CGFloat = 64
    public static let s20: CGFloat = 80
    public static let s24: CGFloat = 96
}

public enum NexusRadius {
    public static let xs: CGFloat = 4
    public static let sm: CGFloat = 6
    public static let md: CGFloat = 10
    public static let lg: CGFloat = 16
    public static let window: CGFloat = 12
    public static let xl: CGFloat = 24
    public static let sheet: CGFloat = 28
    public static let pill: CGFloat = 999
}

public enum NexusSize {
    public static let controlSm: CGFloat = 32
    public static let controlMd: CGFloat = 40
    public static let controlLg: CGFloat = 48
    public static let macControl: CGFloat = 28
    public static let macControlSm: CGFloat = 22
    public static let touchMin: CGFloat = 44
    public static let iconXs: CGFloat = 12
    public static let iconSm: CGFloat = 16
    public static let iconMd: CGFloat = 20
    public static let iconLg: CGFloat = 24
    public static let iconXl: CGFloat = 32
    public static let avatarXs: CGFloat = 20
    public static let avatarSm: CGFloat = 28
    public static let avatarMd: CGFloat = 36
    public static let avatarLg: CGFloat = 48
    public static let headerHeight: CGFloat = 56
    public static let railWidth: CGFloat = 300
    public static let panelWidth: CGFloat = 400
    public static let sidebarWidth: CGFloat = 248
    public static let contentMax: CGFloat = 1280
    public static let readingMax: CGFloat = 680
    public static let iosNavbar: CGFloat = 44
    public static let iosTabbar: CGFloat = 49
    public static let iosRow: CGFloat = 44
    public static let macToolbar: CGFloat = 52
    public static let macSidebar: CGFloat = 220
    public static let macRow: CGFloat = 28
    public static let macInspector: CGFloat = 280
}

public enum NexusMotion {
    public static let instant: Double = 0.08
    public static let fast: Double = 0.16
    public static let base: Double = 0.24
    public static let slow: Double = 0.36
    public static let stagger: Double = 0.06
    public static let count: Double = 0.9
    public static let flow: Double = 2.4
    public static let glow: Double = 3.2
    /// Sheets and panels: a gentle spring with no overshoot.
    public static let spring = Animation.spring(response: 0.36, dampingFraction: 0.9)
    /// Small arrivals only (chips, checks): slight overshoot.
    public static let pop = Animation.spring(response: 0.32, dampingFraction: 0.7)
    public static let easeOut = Animation.timingCurve(0.2, 0, 0, 1, duration: 0.24)
    public static let flowEase = Animation.timingCurve(0.45, 0.05, 0.55, 0.95, duration: 2.4)
    /// Staggered reveal: `.animation(NexusMotion.reveal(index: i), value: shown)`
    public static func reveal(index: Int) -> Animation { .easeOut(duration: base).delay(Double(min(index, 8)) * stagger) }
}

// MARK: - Core styles
public struct NexusPrimaryButtonStyle: ButtonStyle {
    @Environment(\.nexus) private var p
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.custom("PublicSans-SemiBold", size: 15, relativeTo: .body))
            .padding(.horizontal, 20).frame(minHeight: NexusSize.touchMin)
            .foregroundStyle(p.onAction).background(configuration.isPressed ? p.actionHover : p.action, in: RoundedRectangle(cornerRadius: NexusRadius.md))
    }
}
public struct NexusCard<Content: View>: View {
    @Environment(\.nexus) private var p
    let content: Content
    public init(@ViewBuilder content: () -> Content) { self.content = content() }
    public var body: some View {
        content.padding(NexusSpace.s6).frame(maxWidth: .infinity, alignment: .leading)
            .background(p.surfaceRaised, in: RoundedRectangle(cornerRadius: NexusRadius.lg))
            .overlay(RoundedRectangle(cornerRadius: NexusRadius.lg).stroke(p.line, lineWidth: 1))
    }
}
public struct NexusTrustFooter: View {
    @Environment(\.nexus) private var p
    let items: [String]
    public init(_ items: [String]) { self.items = items }
    public var body: some View {
        Label(items.joined(separator: " · "), systemImage: "checkmark.shield").font(.footnote).foregroundStyle(p.inkSubtle)
    }
}

// MARK: - Liquid glass (macOS 26 / iOS 26)
@available(iOS 26.0, macOS 26.0, *)
public extension View {
    /// Floating glass for controls and navigation (never content). Falls back to solid when Reduce Transparency is on.
    func nexusGlass<S: Shape>(in shape: S, prominent: Bool = false) -> some View {
        modifier(NexusGlass(shape: shape, prominent: prominent))
    }
}

@available(iOS 26.0, macOS 26.0, *)
public struct NexusGlass<S: Shape>: ViewModifier {
    let shape: S
    let prominent: Bool
    @Environment(\.nexus) private var p
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    public func body(content: Content) -> some View {
        if reduceTransparency {
            content.background(p.surfaceRaised, in: shape).overlay(shape.stroke(p.line, lineWidth: 1))
        } else if prominent {
            content.glassEffect(.regular.tint(p.action).interactive(), in: shape)
        } else {
            content.glassEffect(.regular.interactive(), in: shape)
        }
    }
}

/// The breathing agent orb used in the companion capsule, Quick Ask and sheets.
public struct NexusAgentOrb: View {
    @Environment(\.nexus) private var p
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breathe = false
    var size: CGFloat
    public init(size: CGFloat = 36) { self.size = size }
    public var body: some View {
        Circle()
            .fill(RadialGradient(colors: [p.flow.opacity(0.85), p.flow, p.agent], center: .init(x: 0.35, y: 0.3), startRadius: 1, endRadius: size * 0.7))
            .frame(width: size, height: size)
            .overlay(Image(systemName: "circle.grid.cross.fill").font(.system(size: size * 0.4)).foregroundStyle(p.onAgent))
            .shadow(color: p.flow.opacity(breathe ? 0.45 : 0.15), radius: breathe ? 10 : 4)
            .onAppear { if !reduceMotion { withAnimation(NexusMotion.flowEase.repeatForever(autoreverses: true)) { breathe = true } } }
            .accessibilityLabel("Agent")
    }
}

// MARK: - Companion accessory (iOS 26 tab bar accessory; also usable as a capsule on macOS)
/// The states of the Nexus companion capsule (see IOSCompanion).
public enum NexusCompanionState: Equatable {
    case idle
    case listening(transcript: String)
    case working(step: String, detail: String)
    case needsYou(question: String, count: Int)
    case suggesting(title: String, detail: String, action: String)
    case done(title: String, detail: String)
}

/// On iPhone: `.tabViewBottomAccessory { NexusCompanionAccessory(state: s) }` (switches to a compact
/// layout when the tab bar minimizes). On Mac or elsewhere, pass `standalone: true` to get its own glass capsule.
public struct NexusCompanionAccessory: View {
    @Environment(\.nexus) private var p
    #if os(iOS)
    @Environment(\.tabViewBottomAccessoryPlacement) private var placement
    private var isInline: Bool { placement == .inline }
    #else
    private var isInline: Bool { false }
    #endif
    let state: NexusCompanionState
    let standalone: Bool
    var onPrimary: () -> Void
    public init(state: NexusCompanionState, standalone: Bool = false, onPrimary: @escaping () -> Void = {}) {
        self.state = state; self.standalone = standalone; self.onPrimary = onPrimary
    }

    private var lines: (String, String) {
        switch state {
        case .idle: return ("Ask Nexus…", "")
        case .listening(let t): return (t.isEmpty ? "Listening…" : t, "Listening")
        case .working(let s, let d): return (s, d)
        case .needsYou(let q, _): return ("Needs your answer", q)
        case .suggesting(let t, let d, _): return (t, d)
        case .done(let t, let d): return (t, d)
        }
    }
    private var needsYou: Bool { if case .needsYou = state { return true } else { return false } }

    public var body: some View {
        let row = HStack(spacing: 10) {
            NexusAgentOrb(size: isInline ? 28 : 34)
            VStack(alignment: .leading, spacing: 0) {
                Text(lines.0).font(NexusFont.subheadline.weight(.medium)).foregroundStyle(state == .idle ? p.inkMuted : p.ink)
                if !isInline, !lines.1.isEmpty { Text(lines.1).font(NexusFont.caption1).foregroundStyle(p.inkMuted) }
            }
            .lineLimit(1)
            Spacer(minLength: 4)
            trailing
        }
        .padding(.horizontal, 8)
        .padding(.vertical, standalone ? 8 : 0)
        .contentTransition(.opacity)
        .animation(NexusMotion.spring, value: state)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Nexus, \(lines.0). \(lines.1)")

        if standalone {
            row.nexusGlass(in: Capsule())
                .overlay { if needsYou { Capsule().strokeBorder(p.attention, lineWidth: 1.5) } }
        } else {
            row.overlay { if needsYou { Capsule().strokeBorder(p.attention, lineWidth: 1.5) } }
        }
    }
    @ViewBuilder private var trailing: some View {
        switch state {
        case .idle: Button(action: onPrimary) { Image(systemName: "mic") }.buttonStyle(.plain).accessibilityLabel("Dictate")
        case .working: Button(action: onPrimary) { Image(systemName: "pause.fill") }.buttonStyle(.plain).accessibilityLabel("Pause")
        case .needsYou(_, let n): Text("\(n)").font(NexusFont.caption1.bold()).padding(6).background(p.attention, in: Circle()).foregroundStyle(p.onAction)
        case .suggesting(_, _, let a): Button(a, action: onPrimary).buttonStyle(.glassProminent).tint(p.action)
        case .done: Button("Undo", action: onPrimary).buttonStyle(.glass)
        case .listening: EmptyView()
        }
    }
}

#if os(iOS)
/// The Nexus iPhone shell: floating glass tabs, Search as its own orb, the companion above.
public struct NexusTabShell<Today: View, Waiting: View, Work: View, People: View, Search: View>: View {
    @State private var selection = "today"
    let companion: NexusCompanionState
    let waitingCount: Int
    let today: Today, waiting: Waiting, work: Work, people: People, search: Search
    public init(companion: NexusCompanionState, waitingCount: Int = 0,
                @ViewBuilder today: () -> Today, @ViewBuilder waiting: () -> Waiting, @ViewBuilder work: () -> Work,
                @ViewBuilder people: () -> People, @ViewBuilder search: () -> Search) {
        self.companion = companion; self.waitingCount = waitingCount
        self.today = today(); self.waiting = waiting(); self.work = work(); self.people = people(); self.search = search()
    }
    public var body: some View {
        TabView(selection: $selection) {
            Tab("Today", systemImage: "house", value: "today") { today }
            Tab("Waiting", systemImage: "tray", value: "waiting") { waiting }.badge(waitingCount)
            Tab("Work", systemImage: "folder", value: "work") { work }
            Tab("People", systemImage: "person.2", value: "people") { people }
            Tab(value: "search", role: .search) { search }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .tabViewBottomAccessory { NexusCompanionAccessory(state: companion) }
    }
}
#endif
