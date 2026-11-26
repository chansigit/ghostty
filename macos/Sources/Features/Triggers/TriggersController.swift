import Cocoa
import SwiftUI

/// Ghostty's main menu has no key equivalents for the standard edit commands
/// (they're terminal keybinds), so text fields here wouldn't respond to
/// Cmd+V and friends. Route them to the first responder ourselves.
private final class TriggersWindow: NSWindow {
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if mods == .command || mods == [.command, .shift],
           let key = event.charactersIgnoringModifiers?.lowercased() {
            let action: Selector?
            switch (key, mods.contains(.shift)) {
            case ("v", false): action = #selector(NSText.paste(_:))
            case ("c", false): action = #selector(NSText.copy(_:))
            case ("x", false): action = #selector(NSText.cut(_:))
            case ("a", false): action = #selector(NSText.selectAll(_:))
            case ("z", false): action = Selector(("undo:"))
            case ("z", true): action = Selector(("redo:"))
            default: action = nil
            }
            if let action, NSApp.sendAction(action, to: nil, from: self) { return true }
        }
        return super.performKeyEquivalent(with: event)
    }
}

/// Window that lets the user edit triggers (output pattern -> send text).
final class TriggersController: NSWindowController, NSWindowDelegate {
    static let shared = TriggersController()

    private let store = TriggerStore()

    private init() {
        let window = TriggersWindow(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 400),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false)
        window.title = "Triggers"
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.delegate = self
        window.contentView = NSHostingView(rootView: TriggersView(
            store: store,
            onApply: { (NSApp.delegate as? AppDelegate)?.reloadConfig(nil) },
            onClose: { [weak self] in self?.window?.close() }))
        window.center()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func show() {
        store.load()
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }
}
