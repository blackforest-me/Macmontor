import AppKit

final class AboutWindowController: NSWindowController {
    init() {
        let contentViewController = AboutViewController()
        let window = NSWindow(contentViewController: contentViewController)
        window.title = "About Macmontor"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()
        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class AboutViewController: NSViewController {
    private let githubURL = URL(string: "https://github.com/blackforest-me/Macmontor")!

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 420, height: 260))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        buildUI()
    }

    private func buildUI() {
        let iconView = NSImageView()
        iconView.image = NSApp.applicationIconImage
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.translatesAutoresizingMaskIntoConstraints = false

        let titleField = NSTextField(labelWithString: "Macmontor")
        titleField.font = .systemFont(ofSize: 24, weight: .bold)
        titleField.alignment = .center

        let versionField = NSTextField(labelWithString: "Version \(Self.versionString)")
        versionField.font = .monospacedSystemFont(ofSize: 12, weight: .medium)
        versionField.textColor = .secondaryLabelColor
        versionField.alignment = .center

        let descriptionField = NSTextField(labelWithString: "Lightweight macOS performance widget")
        descriptionField.font = .systemFont(ofSize: 13, weight: .regular)
        descriptionField.textColor = .secondaryLabelColor
        descriptionField.alignment = .center

        let licenseField = NSTextField(labelWithString: "MIT License")
        licenseField.font = .systemFont(ofSize: 12, weight: .regular)
        licenseField.textColor = .tertiaryLabelColor
        licenseField.alignment = .center

        let openGitHubButton = NSButton(title: "Open GitHub", target: self, action: #selector(openGitHub))
        openGitHubButton.bezelStyle = .rounded

        let closeButton = NSButton(title: "Close", target: self, action: #selector(closeWindow))
        closeButton.bezelStyle = .rounded

        let buttonStack = NSStackView(views: [openGitHubButton, closeButton])
        buttonStack.orientation = .horizontal
        buttonStack.alignment = .centerY
        buttonStack.spacing = 10

        let stack = NSStackView(views: [
            iconView,
            titleField,
            versionField,
            descriptionField,
            licenseField,
            buttonStack
        ])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stack)
        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 68),
            iconView.heightAnchor.constraint(equalToConstant: 68),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -28),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    @objc private func openGitHub() {
        NSWorkspace.shared.open(githubURL)
    }

    @objc private func closeWindow() {
        view.window?.close()
    }

    private static var versionString: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version) (\(build))"
    }
}
