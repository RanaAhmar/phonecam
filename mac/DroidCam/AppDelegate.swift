import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    var menuBarController: MenuBarController!
    var mainWindowController: MainWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide from Dock — menu bar only app
        NSApp.setActivationPolicy(.accessory)

        menuBarController = MenuBarController()
        menuBarController.onShowMainWindow = { [weak self] in
            self?.showMainWindow()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        menuBarController.cleanup()
    }

    func showMainWindow() {
        if mainWindowController == nil {
            mainWindowController = MainWindowController()
        }
        mainWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
