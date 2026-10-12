import Foundation

/// Watches a folder and reports new notes in it: Pinza's own folder, so a
/// text file put there hangs and a note deleted or edited elsewhere is
/// noticed, and the folders chosen in "Also watch folders".
final class NoteWatcher {
    let folder: URL
    private var known: Set<String>?
    private var source: DispatchSourceFileSystemObject?
    private var pending: DispatchWorkItem?
    /// A `start()` that is still waiting on the folder, off the main thread.
    private var starting = false
    /// A folder listing that is still on its way, off the main thread.
    private var listing = false
    /// A note landed while that listing was in flight.
    private var missed = false
    /// `stop()` arrived while one of the two was still pending.
    private var stopped = false
    private let onNew: (URL) -> Void
    private let onChange: () -> Void

    init(folder: URL, onNew: @escaping (URL) -> Void, onChange: @escaping () -> Void) {
        self.onNew = onNew
        self.onChange = onChange
        self.folder = folder
    }

    /// Anything created after the app launched counts as new, even if it
    /// landed before the watcher was ready (macOS may be asking for access
    /// to the folder at that moment).
    private let launchDate = Date()

    /// The folder is opened off the main thread, because `open()` blocks while
    /// macOS asks whether Pinza may look inside it, for a watched folder in
    /// Documents or Downloads. Asking from `applicationDidFinishLaunching`
    /// would hold up the launch, and no status item would appear meanwhile.
    func start() {
        stopped = false
        guard source == nil, !starting else { return }
        starting = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let fd = open(self.folder.path, O_EVTONLY)
            DispatchQueue.main.async { self.watch(fd) }
        }
    }

    /// Starts watching, then reads the folder. The watcher is live before the
    /// listing begins, so a note that lands in between is not lost.
    private func watch(_ fd: Int32) {
        starting = false
        guard !stopped else {
            if fd >= 0 { close(fd) }
            return
        }
        guard fd >= 0 else {
            NSLog("Pinza: cannot watch \(folder.path)")
            return
        }
        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd, eventMask: [.write, .rename, .delete], queue: .main)
        src.setEventHandler { [weak self] in self?.scheduleScan() }
        src.setCancelHandler { close(fd) }
        src.resume()
        source = src
        refresh()
    }

    /// Safe to call while `start()` or a listing is still pending: the file
    /// descriptor is closed as soon as it arrives, and a listing that lands
    /// afterwards is dropped.
    func stop() {
        stopped = true
        missed = false
        pending?.cancel()
        pending = nil
        source?.cancel()
        source = nil
    }

    private func scheduleScan() {
        pending?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.refresh() }
        pending = work
        // Editors write a hidden temp file and rename it; give it a moment.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: work)
    }

    /// Reads the folder off the main thread. Sorting by creation date and
    /// reading it back costs one filesystem call per file, and a watched
    /// folder can be large, so none of it belongs on the main thread.
    private func refresh() {
        guard !listing else {
            missed = true
            return
        }
        listing = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let files = self.listFolder()
            let settled = files.filter { self.creationDate($0) < self.launchDate }
            let candidates = files.filter(Notes.isNote)
            DispatchQueue.main.async { self.adopt(files, settled, candidates) }
        }
    }

    /// Takes a finished listing, reports what is new, then runs the listing
    /// that was asked for while this one was in flight.
    private func adopt(_ files: [URL], _ settled: [URL], _ candidates: [URL]) {
        listing = false
        guard !stopped else { return }
        // The first listing adopts everything that was already there when the
        // app launched. Later ones compare against the previous listing.
        let first = known == nil
        let base = known ?? Set(settled.map(\.path))
        for url in candidates where !base.contains(url.path) {
            onNew(url)
        }
        known = Set(files.map(\.path))
        if !first { onChange() }
        if missed {
            missed = false
            refresh()
        }
    }

    private func listFolder() -> [URL] {
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: folder, includingPropertiesForKeys: [.creationDateKey], options: [.skipsHiddenFiles])) ?? []
        return urls.sorted { creationDate($0) < creationDate($1) }
    }

    private func creationDate(_ url: URL) -> Date {
        (try? url.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
    }
}
