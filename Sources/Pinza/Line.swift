import AppKit
import Combine
import os

let log = Logger(subsystem: "app.pinza.Pinza", category: "line")

/// One note hanging on the line: a file of any kind.
struct Pegged: Identifiable, Equatable {
    let id = UUID()
    let url: URL
    /// What hangs: a text note drawn as a sheet of paper (see NoteCard), or
    /// any other file's preview (see FileCard).
    var thumb: NSImage
    /// A text note's words as last read, for copying and dragging. Nil for
    /// any other kind of file.
    var text: String?
    /// When the file was last changed, to notice edits made in other apps.
    var modified: Date?
    /// Every note hangs a little crooked, like on a real line.
    let tilt = Double.random(in: -2.5...2.5)
    var falling = false
    /// Still flying in from the editor; the card waits hidden.
    var flying = false

    static func == (a: Pegged, b: Pegged) -> Bool {
        a.id == b.id && a.falling == b.falling && a.flying == b.flying && a.thumb === b.thumb
    }
}

/// The line itself: what hangs on it and what you can do with each item.
/// The files never move. The line is only a view onto them.
@MainActor
final class Line: ObservableObject {
    @Published private(set) var items: [Pegged] = []
    @Published private(set) var gust = 0
    @Published var copiedID: UUID?
    @Published var draggingID: UUID?
    @Published var pressedID: UUID?
    /// Whether the line has slid down into view.
    @Published var revealed = false
    /// Something from another app is being dragged over the line.
    @Published var dropTargeted = false

    /// Card frames in window coordinates, reported by the views. The panel
    /// uses them to only catch clicks over notes and let the rest through.
    var hitRects: [UUID: CGRect] = [:]

    var maxItems = 8
    /// How many notes fit across the screen. With Keep on line set, the
    /// line can hold more, and the rest are reached by scrolling.
    var visibleCount = 8
    /// How far the line is scrolled towards older notes, in points; 0 shows
    /// the newest.
    @Published var scroll: CGFloat = 0

    /// Keep on line, from the menu bar: how many notes the line keeps, or
    /// nil for as many as fit across the screen.
    nonisolated static let keepChoices = [25, 50, 100]
    nonisolated static var keepOnLine: Int? {
        get {
            let n = UserDefaults.standard.integer(forKey: "keepOnLine")
            return keepChoices.contains(n) ? n : nil
        }
        set { UserDefaults.standard.set(newValue ?? 0, forKey: "keepOnLine") }
    }

    /// Marks text copied from the line, so the clipboard watcher does not
    /// hang it a second time.
    nonisolated static let ownType = NSPasteboard.PasteboardType("app.pinza.note")

    var soundOn: Bool {
        get { !UserDefaults.standard.bool(forKey: "soundOff") }
        set { UserDefaults.standard.set(!newValue, forKey: "soundOff") }
    }

    var liveCount: Int { items.filter { !$0.falling }.count }

    private let storeKey = "pegged"

    init() {
        restore()
        scheduleGust()
    }

    // MARK: Hanging and dropping

    @discardableResult
    func hang(_ url: URL, quietly: Bool = false, flying: Bool = false) -> UUID? {
        guard !items.contains(where: { $0.url == url && !$0.falling }),
              var item = makeItem(url) else { return nil }
        item.flying = flying
        items.append(item)
        scroll = 0
        // A full line lets the oldest note fall off the far end. Only one: a
        // line hung on a wider screen keeps its length here instead of losing
        // several notes to a single new one.
        if liveCount > maxItems, let oldest = items.first(where: { !$0.falling }) {
            letGo(oldest.id)
        }
        save()
        if !quietly { play("Tink", volume: 0.35) }
        return item.id
    }

    /// The note has reached the line: the real card takes over.
    func land(_ id: UUID) {
        guard let i = items.firstIndex(where: { $0.id == id }) else { return }
        items[i].flying = false
    }

    /// Called just before a note starts falling, so the fall can be drawn
    /// over the whole screen.
    var onFall: ((Pegged) -> Void)?

    func drop(_ id: UUID, quietly: Bool = false) {
        guard let i = items.firstIndex(where: { $0.id == id }), !items[i].falling else { return }
        onFall?(items[i])
        items[i].falling = true
        hitRects[id] = nil
        save()
        if !quietly { play("Pop", volume: 0.25) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            self?.items.removeAll { $0.id == id }
        }
    }

    /// "Take everything down": every note goes the way of its corner cross.
    func clear() {
        takeDown(items.filter { !$0.falling })
    }

    /// The notes hung before (left) or after (right) this one.
    func neighbours(of id: UUID, toTheLeft: Bool) -> [Pegged] {
        let live = items.filter { !$0.falling }
        guard let i = live.firstIndex(where: { $0.id == id }) else { return [] }
        return toTheLeft ? Array(live[..<i]) : Array(live[(i + 1)...])
    }

