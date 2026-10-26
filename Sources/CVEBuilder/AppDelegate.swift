import AppKit
import Combine
import CVECore
import SwiftUI
import UserNotifications

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, UNUserNotificationCenterDelegate {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var onboardingWindow: NSWindow?
    private var settingsWindow: NSWindow?
    private var alertWindow: NSWindow?
    private let model = AppModel()
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.appearance = NSAppearance(named: .darkAqua)
        NSApp.setActivationPolicy(.regular)

        let arguments = CommandLine.arguments
        let isBackground = arguments.contains("--background")
        let forceOnboarding = arguments.contains("--onboarding")
        let forcePanel = arguments.contains("--panel")
        let forceReport = arguments.contains("--report")

        buildMenu()
        configureStatusItem()
        configurePopover()
        wireModel()

        UNUserNotificationCenter.current().delegate = self
        model.start()

        if forceReport {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                self?.openReport()
            }
        } else if forceOnboarding || (!isBackground && !model.settings.hasCompletedOnboarding) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                self?.openOnboarding()
            }
        } else if forcePanel {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
                self?.showPopover()
            }
        } else if !isBackground, !arguments.contains("--scan"), debugAlertIndex() == nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
                self?.showPopover()
            }
        }

        if arguments.contains("--scan") {
            model.scan()
        }

        if let index = debugAlertIndex() {
            model.$report
                .receive(on: RunLoop.main)
                .sink { [weak self] report in
                    guard let self,
                          self.alertWindow == nil,
                          let alerts = report?.alerts,
                          alerts.indices.contains(index) else { return }
                    self.openAlert(alerts[index])
                }
                .store(in: &cancellables)
        }
    }

    private func debugAlertIndex() -> Int? {
        let arguments = CommandLine.arguments
        guard let flagIndex = arguments.firstIndex(of: "--alert") else {
            return arguments.first(where: { $0.hasPrefix("--alert=") })
                .flatMap { Int($0.dropFirst("--alert=".count)) }
        }
        let next = flagIndex + 1
        if next < arguments.count, let index = Int(arguments[next]) {
            return index
        }
        return 0
    }

    func applicationWillTerminate(_ notification: Notification) {
        model.stop()
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        if !model.settings.hasCompletedOnboarding {
            openOnboarding()
            return true
        }
        if let window = settingsWindow, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return true
        }
        if let window = onboardingWindow, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return true
        }
        showPopover()
        return true
    }

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        if window == onboardingWindow { onboardingWindow = nil }
        if window == settingsWindow { settingsWindow = nil }
        if window == alertWindow { alertWindow = nil }
    }

    private func wireModel() {
        model.onQuit = {
            NSApp.terminate(nil)
        }
        model.onOpenSettings = { [weak self] in
            self?.openSettings()
        }
        model.onOpenAlert = { [weak self] alert in
            self?.openAlert(alert)
        }
        model.onOpenReport = { [weak self] in
            self?.openReport()
        }
        model.onOpenOnboarding = { [weak self] in
            self?.openOnboarding()
        }
        model.onShowPanel = { [weak self] in
            self?.showPopover()
        }

        model.$report
            .combineLatest(model.$isScanning)
            .receive(on: RunLoop.main)
            .sink { [weak self] report, scanning in
                self?.updateStatusItem(report: report, scanning: scanning)
            }
            .store(in: &cancellables)
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            let image = BrandAssets.statusBarImage()
            image.size = NSSize(width: 18, height: 18)
            image.isTemplate = true
            button.image = image
            button.image?.isTemplate = true
            button.contentTintColor = nil
            button.imagePosition = .imageLeading
            button.imageScaling = .scaleProportionallyDown
            button.font = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .semibold)
            button.target = self
            button.action = #selector(togglePopover(_:))
            button.sendAction(on: [.leftMouseUp])
            button.toolTip = "Builders Protect"
        }
        statusItem = item
    }

    private func configurePopover() {
        let popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = NSSize(width: 460, height: 720)
        popover.contentViewController = NSHostingController(
            rootView: PanelView(model: model)
        )
        self.popover = popover
    }

    @objc private func togglePopover(_ sender: Any?) {
        guard let popover else { return }
        if popover.isShown {
            popover.performClose(nil)
            return
        }
        showPopover()
    }

    private func showPopover() {
        guard let popover, let button = statusItem?.button else { return }
        model.panelOpened()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.hasShadow = false
        NSApp.activate(ignoringOtherApps: true)
        popover.contentViewController?.view.window?.makeKey()
    }

    private func updateStatusItem(report: ScanReport?, scanning: Bool) {
        guard let button = statusItem?.button else { return }

        if scanning {
            button.title = ""
            button.contentTintColor = nil
            button.toolTip = "Builders Protect — verificando dependências"
            return
        }

        let findings = report?.totalFindings ?? 0
        button.title = ""
        button.contentTintColor = nil

        if findings > 0 {
            let projects = report?.alerts.count ?? 0
            button.toolTip = "Vulnerabilidades em \(Vocabulary.quantity(projects, "projeto", "projetos"))"
        } else {
            button.toolTip = "Builders Protect — nenhuma vulnerabilidade conhecida"
        }
    }

    private func buildMenu() {
        let mainMenu = NSMenu()

        let appItem = NSMenuItem()
        appItem.title = "Builders Protect"
        mainMenu.addItem(appItem)
        let appMenu = NSMenu(title: "Builders Protect")
        appItem.submenu = appMenu

        let about = appMenu.addItem(
            withTitle: "Sobre o Builders Protect",
            action: #selector(showAbout),
            keyEquivalent: ""
        )
        about.target = self

        appMenu.addItem(.separator())

        let check = appMenu.addItem(
            withTitle: "Verificar agora",
            action: #selector(checkNow),
            keyEquivalent: "r"
        )
        check.target = self

        let panel = appMenu.addItem(
            withTitle: "Abrir painel",
            action: #selector(showPanelFromMenu),
            keyEquivalent: "p"
        )
        panel.keyEquivalentModifierMask = [.command, .shift]
        panel.target = self

        let report = appMenu.addItem(
            withTitle: "Abrir controle total",
            action: #selector(showReport),
            keyEquivalent: ""
        )
        report.target = self

        let settings = appMenu.addItem(
            withTitle: "Ajustes…",
            action: #selector(showSettings),
            keyEquivalent: ","
        )
        settings.target = self

        let onboarding = appMenu.addItem(
            withTitle: "Rever configuração",
            action: #selector(showOnboarding),
            keyEquivalent: ""
        )
        onboarding.target = self

        appMenu.addItem(.separator())

        let quit = appMenu.addItem(
            withTitle: "Sair do Builders Protect",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quit.target = self

        let editItem = NSMenuItem()
        editItem.title = "Editar"
        mainMenu.addItem(editItem)
        let editMenu = NSMenu(title: "Editar")
        editItem.submenu = editMenu
        editMenu.addItem(withTitle: "Desfazer", action: Selector(("undo:")), keyEquivalent: "z")
        let redo = editMenu.addItem(withTitle: "Refazer", action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cortar", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copiar", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Colar", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Selecionar tudo", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        let windowItem = NSMenuItem()
        windowItem.title = "Janela"
        mainMenu.addItem(windowItem)
        let windowMenu = NSMenu(title: "Janela")
        windowItem.submenu = windowMenu
        windowMenu.addItem(
            withTitle: "Minimizar",
            action: #selector(NSWindow.performMiniaturize(_:)),
            keyEquivalent: "m"
        )
        windowMenu.addItem(
            withTitle: "Fechar",
            action: #selector(NSWindow.performClose(_:)),
            keyEquivalent: "w"
        )
        NSApp.windowsMenu = windowMenu

        NSApp.mainMenu = mainMenu
    }

    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        let menu = NSMenu()

        let panel = menu.addItem(
            withTitle: "Abrir painel",
            action: #selector(showPanelFromMenu),
            keyEquivalent: ""
        )
        panel.target = self

        let control = menu.addItem(
            withTitle: "Abrir controle total",
            action: #selector(showReport),
            keyEquivalent: ""
        )
        control.target = self

        menu.addItem(.separator())

        let check = menu.addItem(
            withTitle: "Verificar agora",
            action: #selector(checkNow),
            keyEquivalent: ""
        )
        check.target = self

        return menu
    }

    @objc private func showPanelFromMenu() {
        showPopover()
    }

    @objc private func showAbout() {
        let credits = NSAttributedString(
            string: "Vulnerabilidades sob controle.\nUma ferramenta da Cultura Builder.",
            attributes: [
                .font: NSFont.systemFont(ofSize: 11, weight: .regular),
                .foregroundColor: NSColor.secondaryLabelColor
            ]
        )
        NSApp.orderFrontStandardAboutPanel(
            options: [
                .applicationName: "Builders Protect",
                .applicationVersion: BrandAssets.version,
                .credits: credits
            ]
        )
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func checkNow() {
        model.scan()
    }

    @objc private func showSettings() {
        openSettings()
    }

    @objc private func showReport() {
        openReport()
    }

    @objc private func showOnboarding() {
        openOnboarding()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    private func openOnboarding() {
        popover?.performClose(nil)

        if let window = onboardingWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let view = OnboardingView(model: model) { [weak self] in
            self?.closeOnboarding()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                self?.showPopover()
            }
        }
        let hosting = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hosting)
        window.title = "Builders Protect"
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.backgroundColor = NSColor(red: 0.031, green: 0.035, blue: 0.030, alpha: 1)
        window.appearance = NSAppearance(named: .darkAqua)
        window.setContentSize(NSSize(width: 920, height: 640))
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.hasShadow = false
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        onboardingWindow = window
    }

    private func closeOnboarding() {
        onboardingWindow?.orderOut(nil)
        onboardingWindow = nil
    }

    private func openReport() {
        openSettings(section: .analysis)
    }

    private func openSettings(section: SettingsSection = .account) {
        popover?.performClose(nil)
        model.settingsSection = section

        if let window = settingsWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let view = SettingsView(model: model) { [weak self] in
            self?.settingsWindow?.close()
        }
        let hosting = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hosting)
        window.title = "Builders Protect"
        window.styleMask = [
            .titled, .closable, .miniaturizable, .resizable, .fullSizeContentView
        ]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.backgroundColor = NSColor(red: 0.031, green: 0.035, blue: 0.030, alpha: 1)
        window.appearance = NSAppearance(named: .darkAqua)
        window.setContentSize(NSSize(width: 1120, height: 820))
        window.minSize = NSSize(width: 980, height: 680)
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.hasShadow = false
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow = window
    }

    private func openAlert(_ alert: ProjectAlert) {
        alertWindow?.close()

        let view = AlertDetailView(model: model, alert: alert)
        let hosting = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hosting)
        window.title = "Alerta — \(alert.project.name)"
        window.styleMask = [
            .titled, .closable, .miniaturizable, .resizable, .fullSizeContentView
        ]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.backgroundColor = NSColor(red: 0.031, green: 0.035, blue: 0.030, alpha: 1)
        window.appearance = NSAppearance(named: .darkAqua)
        window.setContentSize(NSSize(width: 920, height: 760))
        window.minSize = NSSize(width: 820, height: 600)
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.hasShadow = false
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        alertWindow = window
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        Task { @MainActor [weak self] in
            self?.showPopover()
        }
        completionHandler()
    }
}
