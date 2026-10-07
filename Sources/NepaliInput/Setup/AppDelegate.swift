import AppKit
import Carbon.HIToolbox

/// Opening the app a second time (Spotlight, Finder, the launcher in /Applications) shows its window.
/// The system also starts this process on its own, when the keyboard is selected or at login;
/// those starts must stay invisible.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        let event = NSAppleEventManager.shared().currentAppleEvent
        let launchedAtLogin = event?.paramDescriptor(forKeyword: AEKeyword(keyAEPropData))?.enumCodeValue
            == OSType(keyAELaunchedAsLogInItem)
        // Selecting the keyboard makes the system launch us while it is the current source.
        let startedByKeyboard = SetupModel.currentKeyboardBundleID() == Bundle.main.bundleIdentifier
        guard !launchedAtLogin, !startedByKeyboard, !SetupWindowController.needsSetup else { return }
        DispatchQueue.main.async { SetupWindowController.shared.show(.settings) }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        SetupWindowController.shared.show(.settings)
        return true
    }
}
