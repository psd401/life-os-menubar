import CoreText
import Foundation

/// Registers the bundled Nexus fonts (Newsreader, Public Sans, IBM Plex Mono, Caveat).
/// Call once at launch, e.g. in your App's `init()`. Safe to call more than once.
public enum NexusFonts {
    /// Runs once, thread-safely (Swift initializes static lets lazily and atomically).
    private static let registration: Void = {
        let urls = Bundle.module.urls(forResourcesWithExtension: "ttf", subdirectory: "Fonts") ?? []
        for url in urls {
            var error: Unmanaged<CFError>?
            if !CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) {
                // Already-registered fonts report an error; that's fine.
                error?.release()
            }
        }
    }()

    public static func register() { _ = registration }

    /// PostScript names of the bundled fonts, for checking registration.
    public static let names = [
        "Newsreader-Regular", "Newsreader-Italic", "Newsreader-Medium", "Newsreader-MediumItalic",
        "PublicSans-Regular", "PublicSans-Medium", "PublicSans-SemiBold", "PublicSans-Bold",
        "IBMPlexMono-Regular", "IBMPlexMono-Medium", "Caveat-Medium",
    ]
}
