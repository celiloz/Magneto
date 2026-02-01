import Cocoa
import ApplicationServices

class WindowManager {
    static let shared = WindowManager()
    
    private init() {}
    
    enum SnapPosition {
        case leftHalf
        case rightHalf
        case maximize
        case center
    }
    
    func snapFocusedWindow(to position: SnapPosition) {
        Logger.shared.log("Attempting to snap window to \(position)")
        guard let focusedWindow = getFocusedWindow() else {
            Logger.shared.log("No focused window found. Check Accessibility Permissions.")
            return
        }
        
        guard let screenFrame = getNSScreenFrame() else {
            Logger.shared.log("Could not determine screen frame.")
            return
        }
        
        var newFrame: CGRect = .zero
        
        switch position {
        case .leftHalf:
            newFrame = CGRect(x: screenFrame.minX, y: screenFrame.minY, width: screenFrame.width / 2, height: screenFrame.height)
        case .rightHalf:
            newFrame = CGRect(x: screenFrame.minX + screenFrame.width / 2, y: screenFrame.minY, width: screenFrame.width / 2, height: screenFrame.height)
        case .maximize:
            newFrame = screenFrame
        case .center:
            let width = screenFrame.width * 0.66
            let height = screenFrame.height * 0.66
            let x = screenFrame.minX + (screenFrame.width - width) / 2
            let y = screenFrame.minY + (screenFrame.height - height) / 2
            newFrame = CGRect(x: x, y: y, width: width, height: height)
        }
        
        setWindowFrame(window: focusedWindow, frame: newFrame)
    }
    
    // MARK: - AXUIElement Helpers
    
    // MARK: - AXUIElement Helpers
    
    private func getFocusedWindow() -> AXUIElement? {
        // 1. Check Permissions
        if !PermissionsManager.shared.isTrusted {
            Logger.shared.log("Accessibility permissions not trusted. Returning nil.")
            return nil
        }

        // 2. Try System-Wide Focus
        if let window = getSystemWideFocusedWindow() {
            return window
        }
        
        // 3. Fallback: Try Frontmost App
        Logger.shared.log("System-wide focus failed. Trying frontmost app...")
        if let window = getFrontmostAppWindow() {
            return window
        }
        
        return nil
    }
    
    private func getSystemWideFocusedWindow() -> AXUIElement? {
        let systemWideElement = AXUIElementCreateSystemWide()
        var focusedElement: AnyObject?
        
        let result = AXUIElementCopyAttributeValue(systemWideElement, kAXFocusedUIElementAttribute as CFString, &focusedElement)
        
        guard result == .success, let element = focusedElement else {
            Logger.shared.log("Error getting system focused element: \(result.rawValue)")
            return nil
        }
        
        return findWindowParent(for: element as! AXUIElement)
    }
    
    private func getFrontmostAppWindow() -> AXUIElement? {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else {
            Logger.shared.log("No frontmost application found.")
            return nil
        }
        
        let appElement = AXUIElementCreateApplication(frontApp.processIdentifier)
        var focusedWindow: AnyObject?
        
        // Try to get the focused window of the app directly
        let result = AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focusedWindow)
        
        if result == .success, let window = focusedWindow {
             return (window as! AXUIElement)
        }
        
        // If that fails, try getting the focused element of the app and traversing up
        Logger.shared.log("Could not get kAXFocusedWindow from frontmost app. Trying focused UI element.")
        var focusedElement: AnyObject?
        let elementResult = AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focusedElement)
        
        if elementResult == .success, let element = focusedElement {
            return findWindowParent(for: element as! AXUIElement)
        }
        
        return nil
    }
    
    private func findWindowParent(for element: AXUIElement) -> AXUIElement? {
        var currentElement = element
        var role: AnyObject?
        
        // Traverse up the hierarchy to find the Window
        // Max depth to prevent infinite loops
        for _ in 0..<10 {
            let roleResult = AXUIElementCopyAttributeValue(currentElement, kAXRoleAttribute as CFString, &role)
            
            if roleResult == .success, let roleString = role as? String {
                // Logger.shared.log("Found element with role: \(roleString)")
                if roleString == kAXWindowRole {
                    return currentElement
                }
            }
            
            // Get parent
            var parent: AnyObject?
            let parentResult = AXUIElementCopyAttributeValue(currentElement, kAXParentAttribute as CFString, &parent)
            
            if parentResult == .success, let parentElement = parent {
                currentElement = parentElement as! AXUIElement
            } else {
                break
            }
        }
        
        Logger.shared.log("Could not find a window parent for the element.")
        return nil
    }
    
    private func setWindowFrame(window: AXUIElement, frame: CGRect) {
        // Log the window title for debug purposes
        var title: AnyObject?
        AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &title)
        Logger.shared.log("Setting frame for window: \(title as? String ?? "Unknown")")
        
        // Converting visibleFrame (Cocoa) to AX (Quartz/Global) coordinates.
        // The main screen height is needed to flip Y.
        guard let mainScreenHeight = NSScreen.screens.first?.frame.height else { return }
        
        // Flip Y for the top-left origin
        // y_quartz = screen_height - (y_cocoa + height_cocoa)
        
        let axX = frame.origin.x
        let axY = mainScreenHeight - (frame.origin.y + frame.height)
        
        var position = CGPoint(x: axX, y: axY)
        var size = CGSize(width: frame.width, height: frame.height)
        
        // Create AXValues
        guard let positionValue = AXValueCreate(.cgPoint, &position),
              let sizeValue = AXValueCreate(.cgSize, &size) else {
            return
        }
        
        // Check if attributes are settable
        var sizeSettable: DarwinBoolean = false
        var posSettable: DarwinBoolean = false
        
        AXUIElementIsAttributeSettable(window, kAXSizeAttribute as CFString, &sizeSettable)
        AXUIElementIsAttributeSettable(window, kAXPositionAttribute as CFString, &posSettable)
        
        if !sizeSettable.boolValue || !posSettable.boolValue {
            Logger.shared.log("Warning: Window attributes might not be settable. Size: \(sizeSettable), Pos: \(posSettable)")
        }
        
        // Ideally set size first to avoid moving out of bounds, then position, then size again to be sure.
        let resSize1 = AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)
        let resPos = AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, positionValue)
        let resSize2 = AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)
        
        if resSize1 != .success || resPos != .success || resSize2 != .success {
            Logger.shared.log("Failed to set window attributes. Size1: \(resSize1.rawValue), Pos: \(resPos.rawValue), Size2: \(resSize2.rawValue)")
        } else {
            Logger.shared.log("Successfully snapped window.")
        }
    }
    
    private func getNSScreenFrame() -> CGRect? {
        // We really want the screen that contains the focused window, but for simplicity let's use the main screen or the screen with the mouse.
        // A better heuristic: use NSScreen.main which usually corresponds to the focused window's screen in modern macOS if the app is active,
        // BUT since we are a background helper, 'NSScreen.main' might be just the primary monitor.
        // Let's stick to NSScreen.main (primary with menu bar) for now as a baseline, or find the screen containing the mouse.
        
        // Simpler approach for this task: Use the screen containing the mouse cursor.
        let mouseLocation = NSEvent.mouseLocation
        let screens = NSScreen.screens
        if let screenWithMouse = screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) }) {
            return screenWithMouse.visibleFrame // proper rect for working area (excludes dock/menubar)
        }
        
        return NSScreen.main?.visibleFrame
    }
}
