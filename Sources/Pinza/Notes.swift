import AppKit
import UniformTypeIdentifiers

/// Where notes live: one file per note, in Pinza's own folder.
///
/// A note is any file: text written on the sheet, an image or text copied or
/// dropped on the line, a PDF or a document from Finder. Being files, they
/// behave like a screenshot does on the line: dragged into a folder to keep
/// one, into an app to send it, to the Trash to let it go.
enum Notes {
    static let folder: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Pinza/Notes", isDirectory: true)
    }()

    /// Text files hang as a sheet of paper with their words on it, and the
    /// sheet edits them. Everything else hangs as its own preview.
    static let textExtensions: Set<String> = ["txt", "text", "md", "markdown"]

    static func isText(_ url: URL) -> Bool {
        textExtensions.contains(url.pathExtension.lowercased())
    }

    /// Notes written on the sheet with a picture or a file pasted in are
    /// saved as rich text documents, which carry them inside.
    static func isRich(_ url: URL) -> Bool {
        ["rtfd", "rtf"].contains(url.pathExtension.lowercased())
    }

    static let imageExtensions: Set<String> = ["png", "jpg", "jpeg", "heic", "tif", "tiff", "gif", "webp", "bmp"]

    static func isImage(_ url: URL) -> Bool {
        imageExtensions.contains(url.pathExtension.lowercased())
    }

    /// Files still being written by a browser or a download tool.
    private static let partialExtensions: Set<String> = ["download", "crdownload", "part", "partial", "tmp"]

    /// Whether a file in a watched folder hangs: any file or package, but no
    /// folder, and nothing still downloading.
    static func isNote(_ url: URL) -> Bool {
        guard !partialExtensions.contains(url.pathExtension.lowercased()),
              let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .isPackageKey]) else { return false }
        return values.isRegularFile == true || values.isPackage == true
    }

    /// Anything bigger is not a note.
    static let maxBytes = 1024 * 1024
    /// Text copied or written beyond this many characters does not hang.
    static let maxCharacters = 20_000

    /// The note's text, or nil if the file cannot be read as text.
    static func read(_ url: URL) -> String? {
        guard let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize,
              size <= maxBytes else { return nil }
        if let text = try? String(contentsOf: url, encoding: .utf8) { return text }
        var encoding = String.Encoding.utf8
        return try? String(contentsOf: url, usedEncoding: &encoding)
    }

    /// Writes a new note into the folder, named after its first line.
    static func create(_ text: String, prefix: String? = nil) -> URL? {
        let fm = FileManager.default
        do {
            try fm.createDirectory(at: folder, withIntermediateDirectories: true)
            let url = uniqueURL(in: folder, for: fileName(for: text, prefix: prefix))
            try text.write(to: url, atomically: true, encoding: .utf8)
            // What people write can be private: only they can read it.
            try fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
            return url
        } catch {
            log.error("Could not save a note: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    /// The files pasted into a rich note, as they are kept inside its
    /// package, next to the text itself.
    static func attachedFiles(of url: URL) -> [URL] {
        guard url.pathExtension.lowercased() == "rtfd",
              let names = try? FileManager.default.contentsOfDirectory(atPath: url.path) else { return [] }
        return names.filter { $0 != "TXT.rtf" && !$0.hasPrefix(".") }.sorted()
            .map { url.appendingPathComponent($0) }
    }

    /// The words in a file that is a kind of text, Markdown, code or data
    /// included, or nil for any other kind of file.
    static func textContents(of url: URL) -> String? {
        let type = UTType(filenameExtension: url.pathExtension)
        guard isText(url) || type?.conforms(to: .text) == true,
              type?.conforms(to: .rtf) != true, type?.conforms(to: .html) != true else { return nil }
        return read(url)
    }

    /// A rich note's text and attachments, or nil if it cannot be read.
    static func readRich(_ url: URL) -> NSAttributedString? {
        try? NSAttributedString(url: url, options: [:], documentAttributes: nil)
    }

    /// Writes a new rich note into the folder, named after its first line.
    static func create(rich: NSAttributedString) -> URL? {
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        } catch {
            return nil
        }
        let url = uniqueURL(in: folder, for: fileName(for: plainText(of: rich), ext: "rtfd"))
        return write(rich: rich, to: url) ? url : nil
    }

    /// Writes a rich note over its file, all at once, so a reader never sees
    /// half a package.
    @discardableResult
    static func write(rich: NSAttributedString, to url: URL) -> Bool {
        let fm = FileManager.default
        do {
            let wrapper = try rich.fileWrapper(from: NSRange(location: 0, length: rich.length),
                                               documentAttributes: [.documentType: NSAttributedString.DocumentType.rtfd])
            let scratch = try fm.url(for: .itemReplacementDirectory, in: .userDomainMask,
                                     appropriateFor: folder, create: true)
            let temp = scratch.appendingPathComponent(url.lastPathComponent)
            try wrapper.write(to: temp, options: .atomic, originalContentsURL: nil)
            try fm.setAttributes([.posixPermissions: 0o700], ofItemAtPath: temp.path)
            if fm.fileExists(atPath: url.path) {
                _ = try fm.replaceItemAt(url, withItemAt: temp)
            } else {
                try fm.moveItem(at: temp, to: url)
            }
            try? fm.removeItem(at: scratch)
            return true
        } catch {
            log.error("Could not save \(url.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    /// The words of a rich note, without the marks that stand for its
    /// attachments.
    static func plainText(of rich: NSAttributedString) -> String {
        rich.string.replacingOccurrences(of: "\u{FFFC}", with: "")
    }

    static func hasAttachments(_ rich: NSAttributedString) -> Bool {
        var found = false
        rich.enumerateAttribute(.attachment, in: NSRange(location: 0, length: rich.length)) { value, _, stop in
            if value != nil { found = true; stop.pointee = true }
        }
        return found
    }

    /// The first picture pasted into a rich note, for its card.
    static func firstImage(in rich: NSAttributedString) -> NSImage? {
        var image: NSImage?
        rich.enumerateAttribute(.attachment, in: NSRange(location: 0, length: rich.length)) { value, _, stop in
            guard let attachment = value as? NSTextAttachment else { return }
            if let picture = attachment.image
                ?? attachment.fileWrapper?.regularFileContents.flatMap(NSImage.init(data:)) {
                image = picture
                stop.pointee = true
            }
        }
        return image
    }

    /// Saves an image, copied or dropped, as a PNG note.
    static func create(png: Data, prefix: String) -> URL? {
        save(png, as: "\(prefix) \(stamp()).png")
    }

    private static func save(_ data: Data, as name: String) -> URL? {
        let fm = FileManager.default
        do {
            try fm.createDirectory(at: folder, withIntermediateDirectories: true)
            let url = uniqueURL(in: folder, for: name)
            try data.write(to: url, options: .atomic)
            try fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
            return url
        } catch {
            log.error("Could not save a note: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    /// Writes an edited note back over its file.
    @discardableResult
    static func write(_ text: String, to url: URL) -> Bool {
        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
            return true
        } catch {
            log.error("Could not save \(url.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    /// The first line with something on it, without Markdown's heading or
    /// list marks.
    static func title(of text: String) -> String {
        let line = text.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty } ?? ""
        var title = Substring(line)
        while let c = title.first, "#*->[] \t".contains(c) { title.removeFirst() }
        return String(title)
    }

    /// Everything after the title, with runs of blank lines folded into one.
    static func body(of text: String) -> String {
        var lines = text.components(separatedBy: .newlines)
        while let first = lines.first, first.trimmingCharacters(in: .whitespaces).isEmpty { lines.removeFirst() }
        if !lines.isEmpty { lines.removeFirst() }
        var out: [String] = []
        for line in lines {
            let blank = line.trimmingCharacters(in: .whitespaces).isEmpty
            if blank && (out.isEmpty || out.last == "") { continue }
            out.append(blank ? "" : line)
        }
        return out.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// "Buy milk.txt" for a note that starts with "Buy milk". A note with no
    /// words in its first line is named after the moment it was written.
    static func fileName(for text: String, prefix: String? = nil, ext: String = "txt") -> String {
        var name = title(of: text)
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        while name.hasPrefix(".") { name.removeFirst() }
        if name.count > 48 { name = String(name.prefix(48)).trimmingCharacters(in: .whitespaces) + "…" }
        if name.isEmpty { name = "\(prefix ?? "Note") \(stamp())" }
        return name + "." + ext
    }

    static func uniqueURL(in folder: URL, for name: String) -> URL {
        let base = (name as NSString).deletingPathExtension
        let ext = (name as NSString).pathExtension
        var candidate = folder.appendingPathComponent(name)
        var n = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = folder.appendingPathComponent("\(base) \(n)")
            if !ext.isEmpty { candidate.appendPathExtension(ext) }
            n += 1
        }
        return candidate
    }

    static func modificationDate(_ url: URL) -> Date? {
        try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
    }

    private static func stamp() -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        return f.string(from: Date())
    }
}
