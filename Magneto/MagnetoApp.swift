import SwiftUI

@main
struct MagnetoApp: App {
    // Ensuring managers are initialized.
    init() {
        Logger.shared.log("Magneto App Initialized")
        // check accessibility permissions on launch
        PermissionsManager.shared.checkAccessibilityPermissions()
        // register hotkeys
        HotkeyManager.shared.registerHotkeys()
    }
    
    var body: some Scene {
        // macOS 13+ Menu Bar Extra.
        MenuBarExtra("Magneto", systemImage: "uiwindow.split.2x1") {
            MagnetoMenu()
        }
        
        // Define the Settings Window
        Settings {
             ContentView()
        }
    }
}

struct MagnetoMenu: View {
    @ObservedObject var hotkeyManager = HotkeyManager.shared
    
    var body: some View {
        Button(menuTitle(NSLocalizedString("Snap Left", comment: ""), for: .snapLeft)) {
            WindowManager.shared.snapFocusedWindow(to: .leftHalf)
        }
        Button(menuTitle(NSLocalizedString("Snap Right", comment: ""), for: .snapRight)) {
            WindowManager.shared.snapFocusedWindow(to: .rightHalf)
        }
        Button(menuTitle(NSLocalizedString("Maximize", comment: ""), for: .maximize)) {
            WindowManager.shared.snapFocusedWindow(to: .maximize)
        }
        Button(menuTitle(NSLocalizedString("Center", comment: ""), for: .center)) {
            WindowManager.shared.snapFocusedWindow(to: .center)
        }
        
        Divider()
        
        Button(NSLocalizedString("Settings...", comment: "")) {
            SettingsWindowController.shared.showWindow()
        }
        .keyboardShortcut(",", modifiers: .command)
        
        Button(NSLocalizedString("Quit", comment: "")) {
            NSApplication.shared.terminate(nil)
        }
    }
    
    private func menuTitle(_ title: String, for action: HotkeyManager.Action) -> String {
        if let combo = hotkeyManager.shortcuts[action.rawValue] {
            return "\(title) (\(combo.displayString))"
        }
        return title
    }
}


// Simple singleton to handle window if not using SwiftUI Settings scene perfectly or for older macOS support logic helpers
class SettingsWindowController {
    static let shared = SettingsWindowController()
    private var window: NSWindow?
    
    func showWindow() {
        if window == nil {
            let contentView = ContentView()
            window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 450, height: 400),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered, defer: false)
            window?.center()
            window?.title = "Magneto Settings"
            window?.contentView = NSHostingView(rootView: contentView)
            window?.isReleasedWhenClosed = false
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
