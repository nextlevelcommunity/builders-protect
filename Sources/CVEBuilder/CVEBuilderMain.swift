import AppKit

@main
struct CVEBuilderMain {
    static func main() {
        let application = NSApplication.shared
        application.setActivationPolicy(.accessory)

        if let bundleID = Bundle.main.bundleIdentifier {
            let duplicates = NSRunningApplication
                .runningApplications(withBundleIdentifier: bundleID)
                .filter { $0.processIdentifier != getpid() }
            if let other = duplicates.first {
                other.activate(options: [.activateIgnoringOtherApps])
                return
            }
        }

        let delegate = AppDelegate()
        application.delegate = delegate
        application.run()
    }
}
