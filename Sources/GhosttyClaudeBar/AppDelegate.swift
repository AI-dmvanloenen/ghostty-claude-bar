import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var monitor: SessionMonitor?
    private var statusController: StatusItemController?
    private var reportWindow: ReportWindowController?
    private var settingsWindow: SettingsWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let monitor = SessionMonitor(interval: AppSettings.refreshInterval)
        let reportWindow = ReportWindowController(monitor: monitor)
        let settingsWindow = SettingsWindowController(monitor: monitor)

        statusController = StatusItemController(
            monitor: monitor,
            onOpenReport: { reportWindow.show() },
            onOpenSettings: { settingsWindow.show() }
        )

        self.monitor = monitor
        self.reportWindow = reportWindow
        self.settingsWindow = settingsWindow

        monitor.start()

        // Convenience for launching straight into the window (demo / dev).
        if CommandLine.arguments.contains("--open-report") {
            reportWindow.show()
        }
    }
}
