import AppKit
import Carbon

/// The sheet a note is written on, just under the line: the same paper the
/// note hangs as, in the same glass frame. ⌘↩ hangs it, or saves a note
/// that is already on the line; Escape puts the sheet away.
///
/// It floats without bringing Pinza to the front, the way Spotlight does,
/// so the app you were in keeps its menu bar and gets the keyboard back as
/// soon as the sheet goes.
@MainActor
final class NoteEditor: NSObject, NSWindowDelegate, NSTextViewDelegate {
    static let shared = NoteEditor()

    /// A new note was written: its file, and where its sheet was on screen,
    /// so it can fly from there to the line.
    var onCreated: (URL, CGRect) -> Void = { _, _ in }
    /// A note on the line was edited and written back.
    var onSaved: (URL) -> Void = { _ in }

    private var window: EditorPanel?
    private var textView: NSTextView?
    private var paperView: NSView?
    /// The note being edited, or nil for a new one.
    private var editing: URL?
    /// A new note put away unfinished waits here for next time.
    private var draft = ""

    var isOpen: Bool { window != nil }

    func new() {
        if let window, editing == nil {
            window.makeKeyAndOrderFront(nil)
            return
        }
        show(text: draft, editing: nil)
    }

    func edit(_ url: URL) {
        guard let text = Notes.read(url) else {
            NSWorkspace.shared.open(url)
            return
        }
        show(text: text, editing: url)
    }

    // MARK: The sheet

    private static let size = NSSize(width: 360, height: 240)

    private func show(text: String, editing url: URL?) {
        close()
        editing = url

        let window = EditorPanel(contentRect: NSRect(origin: .zero, size: Self.size),
                                 styleMask: [.titled, .closable, .resizable, .fullSizeContentView, .nonactivatingPanel],
                                 backing: .buffered, defer: false)
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.hidesOnDeactivate = false
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 260, height: 170)
        window.delegate = self
        window.onDone = { [weak self] in self?.done() }
        window.onCancel = { [weak self] in self?.cancel() }
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true

        // The glass, like the frame of a card on the line.
        let glass = NSVisualEffectView()
        glass.material = .hudWindow
        glass.blendingMode = .behindWindow
        glass.state = .active
        window.contentView = glass

        // The paper, inset in the glass.
        let paper = NSView()
        paper.wantsLayer = true
        paper.layer?.backgroundColor = NoteCard.paper.cgColor
        paper.layer?.cornerRadius = 12
        paper.layer?.cornerCurve = .continuous
        paper.layer?.borderWidth = 0.5
        paper.layer?.borderColor = NSColor.black.withAlphaComponent(0.08).cgColor
        paper.translatesAutoresizingMaskIntoConstraints = false
        glass.addSubview(paper)

        let scroll = NSTextView.scrollableTextView()
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.translatesAutoresizingMaskIntoConstraints = false
        let textView = scroll.documentView as! NSTextView
        textView.delegate = self
        textView.string = text
        textView.isRichText = false
        textView.allowsUndo = true
        textView.drawsBackground = false
        textView.font = .systemFont(ofSize: 14)
        textView.textColor = NoteCard.ink
        textView.insertionPointColor = NoteCard.ink
        textView.textContainerInset = NSSize(width: 8, height: 10)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.typingAttributes = [.font: NSFont.systemFont(ofSize: 14), .foregroundColor: NoteCard.ink]
        paper.addSubview(scroll)

