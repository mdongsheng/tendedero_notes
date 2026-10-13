import AppKit
import QuickLookThumbnailing

/// How a note that is not text hangs: as its own preview, the way Finder
/// shows it, in the same glass frame. Until Quick Look has drawn that
/// preview, and for files it cannot draw, it hangs as a sheet of paper that
/// names the file's type, ".md", ".pptx", ".docx", with its icon and name.
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

    /// What a file is, as it is written at the end of its name: ".md",
    /// ".pptx", ".docx". A file without one says what kind it is.
    static func typeLabel(for url: URL) -> String {
        let ext = url.pathExtension
        if !ext.isEmpty { return "." + ext.lowercased() }
        return (try? url.resourceValues(forKeys: [.localizedTypeDescriptionKey]).localizedTypeDescription) ?? ""
    }

    /// For a file Quick Look cannot preview: its type in large letters, so it
    /// reads from across the screen, over its icon and under it its name, on
    /// the same paper as a written note.
    private static func iconSheet(for url: URL) -> NSImage? {
        let s = Layout.size.scale
        let sheet = CGSize(width: Layout.cardWidth - 14, height: (Layout.sheetMaxHeight * 0.86).rounded())
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

        let iconSide = (32 * s).rounded()
        var y = 7 * s
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icon.draw(in: NSRect(x: (sheet.width - iconSide) / 2, y: y, width: iconSide, height: iconSide),
                  from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
        y += iconSide + 2 * s

        let centred = NSMutableParagraphStyle()
        centred.alignment = .center
        centred.lineBreakMode = .byTruncatingMiddle
        let type = NSAttributedString(string: typeLabel(for: url), attributes: [
            .font: NSFont.systemFont(ofSize: 17 * s, weight: .bold),
            .foregroundColor: NoteCard.ink,
            .paragraphStyle: centred,
        ])
        let typeHeight = ceil(19 * s * 1.25)
        type.draw(with: NSRect(x: 6 * s, y: y, width: sheet.width - 12 * s, height: typeHeight),
                  options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine])
        y += typeHeight

        let name = NSAttributedString(string: url.lastPathComponent, attributes: [
            .font: NSFont.systemFont(ofSize: 9 * s, weight: .medium),
            .foregroundColor: NoteCard.pencil,
            .paragraphStyle: centred,
        ])
        name.draw(with: NSRect(x: 8 * s, y: y, width: sheet.width - 16 * s, height: max(0, sheet.height - y - 4 * s)),
                  options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine])
        NSGraphicsContext.restoreGraphicsState()

        guard let image = cg.makeImage() else { return nil }
        return NSImage(cgImage: image, size: sheet)
    }
}
