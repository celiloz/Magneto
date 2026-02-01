import Cocoa
import ApplicationServices

class PermissionsManager {
    static let shared = PermissionsManager()
    
    private init() {}
    
    /// Checks if the application is trusted with Accessibility permissions.
    /// If not, it prompts the user to grant permissions.
    func checkAccessibilityPermissions() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String : true]
        let accessEnabled = AXIsProcessTrustedWithOptions(options)
        
        if !accessEnabled {
            Logger.shared.log("Accessibility Access Not Enabled. Prompting user...")
            // The system will automatically show the prompt due to the option above.
            // You can also show a custom alert here if you want to explain *why* you need it.
        } else {
            Logger.shared.log("Accessibility Access Enabled. Good to go.")
        }
    }
    
    var isTrusted: Bool {
        return AXIsProcessTrusted()
    }
}
