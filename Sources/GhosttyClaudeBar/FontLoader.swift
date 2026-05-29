import AppKit
import CoreText

/// Registers the app-bundled fonts at launch so SwiftUI `Font.custom` can use
/// them. Bundling (vs relying on system fonts) is what gives the UI a
/// non-generic typographic signature: Martian Mono (condensed, techy — the
/// "mission control" display face) + IBM Plex Mono (the telemetry face).
enum FontLoader {
    static func registerBundledFonts() {
        guard let urls = Bundle.module.urls(forResourcesWithExtension: "ttf", subdirectory: "Fonts"),
              !urls.isEmpty else { return }
        CTFontManagerRegisterFontURLs(urls as CFArray, .process, true, nil)
    }

    /// Debug: family names currently available that match a needle.
    static func families(matching needle: String) -> [String] {
        NSFontManager.shared.availableFontFamilies
            .filter { $0.localizedCaseInsensitiveContains(needle) }
    }
}