    /// Takes down everything on one side of a note. Each one goes the way
    /// of its own corner button: to the Trash from Pinza's folder, and only
    /// off the line from anywhere else.
    func takeDown(_ id: UUID, toTheLeft: Bool) {
        takeDown(neighbours(of: id, toTheLeft: toTheLeft))
    }

    /// One after another, and only the first makes a sound.
    private func takeDown(_ live: [Pegged]) {
        for (n, item) in live.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.06 * Double(n)) { [weak self] in
                self?.discard(item.id, quietly: n > 0)
            }
        }
    }

    /// Notes whose file was deleted or moved away fall off by themselves.
    func prune() {
        for item in items where !item.falling && !FileManager.default.fileExists(atPath: item.url.path) {
            drop(item.id, quietly: true)
        }
    }

    /// Notes changed in another app, like TextEdit after a double click,
    /// show their new version.
    func refreshEdited() {
        for item in items where !item.falling && Notes.modificationDate(item.url) != item.modified {
            reloadThumbnail(for: item.url)
        }
    }

    // MARK: Actions on one note

    /// The latest text of a text note, read again in case it was edited
    /// elsewhere. Nil for any other kind of file.
    func text(of id: UUID) -> String? {
        guard let item = items.first(where: { $0.id == id }), item.text != nil else { return nil }
        return Notes.read(item.url) ?? item.text
    }

    func url(of id: UUID) -> URL? {
        items.first(where: { $0.id == id })?.url
    }

    /// The text of a text note; the picture and the file of an image; the
    /// file of anything else, which apps paste as the file itself.
    func copy(_ id: UUID) {
        guard let url = url(of: id) else { return }
        let entry = NSPasteboardItem()
        if let text = text(of: id) {
            entry.setString(text, forType: .string)
        } else {
            if Notes.isImage(url), let png = pngData(url) { entry.setData(png, forType: .png) }
            entry.setString(url.absoluteString, forType: .fileURL)
        }
        entry.setData(Data(), forType: Line.ownType)
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.writeObjects([entry])

        copiedID = id
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            if self?.copiedID == id { self?.copiedID = nil }
        }
    }

    /// Opens the file in its app: TextEdit for text unless changed.
    func open(_ id: UUID) {
        guard let item = items.first(where: { $0.id == id }) else { return }
        NSWorkspace.shared.open(item.url)
    }

    /// Moves the file to the Trash and takes the note off the line. When a
    /// drag ends on the Dock's Trash, macOS only reports it: deleting the file
    /// is the source app's job, as Finder does.
    @discardableResult
    func trash(_ id: UUID, quietly: Bool = false) -> Bool {
        guard let item = items.first(where: { $0.id == id }) else { return false }
        do {
            try FileManager.default.trashItem(at: item.url, resultingItemURL: nil)
            log.notice("Trashed \(item.url.lastPathComponent, privacy: .public)")
            if soundOn && !quietly { Line.trashSound?.play() }
            drop(id, quietly: true)
            return true
        } catch {
            log.error("Could not trash \(item.url.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
            if !quietly { NSSound.beep() }
            return false
        }
    }

    private static let trashSound = NSSound(
        contentsOfFile: "/System/Library/Components/CoreAudio.component/Contents/SharedSupport/SystemSounds/dock/drag to trash.aif",
        byReference: true)

    /// Whether the file lives in Pinza's own folder. Those are discarded to
    /// the Trash, or the folder would fill up with forgotten notes. Files
    /// anywhere else, like a watched folder, stay where they are.
    func isInInbox(_ id: UUID) -> Bool {
        guard let item = items.first(where: { $0.id == id }) else { return false }
        return item.url.standardizedFileURL.path.hasPrefix(Notes.folder.standardizedFileURL.path + "/")
    }

    /// The corner cross and "Take down" both end up here.
    func discard(_ id: UUID, quietly: Bool = false) {
        if isInInbox(id) { trash(id, quietly: quietly) } else { drop(id, quietly: quietly) }
    }

    /// Moves along a line that holds more than fit, from a scroll gesture.
    func scroll(by delta: CGFloat) {
        let most = CGFloat(max(0, items.count - visibleCount)) * Layout.spacing
        let next = min(most, max(0, scroll + delta))
        if next != scroll { scroll = next }
    }

    /// After Keep on line is lowered, the oldest notes past it go the way
    /// of a full line.
    func trim() {
        while liveCount > maxItems, let oldest = items.first(where: { !$0.falling }) {
            letGo(oldest.id)
        }
        scroll = 0
    }

    /// The oldest note falling off a full line. Like the cross, a file from
    /// Pinza's folder goes to the Trash, or nothing would ever take it out
    /// of that folder. If the Trash refuses it, it still leaves the line.
    private func letGo(_ id: UUID) {
        if isInInbox(id), trash(id, quietly: true) { return }
        drop(id, quietly: true)
    }

    /// Keep a note by moving its file to the Desktop.
    func saveToDesktop(_ id: UUID) {
        guard let item = items.first(where: { $0.id == id }) else { return }
        let desktop = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop")
        let target = Notes.uniqueURL(in: desktop, for: item.url.lastPathComponent)
        do {
            try FileManager.default.moveItem(at: item.url, to: target)
            drop(id, quietly: true)
        } catch {
            log.error("Could not save to Desktop: \(error.localizedDescription, privacy: .public)")
            NSSound.beep()
        }
    }

    /// Long press: a text note opens on the sheet it was written on, an
    /// image in the system Markup editor, and anything else in Quick Look.
    func edit(_ id: UUID) {
        guard let item = items.first(where: { $0.id == id }) else { return }
        if item.text != nil {
            NoteEditor.shared.edit(item.url)
        } else if Notes.isImage(item.url) {
            Markup.shared.edit(item.url)
        } else {
            quickLook(id)
        }
    }

    /// Whether a long press edits this note, for its menu.
    func canEdit(_ id: UUID) -> Bool {
        guard let item = items.first(where: { $0.id == id }) else { return false }
        return item.text != nil || Notes.isImage(item.url)
    }

    /// After editing, the note on the line shows the new version.
    func reloadThumbnail(for url: URL) {
        guard let i = items.firstIndex(where: { $0.url == url && !$0.falling }),
              let fresh = makeItem(url) else { return }
        items[i].thumb = fresh.thumb
        items[i].text = fresh.text
        items[i].modified = fresh.modified
    }

    /// Quick Look on this note, with the rest of the line a key press away.
    func quickLook(_ id: UUID) {
        let live = items.filter { !$0.falling }
        guard let index = live.firstIndex(where: { $0.id == id }) else { return }
        QuickLook.shared.show(live.map(\.url), at: index)
    }

    /// After a change of size, every note is redrawn sharp at the new one.
    func reloadThumbnails() {
        for item in items where !item.falling { reloadThumbnail(for: item.url) }
    }

    func reveal(_ id: UUID) {
        guard let item = items.first(where: { $0.id == id }) else { return }
        NSWorkspace.shared.activateFileViewerSelecting([item.url])
    }

    // MARK: Breeze

    /// Every so often a little wind moves the line. It is the detail that
    /// makes it feel like an object and not a widget.
    private func scheduleGust() {
        DispatchQueue.main.asyncAfter(deadline: .now() + .random(in: 7...16)) { [weak self] in
            guard let self else { return }
            if !self.items.isEmpty && self.draggingID == nil { self.gust += 1 }
            self.scheduleGust()
        }
    }

    // MARK: Persistence

    private func save() {
        let paths = items.filter { !$0.falling }.map(\.url.path)
        UserDefaults.standard.set(paths, forKey: storeKey)
    }

    /// Everything comes back as it was. This runs before the line knows its
    /// screen, so the capacity is still the default one: hanging through
    /// `hang` would let notes fall off a wide screen's line at every launch.
    private func restore() {
        let paths = UserDefaults.standard.stringArray(forKey: storeKey) ?? []
        for path in paths where FileManager.default.fileExists(atPath: path) {
            let url = URL(fileURLWithPath: path)
            guard !items.contains(where: { $0.url == url }), let item = makeItem(url) else { continue }
            items.append(item)
        }
    }

    // MARK: Helpers

    /// A text file with words in it hangs as paper; anything else, an empty
    /// or unreadable text file included, as its preview, which Quick Look
    /// draws a moment later.
    private func makeItem(_ url: URL) -> Pegged? {
        let modified = Notes.modificationDate(url)
        if Notes.isText(url), let text = Notes.read(url),
           !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let thumb = NoteCard.render(text) {
            return Pegged(url: url, thumb: thumb, text: text, modified: modified)
        }
        guard FileManager.default.fileExists(atPath: url.path),
              let thumb = FileCard.placeholder(for: url) else { return nil }
        if !Notes.isImage(url) {
            FileCard.preview(for: url) { [weak self] preview in
                guard let self,
                      let i = self.items.firstIndex(where: { $0.url == url && !$0.falling }),
                      self.items[i].modified == modified else { return }
                self.items[i].thumb = preview
            }
        }
        return Pegged(url: url, thumb: thumb, text: nil, modified: modified)
    }

    private func pngData(_ url: URL) -> Data? {
        if url.pathExtension.lowercased() == "png" { return try? Data(contentsOf: url) }
        guard let tiff = NSImage(contentsOf: url)?.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .png, properties: [:])
    }

    private func play(_ name: String, volume: Float) {
        guard soundOn, let sound = NSSound(named: name)?.copy() as? NSSound else { return }
        sound.volume = volume
        sound.play()
    }
}
