import SwiftUI
import AppKit
import CoreText

/// Provides Font Awesome Brand icons for use in SwiftUI views.
enum FontAwesome {
    private static var _font: CTFont?
    private static var registered = false

    /// Register the Font Awesome Brands font from the app bundle.
    static func registerFonts() {
        guard !registered else { return }
        registered = true

        guard let url = fontURL() else { return }

        // Register with the font system
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)

        // Pre-create the CTFont directly from the file as a guaranteed fallback
        if let provider = CGDataProvider(url: url as CFURL),
           let cgFont = CGFont(provider) {
            _font = CTFontCreateWithGraphicsFont(cgFont, 14, nil, nil)
        }
    }

    private static func fontURL() -> URL? {
        // Search multiple possible locations in the bundle
        let resourcesDir = Bundle.main.resourceURL
        let candidates: [URL?] = [
            resourcesDir?.appendingPathComponent("FontAwesome6Brands-Regular.otf"),
            resourcesDir?.appendingPathComponent("Resources/FontAwesome6Brands-Regular.otf"),
            Bundle.main.url(forResource: "FontAwesome6Brands-Regular", withExtension: "otf"),
            Bundle.main.url(forResource: "FontAwesome6Brands-Regular", withExtension: "otf", subdirectory: "Resources"),
        ]
        return candidates.compactMap { $0 }.first { FileManager.default.fileExists(atPath: $0.path) }
    }

    // Unicode codepoints for FA 6 Brands
    static let chrome  = "\u{f268}"
    static let safari  = "\u{f267}"

    /// Create an NSFont at the given size using the pre-loaded CTFont.
    static func brandsFont(size: CGFloat) -> NSFont {
        if let base = _font {
            return CTFontCreateCopyWithAttributes(base, size, nil, nil) as NSFont
        }
        // If pre-load failed, try system font manager
        if let font = NSFont(name: "FontAwesome6Brands-Regular", size: size) {
            return font
        }
        return NSFont.systemFont(ofSize: size)
    }
}

/// A SwiftUI view that renders a Font Awesome Brands icon via NSTextField (bypasses SwiftUI font bugs).
struct FAIcon: NSViewRepresentable {
    let icon: String
    var size: CGFloat = 14

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField(labelWithString: icon)
        field.font = FontAwesome.brandsFont(size: size)
        field.alignment = .center
        field.setContentHuggingPriority(.required, for: .horizontal)
        field.setContentHuggingPriority(.required, for: .vertical)
        return field
    }

    func updateNSView(_ field: NSTextField, context: Context) {
        field.stringValue = icon
        field.font = FontAwesome.brandsFont(size: size)
    }
}