        let hint = NSTextField(labelWithString: url == nil
            ? L("⌘↩ hangs it on the line")
            : L("⌘↩ saves it on the line"))
        hint.font = .systemFont(ofSize: 11)
        hint.textColor = .secondaryLabelColor
        hint.lineBreakMode = .byTruncatingTail
        hint.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let cancel = NSButton(title: L("Cancel"), target: self, action: #selector(cancelPressed))
        cancel.bezelStyle = .rounded
        cancel.controlSize = .regular
        let done = NSButton(title: url == nil ? L("Hang") : L("Save"), target: self, action: #selector(donePressed))
        done.bezelStyle = .rounded
        done.keyEquivalent = "\r"
        done.keyEquivalentModifierMask = .command

        let bar = NSStackView(views: [hint, cancel, done])
        bar.orientation = .horizontal
        bar.spacing = 8
        bar.setHuggingPriority(.defaultLow, for: .horizontal)
        bar.translatesAutoresizingMaskIntoConstraints = false
        glass.addSubview(bar)

        // The inset matches a card's: 4 points of glass around the paper,
        // a little more under the title bar.
        NSLayoutConstraint.activate([
            paper.topAnchor.constraint(equalTo: glass.topAnchor, constant: 30),
            paper.leadingAnchor.constraint(equalTo: glass.leadingAnchor, constant: 8),
            paper.trailingAnchor.constraint(equalTo: glass.trailingAnchor, constant: -8),
            paper.bottomAnchor.constraint(equalTo: bar.topAnchor, constant: -8),
            scroll.topAnchor.constraint(equalTo: paper.topAnchor, constant: 2),
            scroll.leadingAnchor.constraint(equalTo: paper.leadingAnchor, constant: 2),
            scroll.trailingAnchor.constraint(equalTo: paper.trailingAnchor, constant: -2),
            scroll.bottomAnchor.constraint(equalTo: paper.bottomAnchor, constant: -2),
            bar.leadingAnchor.constraint(equalTo: glass.leadingAnchor, constant: 14),
            bar.trailingAnchor.constraint(equalTo: glass.trailingAnchor, constant: -10),
            bar.bottomAnchor.constraint(equalTo: glass.bottomAnchor, constant: -10),
        ])

        self.window = window
        self.textView = textView
        self.paperView = paper
        place(window)
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(textView)
        textView.setSelectedRange(NSRange(location: (text as NSString).length, length: 0))
    }

    /// Centred just under where the line hangs, on the screen you are using,
    /// so the note has only a short way to fly.
    private func place(_ window: NSWindow) {
        guard let visible = LinePanel.screenUnderPointer()?.visibleFrame else {
            window.center()
            return
        }
        let size = window.frame.size
        window.setFrameOrigin(NSPoint(x: visible.midX - size.width / 2,
                                      y: visible.maxY - Layout.panelHeight - size.height + 40))
    }

    // MARK: Done and cancel

    @objc private func donePressed() { done() }
    @objc private func cancelPressed() { cancel() }

    private func done() {
        guard let window, let textView else { return }
        let text = textView.string
        let empty = text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if let url = editing {
            // Emptying a note does not delete it; the cross is for that.
            if !empty, Notes.write(text, to: url) { onSaved(url) }
            close()
            return
        }
        guard !empty else {
            draft = ""
            close()
            return
        }
        guard text.count <= Notes.maxCharacters, let url = Notes.create(text) else {
            NSSound.beep()
            return
        }
        draft = ""
        let from = paperView.map { window.convertToScreen($0.convert($0.bounds, to: nil)) } ?? window.frame
        close()
        onCreated(url, from)
    }

    /// A new note keeps what was written for next time. An edit is dropped.
    private func cancel() {
        if editing == nil, let textView { draft = textView.string }
        close()
    }

    private func close() {
        let window = self.window
        self.window = nil
        textView = nil
        paperView = nil
        editing = nil
        window?.delegate = nil
        window?.orderOut(nil)
        window?.close()
    }

    // MARK: NSWindowDelegate

    /// The close button counts as cancel.
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        cancel()
        return false
    }

    // MARK: NSTextViewDelegate

    func textView(_ textView: NSTextView, doCommandBy selector: Selector) -> Bool {
        if selector == #selector(NSResponder.cancelOperation(_:)) {
            cancel()
            return true
        }
        return false
    }
}

/// A floating panel that takes the keyboard without activating the app.
/// With no main menu to carry them, the editing shortcuts are handled here.
final class EditorPanel: NSPanel {
    var onDone: () -> Void = {}
    var onCancel: () -> Void = {}

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection([.command, .control, .option, .shift])
        if flags == .command, [kVK_Return, kVK_ANSI_KeypadEnter].contains(Int(event.keyCode)) {
            onDone()
            return true
        }
        if flags == .command, event.charactersIgnoringModifiers?.lowercased() == "w" {
            onCancel()
            return true
        }
        let key = event.charactersIgnoringModifiers?.lowercased() ?? ""
        var action: Selector?
        if flags == .command {
            switch key {
            case "x": action = #selector(NSText.cut(_:))
            case "c": action = #selector(NSText.copy(_:))
            case "v": action = #selector(NSText.paste(_:))
            case "a": action = #selector(NSText.selectAll(_:))
            case "z": action = Selector(("undo:"))
            default: break
            }
        } else if flags == [.command, .shift], key == "z" {
            action = Selector(("redo:"))
        }
        if let action, NSApp.sendAction(action, to: nil, from: self) { return true }
        return super.performKeyEquivalent(with: event)
    }

    override func cancelOperation(_ sender: Any?) {
        onCancel()
    }
}
