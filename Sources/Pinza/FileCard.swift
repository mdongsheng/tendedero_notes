import AppKit
import QuickLookThumbnailing

/// How a note that is not text hangs: as its own preview, the way Finder
/// shows it, in the same glass frame. Until Quick Look has drawn that
/// preview, and for files it cannot draw, it hangs as a sheet of paper with
/// the file's icon and name.
enum FileCard {
    /// Shown at once. An image is its own thumbnail straight away.
    static func placeholder(for url: URL) -> NSImage? {
        if Notes.isImage(url), let thumb = imageThumbnail(url) { return thumb }
        return iconSheet(for: url)
    }

    /// Asks Quick Look for the file's preview, as large as a card shows it.
    /// Calls back on the main thread, only with a preview.
    static func preview(for url: URL, done: @escaping @MainActor (NSImage) -> Void) {
        let size = CGSize(width: Layout.cardWidth - 14, height: Layout.sheetMaxHeight)
        let request = QLThumbnailGenerator.Request(fileAt: url, size: size, scale: 2,
                                                   representationTypes: .thumbnail)
        QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { thumbnail, _ in
            guard let cg = thumbnail?.cgImage else { return }
            let image = NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
            DispatchQueue.main.async {
                MainActor.assumeIsolated { done(image) }
            }
        }
    }

    /// The same size a card shows, twice over for a Retina screen.
    private static func imageThumbnail(_ url: URL) -> NSImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: Int(320 * Layout.size.scale),
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
    }

    /// The file's icon above its name, on the same paper as a written note.
    private static func iconSheet(for url: URL) -> NSImage? {
        let s = Layout.size.scale
        let sheet = CGSize(width: Layout.cardWidth - 14, height: (Layout.sheetMaxHeight * 0.82).rounded())
        let scale: CGFloat = 2
        let pw = Int(sheet.width * scale), ph = Int(sheet.height * scale)
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let cg = CGContext(data: nil, width: pw, height: ph, bitsPerComponent: 8, bytesPerRow: 0,
                                 space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        cg.translateBy(x: 0, y: CGFloat(ph))
        cg.scaleBy(x: scale, y: -scale)

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: cg, flipped: true)
        NoteCard.paper.setFill()
        NSRect(origin: .zero, size: sheet).fill()

        let iconSide = (40 * s).rounded()
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icon.draw(in: NSRect(x: (sheet.width - iconSide) / 2, y: 8 * s, width: iconSide, height: iconSide),
                  from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byTruncatingMiddle
        let name = NSAttributedString(string: url.lastPathComponent, attributes: [
            .font: NSFont.systemFont(ofSize: 10 * s, weight: .medium),
            .foregroundColor: NoteCard.ink,
            .paragraphStyle: paragraph,
        ])
        let top = 8 * s + iconSide + 5 * s
        name.draw(with: NSRect(x: 8 * s, y: top, width: sheet.width - 16 * s, height: sheet.height - top - 6 * s),
                  options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine])
        NSGraphicsContext.restoreGraphicsState()

        guard let image = cg.makeImage() else { return nil }
        return NSImage(cgImage: image, size: sheet)
    }
}
