import AppKit
import SwiftUI

class StatusBarController {

    private var statusItem: NSStatusItem!
    private var popover = NSPopover()

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "externaldrive.fill.badge.wifi",
                                   accessibilityDescription: "NAS Mounter")
            button.action = #selector(togglePopover(_:))
            button.target = self
        }

        popover.behavior = .transient          // se cierra al hacer click afuera
        popover.animates = true
        popover.contentViewController = NSHostingController(rootView: ContentView())
    }

    @objc func togglePopover(_ sender: AnyObject?) {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    func closePopover() {
        popover.performClose(nil)
    }
}
