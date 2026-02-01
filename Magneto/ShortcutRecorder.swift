import SwiftUI
import Carbon

struct ShortcutRecorder: View {
    let title: String
    @Binding var keyCombo: KeyCombo?
    @State private var monitor: Any?
    @State private var isRecording = false
    
    var body: some View {
        HStack {
            Text(title)
            Spacer()
            
            Button(action: {
                isRecording = true
            }) {
                HStack(spacing: 3) {
                    if isRecording {
                        Text(NSLocalizedString("Type Shortcut (Esc to Cancel)...", comment: ""))
                            .foregroundColor(.secondary)
                    } else if let combo = keyCombo {
                        // Modifiers
                        if (combo.modifiers & controlKey) != 0 { Text("⌃") }
                        if (combo.modifiers & optionKey) != 0 { Text("⌥") }
                        if (combo.modifiers & shiftKey) != 0 { Text("⇧") }
                        if (combo.modifiers & cmdKey) != 0 { Text("⌘") }
                        
                        // Key
                        Text(getKeyString(keyCode: combo.keyCode))
                    } else {
                        Text(NSLocalizedString("None", comment: ""))
                    }
                }
                .font(.system(.body, design: .monospaced))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(isRecording ? Color.accentColor.opacity(0.1) : Color(nsColor: .controlBackgroundColor))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isRecording ? Color.accentColor : Color(nsColor: .separatorColor), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
        .onChange(of: isRecording) { recording in
            if recording {
                // Add monitor
                monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                    // Esc to cancel
                    if event.keyCode == 53 {
                        isRecording = false
                        return nil
                    }
                    
                    // Capture valid shortcut
                    // Ignore modifiers only
                    if event.keyCode < 65535 {
                        var modifiers = 0
                        if event.modifierFlags.contains(.control) { modifiers |= controlKey }
                        if event.modifierFlags.contains(.option) { modifiers |= optionKey }
                        if event.modifierFlags.contains(.shift) { modifiers |= shiftKey }
                        if event.modifierFlags.contains(.command) { modifiers |= cmdKey }
                        
                        let newCombo = KeyCombo(keyCode: Int(event.keyCode), modifiers: modifiers)
                        keyCombo = newCombo
                        isRecording = false
                        return nil // Consume event
                    }
                    
                    return event
                }
            } else {
                // Remove monitor
                if let m = monitor {
                    NSEvent.removeMonitor(m)
                    monitor = nil
                }
            }
        }
    }
    
    // Helper to print key string active
    func getKeyString(keyCode: Int) -> String {
        switch keyCode {
        case 123: return "←"
        case 124: return "→"
        case 126: return "↑"
        case 125: return "↓"
        default:
             // Very basic mapping for demo
            return "\(keyCode)"
        }
    }
}
