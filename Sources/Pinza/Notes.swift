import Foundation

/// Where notes live: one plain text file per note, in Pinza's own folder.
///
/// Plain text files, so a note behaves like a screenshot does on the line:
/// it can be dragged into a folder to keep it, into an app to send it, to
/// the Trash to let it go, and opened in any editor.
enum Notes {
    static let folder: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Pinza/Notes", isDirectory: true)
    }()

    /// Files that count as notes in a watched folder.
    static let textExtensions: Set<String> = ["txt", "text", "md", "markdown"]

    static func isNote(_ url: URL) -> Bool {
        textExtensions.contains(url.pathExtension.lowercased())
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
    static func fileName(for text: String, prefix: String? = nil) -> String {
        var name = title(of: text)
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        while name.hasPrefix(".") { name.removeFirst() }
        if name.count > 48 { name = String(name.prefix(48)).trimmingCharacters(in: .whitespaces) + "…" }
        if name.isEmpty { name = "\(prefix ?? "Note") \(stamp())" }
        return name + ".txt"
    }

    static func uniqueURL(in folder: URL, for name: String) -> URL {
        let base = (name as NSString).deletingPathExtension
        let ext = (name as NSString).pathExtension
        var candidate = folder.appendingPathComponent(name)
        var n = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = folder.appendingPathComponent("\(base) \(n)").appendingPathExtension(ext)
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
