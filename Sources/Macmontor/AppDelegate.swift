import AppKit
import Foundation
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var window: WidgetWindow!
    private var viewController: WidgetViewController!
    private var statusItem: NSStatusItem!
    private var aboutWindowController: AboutWindowController?
    private let showHideItem = NSMenuItem()
    private let modeItem = NSMenuItem()
    private let resetSizeItem = NSMenuItem()
    private let alwaysOnTopItem = NSMenuItem()
    private let launchAtLoginItem = NSMenuItem()
    private let glassAppearanceItem = NSMenuItem()
    private let contrastAppearanceItem = NSMenuItem()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        applyApplicationIcon()

        viewController = WidgetViewController()
        window = WidgetWindow(contentViewController: viewController)
        window.delegate = viewController
        setupStatusItem()
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()

        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            showWidget()
        }
        updateMenuItems()
        return true
    }

    @MainActor
    func menuWillOpen(_ menu: NSMenu) {
        updateMenuItems()
    }

    @MainActor
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            let image = NSImage(systemSymbolName: "chart.line.uptrend.xyaxis", accessibilityDescription: "Macmontor")
            image?.isTemplate = true
            button.image = image
            button.toolTip = "Macmontor"
        }

        let menu = NSMenu()
        menu.delegate = self

        let titleItem = NSMenuItem(title: "Macmontor", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)
        menu.addItem(.separator())

        let aboutItem = NSMenuItem(title: "About Macmontor", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)
        menu.addItem(.separator())

        showHideItem.target = self
        showHideItem.action = #selector(toggleWidgetWindow)
        showHideItem.keyEquivalent = "w"
        menu.addItem(showHideItem)

        modeItem.target = self
        modeItem.action = #selector(toggleWidgetMode)
        modeItem.keyEquivalent = "m"
        menu.addItem(modeItem)

        resetSizeItem.title = "Reset Size"
        resetSizeItem.target = self
        resetSizeItem.action = #selector(resetWidgetSize)
        menu.addItem(resetSizeItem)

        alwaysOnTopItem.title = "Always on Top"
        alwaysOnTopItem.target = self
        alwaysOnTopItem.action = #selector(toggleAlwaysOnTop)
        menu.addItem(alwaysOnTopItem)

        let appearanceMenu = NSMenu()
        glassAppearanceItem.title = "Glass"
        glassAppearanceItem.target = self
        glassAppearanceItem.action = #selector(useGlassAppearance)
        appearanceMenu.addItem(glassAppearanceItem)

        contrastAppearanceItem.title = "Contrast"
        contrastAppearanceItem.target = self
        contrastAppearanceItem.action = #selector(useContrastAppearance)
        appearanceMenu.addItem(contrastAppearanceItem)

        let appearanceItem = NSMenuItem(title: "Appearance", action: nil, keyEquivalent: "")
        appearanceItem.submenu = appearanceMenu
        menu.addItem(appearanceItem)

        launchAtLoginItem.title = "Launch at Login"
        launchAtLoginItem.target = self
        launchAtLoginItem.action = #selector(toggleLaunchAtLogin)
        menu.addItem(launchAtLoginItem)

        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: "Quit Macmontor", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
        updateMenuItems()
    }

    @MainActor
    private func updateMenuItems() {
        showHideItem.title = window.isVisible ? "Hide Widget" : "Show Widget"
        modeItem.title = viewController.currentMode == .detail ? "Switch to Compact" : "Switch to Detail"
        glassAppearanceItem.state = Palette.appearance == .glass ? .on : .off
        contrastAppearanceItem.state = Palette.appearance == .contrast ? .on : .off
        alwaysOnTopItem.state = window.isAlwaysOnTop ? .on : .off
        launchAtLoginItem.state = launchAtLoginEnabled ? .on : .off
    }

    @MainActor
    @objc private func toggleWidgetWindow() {
        if window.isVisible {
            window.saveFrame()
            window.orderOut(nil)
        } else {
            showWidget()
        }
        updateMenuItems()
    }

    @MainActor
    @objc private func showAbout() {
        if aboutWindowController == nil {
            aboutWindowController = AboutWindowController()
        }

        aboutWindowController?.showWindow(nil)
        aboutWindowController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @MainActor
    @objc private func toggleWidgetMode() {
        showWidget()
        viewController.toggleMode()
        updateMenuItems()
    }

    @MainActor
    @objc private func resetWidgetSize() {
        showWidget()
        viewController.resetWindowSize(animated: true)
        updateMenuItems()
    }

    @MainActor
    @objc private func toggleAlwaysOnTop() {
        window.setAlwaysOnTop(!window.isAlwaysOnTop)
        updateMenuItems()
    }

    @MainActor
    @objc private func useGlassAppearance() {
        setAppearance(.glass)
    }

    @MainActor
    @objc private func useContrastAppearance() {
        setAppearance(.contrast)
    }

    @MainActor
    private func setAppearance(_ appearance: WidgetAppearance) {
        Palette.appearance = appearance
        viewController.applyAppearance()
        updateMenuItems()
    }

    @MainActor
    @objc private func toggleLaunchAtLogin() {
        do {
            if launchAtLoginEnabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            NSSound.beep()
            NSLog("Macmontor launch at login update failed: \(error.localizedDescription)")
        }
        updateMenuItems()
    }

    private var launchAtLoginEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    @MainActor
    @objc private func quitApp() {
        window.saveFrame()
        NSApp.terminate(nil)
    }

    @MainActor
    private func showWidget() {
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
    }

    @MainActor
    private func applyApplicationIcon() {
        guard
            let iconURL = Bundle.main.url(forResource: "Macmontor", withExtension: "icns"),
            let icon = NSImage(contentsOf: iconURL)
        else {
            return
        }

        NSApp.applicationIconImage = icon
    }
}
