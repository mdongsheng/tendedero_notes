import AppKit

/// Turns what is copied or dropped on the line into notes:
///
/// - Files hang where they are, whatever their kind. Taking one down leaves
///   it there, as with a watched folder.
/// - An image is saved as a PNG in Pinza's folder.
/// - Text is saved as a text note there.
@MainActor
enum Intake {
    /// A drop of a whole folder's worth hangs no more than this.
    static let maxFiles = 10
    /// Anything bigger is not a picture worth hanging.
    private static let maxImageBytes = 64 * 1024 * 1024
    private static let maxPixels = 80_000_000

    static func notes(from pb: NSPasteboard, prefix: String) -> [URL] {
        if let urls = pb.readObjects(forClasses: [NSURL.self],
                                     options: [.urlReadingFileURLsOnly: true]) as? [URL], !urls.isEmpty {
            return Array(urls.filter(Notes.isNote).prefix(maxFiles))
        }
        let string = pb.string(forType: .string)
        let trimmed = string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        // An image dragged from a web page brings its address along, and that
        // is not what was meant. Text from a document or a spreadsheet brings
        // a picture of itself, and the words are.
        let isLink = trimmed.contains("://") && !trimmed.contains(where: \.isWhitespace)
        if trimmed.isEmpty || isLink, let png = image(from: pb),
           let url = Notes.create(png: png, prefix: prefix) {
            return [url]
        }
        if let string, !trimmed.isEmpty, string.count <= Notes.maxCharacters,
           let url = Notes.create(string, prefix: prefix) {
            return [url]
        }
        return []
    }

    /// PNG bytes are kept as they are; TIFF becomes PNG. Either way the image
    /// must decode and have a sane size.
    private static func image(from pb: NSPasteboard) -> Data? {
        guard let type = pb.availableType(from: [.png, .tiff]),
              let data = pb.data(forType: type), data.count <= maxImageBytes,
              let rep = NSBitmapImageRep(data: data),
              rep.pixelsWide > 0, rep.pixelsHigh > 0,
              rep.pixelsWide <= maxPixels / rep.pixelsHigh else { return nil }
        return type == .png ? data : rep.representation(using: .png, properties: [:])
    }
}
