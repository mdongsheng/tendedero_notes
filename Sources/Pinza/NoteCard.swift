import AppKit

/// Draws a note as the picture that hangs on the line: a sheet of paper with
/// its first line as the title and as much of the rest as fits. It takes the
/// place a screenshot's thumbnail had, so the card, the drag, the flight and
/// the fall all work with it unchanged.
enum NoteCard {
    /// Warm white paper, the same in light and dark mode, like a real sheet.
    static let paper = NSColor(srgbRed: 1.0, green: 0.988, blue: 0.957, alpha: 1)
    static let ink = NSColor(srgbRed: 0.13, green: 0.13, blue: 0.15, alpha: 1)
    static let pencil = NSColor(srgbRed: 0.36, green: 0.36, blue: 0.40, alpha: 1)

    /// The sheet's size in points: as wide as a card holds, and only as tall
    /// as the text needs, up to the tallest a card holds. With a picture it
    /// takes the whole height.
    static func size(for text: String, image: NSImage? = nil) -> CGSize {
        let width = Layout.cardWidth - 14
        if image != nil { return CGSize(width: width, height: Layout.sheetMaxHeight) }
        let pad = padding
        let measured = attributed(text).boundingRect(
            with: CGSize(width: width - pad * 2, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading]).height
        let height = min(Layout.sheetMaxHeight, max(width * 0.42, ceil(measured) + pad * 2))
        return CGSize(width: width, height: height)
    }

    /// The sheet as an image, `scale` pixels per point. Twice covers a Retina
    /// screen; the flight from the editor asks for more while it is large.
    static func render(_ text: String, image: NSImage? = nil, scale: CGFloat = 2) -> NSImage? {
        let sheet = Self.size(for: text, image: image)
        let pw = Int((sheet.width * scale).rounded()), ph = Int((sheet.height * scale).rounded())
        guard pw > 0, ph > 0,
              let space = CGColorSpace(name: CGColorSpace.sRGB),
              let cg = CGContext(data: nil, width: pw, height: ph, bitsPerComponent: 8, bytesPerRow: 0,
                                 space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        // Top down, the way text is laid out, so it starts at the top edge.
        cg.translateBy(x: 0, y: CGFloat(ph))
        cg.scaleBy(x: scale, y: -scale)

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: cg, flipped: true)
        paper.setFill()
        NSRect(origin: .zero, size: sheet).fill()
        let pad = padding
        var box = NSRect(x: pad, y: pad, width: sheet.width - pad * 2, height: sheet.height - pad * 2)
        // A picture pasted into the note fills the top, the words go under it.
        if let image, image.size.width > 0, image.size.height > 0 {
            let words = !Notes.plainText(of: NSAttributedString(string: text))
                .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            let frame = NSRect(x: 0, y: 0, width: sheet.width,
                               height: words ? (sheet.height * 0.58).rounded() : sheet.height)
            let fill = max(frame.width / image.size.width, frame.height / image.size.height)
            let drawn = NSSize(width: image.size.width * fill, height: image.size.height * fill)
            NSGraphicsContext.saveGraphicsState()
            NSBezierPath(rect: frame).addClip()
            image.draw(in: NSRect(x: frame.midX - drawn.width / 2, y: frame.midY - drawn.height / 2,
                                  width: drawn.width, height: drawn.height),
                       from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
            NSGraphicsContext.restoreGraphicsState()
            box.origin.y = frame.maxY + pad * 0.6
            box.size.height = max(0, sheet.height - box.origin.y - pad * 0.6)
        }
        attributed(text).draw(with: box, options: [.usesLineFragmentOrigin, .usesFontLeading,
                                                   .truncatesLastVisibleLine])
        NSGraphicsContext.restoreGraphicsState()

        guard let image = cg.makeImage() else { return nil }
        return NSImage(cgImage: image, size: sheet)
    }

    private static var padding: CGFloat { (9 * Layout.size.scale).rounded() }

    /// Title in semibold, the rest a little smaller and lighter. Only the
    /// start of a long note is laid out: no more than that can show.
    private static func attributed(_ text: String) -> NSAttributedString {
        let s = Layout.size.scale
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping
        paragraph.lineSpacing = 1
        let title = Notes.title(of: text)
        let body = String(Notes.body(of: text).prefix(600))

        let result = NSMutableAttributedString(string: title.isEmpty ? " " : title, attributes: [
            .font: NSFont.systemFont(ofSize: 12 * s, weight: .semibold),
            .foregroundColor: ink,
            .paragraphStyle: paragraph,
        ])
        if !body.isEmpty {
            let bodyParagraph = paragraph.mutableCopy() as! NSMutableParagraphStyle
            bodyParagraph.paragraphSpacingBefore = 2 * s
            result.append(NSAttributedString(string: "\n" + body, attributes: [
                .font: NSFont.systemFont(ofSize: 10.5 * s),
                .foregroundColor: pencil,
                .paragraphStyle: bodyParagraph,
            ]))
        }
        return result
    }
}
