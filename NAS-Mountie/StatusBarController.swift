import AppKit
import SwiftUI
import CoreWLAN

class StatusBarController {

    private var statusItem: NSStatusItem!
    private var popover = NSPopover()

    // Timer que pulsa cada 2s para detectar SSID y actualizar el tooltip del ícono.
    // Se detiene una vez que hay un perfil confirmado o la red no tiene perfil.
    private var networkCheckTimer: Timer?

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

        startNetworkCheck()
    }

    deinit {
        networkCheckTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Network check

    private func startNetworkCheck() {
        // Fire immediately, then every 2 seconds.
        updateStatusIcon()
        networkCheckTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.updateStatusIcon()
        }
    }

    private func updateStatusIcon() {
        guard let button = statusItem.button else { return }

        let ssid = NetworkHelper.currentSSID()
        let hasProfile = ssid.flatMap { NetworkProfileManager.profile(for: $0) } != nil

        DispatchQueue.main.async {
            if let ssid {
                if hasProfile {
                    // Known network with a saved profile — show full-opacity icon + green tint tooltip
                    button.appearsDisabled = false
                    button.toolTip = "NAS Mountie — \(ssid) ✓"
                } else {
                    // Connected to Wi-Fi but no profile saved for this network
                    button.appearsDisabled = false
                    button.toolTip = "NAS Mountie — \(ssid) (no profile)"
                }
            } else {
                // No Wi-Fi / SSID not available yet
                button.appearsDisabled = false
                button.toolTip = "NAS Mountie — no network"
            }
        }
    }

    // MARK: - Popover

    @objc func togglePopover(_ sender: AnyObject?) {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()

            NotificationCenter.default.post(
                name: NSNotification.Name("NASMountiePopoverDidOpen"),
                object: nil
            )
        }
    }

    @objc func handleClosePopover() {
        popover.performClose(nil)
    }

    func closePopover() {
        popover.performClose(nil)
    }
}
