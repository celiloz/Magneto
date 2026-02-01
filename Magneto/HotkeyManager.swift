import Cocoa
import Carbon
import Combine

// Global C-compatible callback function
func hotKeyHandler(nextHandler: EventHandlerCallRef?, event: EventRef?, userData: UnsafeMutableRawPointer?) -> OSStatus {
    return HotkeyManager.shared.handleCarbonEvent(event)
}

struct KeyCombo: Codable, Equatable {
    let keyCode: Int
    let modifiers: Int // Carbon modifiers
    
    // Helper for UI display
    var displayString: String {
        var str = ""
        if (modifiers & controlKey) != 0 { str += "⌃" }
        if (modifiers & optionKey) != 0 { str += "⌥" }
        if (modifiers & shiftKey) != 0 { str += "⇧" }
        if (modifiers & cmdKey) != 0 { str += "⌘" }
        
        // Key codes mapping (basic subset)
        switch keyCode {
        case 123: str += "←"
        case 124: str += "→"
        case 126: str += "↑"
        case 125: str += "↓"
        default: str += "" // Handle other keys if we allow robust recording
        }
        return str
    }
}

class HotkeyManager: ObservableObject {
    static let shared = HotkeyManager()
    
    private var eventHandlerRef: EventHandlerRef?
    private var hotKeyRefs: [UInt32: EventHotKeyRef] = [:]
    
    // Actions
    enum Action: String, CaseIterable {
        case snapLeft = "SnapLeft"
        case snapRight = "SnapRight"
        case maximize = "Maximize"
        case center = "Center"
        
        var id: UInt32 {
            switch self {
            case .snapLeft: return 1
            case .snapRight: return 2
            case .maximize: return 3
            case .center: return 4
            }
        }
    }
    
    // Storage
    @Published var shortcuts: [String: KeyCombo] = [:]
    
    private init() {
        loadShortcuts()
    }
    
    private func loadShortcuts() {
        if let data = UserDefaults.standard.data(forKey: "shortcuts"),
           let decoded = try? JSONDecoder().decode([String: KeyCombo].self, from: data) {
            self.shortcuts = decoded
        } else {
            // Defaults
            let modifiers = controlKey | optionKey
            shortcuts = [
                Action.snapLeft.rawValue: KeyCombo(keyCode: 123, modifiers: modifiers), // Left Arrow
                Action.snapRight.rawValue: KeyCombo(keyCode: 124, modifiers: modifiers), // Right Arrow
                Action.maximize.rawValue: KeyCombo(keyCode: 126, modifiers: modifiers), // Up Arrow
                Action.center.rawValue: KeyCombo(keyCode: 125, modifiers: modifiers)   // Down Arrow
            ]
        }
    }
    
    func saveShortcuts() {
        if let encoded = try? JSONEncoder().encode(shortcuts) {
            UserDefaults.standard.set(encoded, forKey: "shortcuts")
        }
    }
    
    func resetToDefaults() {
        let modifiers = controlKey | optionKey
        shortcuts = [
            Action.snapLeft.rawValue: KeyCombo(keyCode: 123, modifiers: modifiers), // Left Arrow
            Action.snapRight.rawValue: KeyCombo(keyCode: 124, modifiers: modifiers), // Right Arrow
            Action.maximize.rawValue: KeyCombo(keyCode: 126, modifiers: modifiers), // Up Arrow
            Action.center.rawValue: KeyCombo(keyCode: 125, modifiers: modifiers)   // Down Arrow
        ]
        saveShortcuts()
        registerHotkeys()
    }
    
    func registerHotkeys() {
        // Unregister existing first if needed (basic cleanup)
        unregisterAll()
        
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        
        // Install Event Handler if not already
        if eventHandlerRef == nil {
            InstallEventHandler(GetApplicationEventTarget(), hotKeyHandler, 1, &eventType, nil, &eventHandlerRef)
        }
        
        // Register each
        for action in Action.allCases {
            if let combo = shortcuts[action.rawValue] {
                register(action: action, combo: combo)
            }
        }
    }
    
    func unregisterAll() {
        for (_, ref) in hotKeyRefs {
            UnregisterEventHotKey(ref)
        }
        hotKeyRefs.removeAll()
    }
    
    func updateShortcut(for action: Action, combo: KeyCombo?) {
        // Remove old
        if let existingRef = hotKeyRefs[action.id] {
            UnregisterEventHotKey(existingRef)
            hotKeyRefs.removeValue(forKey: action.id)
        }
        
        if let combo = combo {
            shortcuts[action.rawValue] = combo
            register(action: action, combo: combo)
        } else {
            shortcuts.removeValue(forKey: action.rawValue)
        }
        
        saveShortcuts()
    }
    
    private func register(action: Action, combo: KeyCombo) {
        var hotKeyRef: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: OSType(1296122708), id: action.id) // Signature 'MAGN'
        
        let status = RegisterEventHotKey(UInt32(combo.keyCode), UInt32(combo.modifiers), hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
        
        if status != noErr {
            Logger.shared.log("Failed to register hotkey ID: \(action.id), error: \(status)")
        } else {
            if let ref = hotKeyRef {
                hotKeyRefs[action.id] = ref
            }
            Logger.shared.log("Successfully registered hotkey for \(action.rawValue)")
        }
    }
    
    func handleCarbonEvent(_ event: EventRef?) -> OSStatus {
        guard let event = event else { return OSStatus(eventNotHandledErr) }
        
        var hotKeyID = EventHotKeyID()
        let result = GetEventParameter(event,
                                       EventParamName(kEventParamDirectObject),
                                       EventParamType(typeEventHotKeyID),
                                       nil,
                                       MemoryLayout<EventHotKeyID>.size,
                                       nil,
                                       &hotKeyID)
        
        if result == noErr {
            Logger.shared.log("Hotkey pressed: \(hotKeyID.id)")
            
            // Map ID back to Action
            if let action = Action.allCases.first(where: { $0.id == hotKeyID.id }) {
                switch action {
                case .snapLeft:
                    WindowManager.shared.snapFocusedWindow(to: .leftHalf)
                case .snapRight:
                    WindowManager.shared.snapFocusedWindow(to: .rightHalf)
                case .maximize:
                    WindowManager.shared.snapFocusedWindow(to: .maximize)
                case .center:
                    WindowManager.shared.snapFocusedWindow(to: .center)
                }
                return noErr
            }
        }
        
        return OSStatus(eventNotHandledErr)
    }
}
