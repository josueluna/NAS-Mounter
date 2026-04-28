import AppKit
import SwiftUI

class StatusBarController {

    private var statusItem: NSStatusItem!
    private var popover = NSPopover()

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            let image = NSImage(named: "TBIcon")
            image?.isTemplate = true
            button.image = image
            button.imageScaling = .scaleProportionallyUpOrDown
            button.action = #selector(togglePopover(_:))
            button.target = self
        }

        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(rootView: ContentView())

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleClosePopover),
            name: NSNotification.Name("NASMountieClosePopover"),
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
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

    @objc func handleClosePopover() {
        popover.performClose(nil)
    }

    func closePopover() {
        popover.performClose(nil)
    }
}
