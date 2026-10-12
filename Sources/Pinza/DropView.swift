import AppKit

/// The line's whole strip, under the notes: anything dropped on it hangs.
/// Files from Finder, a picture or text dragged out of an app, see Intake.
///
/// The strip lets the mouse through everywhere but over the notes, so while
/// something is being dragged towards it the app delegate lets it catch the
/// mouse, see `AppDelegate.updateMousePassThrough`.
final class DropView: NSView {
    /// Something that can hang is over the line, or has left it.
    var onTargeted: (Bool) -> Void = { _ in }
    /// It was let go over the line.
    var onDrop: (NSPasteboard) -> Bool = { _ in false }

    init(content: NSView) {
        super.init(frame: .zero)
        content.frame = bounds
        content.autoresizingMask = [.width, .height]
        addSubview(content)
        registerForDraggedTypes([.fileURL, .png, .tiff, .string])
    }

    required init?(coder: NSCoder) { fatalError() }

    /// A note dragged off the line is not hung again where it came from.
    private func accepts(_ sender: NSDraggingInfo) -> Bool {
        !(sender.draggingSource is GrabView)
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard accepts(sender) else { return [] }
        onTargeted(true)
        return .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        accepts(sender) ? .copy : []
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        onTargeted(false)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        onTargeted(false)
        return accepts(sender) && onDrop(sender.draggingPasteboard)
    }

    override func draggingEnded(_ sender: NSDraggingInfo) {
        onTargeted(false)
    }
}
