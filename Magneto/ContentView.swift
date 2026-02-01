import SwiftUI
import ApplicationServices
import Combine

struct ContentView: View {
    @State private var selectedTab: Int = 0
    
    @AppStorage("appAppearance") private var appAppearance = "system"

    var body: some View {
        TabView(selection: $selectedTab) {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }
                .tag(0)
            
            ShortcutsSettingsView()
                .tabItem {
                    Label("Shortcuts", systemImage: "keyboard")
                }
                .tag(1)
            
            AboutSettingsView()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
                .tag(2)
        }
        .frame(width: 450, height: 350)
        .padding()
        .preferredColorScheme(appAppearance == "dark" ? .dark : (appAppearance == "light" ? .light : nil))
    }
}

// MARK: - General Tab

struct GeneralSettingsView: View {
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("appAppearance") private var appAppearance = "system"
    
    // Timer to check permission status because AXIsProcessTrusted doesn't notify changes.
    @State private var isTrusted: Bool = AXIsProcessTrusted()
    let timer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()
    
    var body: some View {
        Form {
            Section {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: isTrusted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(isTrusted ? .green : .red)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(isTrusted ? "Accessibility Permission Granted" : "Permission Required")
                            .font(.headline)
                        
                        Text(isTrusted ? "Magneto has necessary permissions to manage windows." : "Magneto needs accessibility permissions to move and resize windows.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        if !isTrusted {
                            Button("Open System Settings") {
                                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                                    NSWorkspace.shared.open(url)
                                }
                            }
                            .padding(.top, 4)
                        }
                    }
                }
                .padding(.vertical, 8)
            } header: {
                Text("Permissions")
            }
            
            Section {
                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .toggleStyle(.switch)
            } header: {
                Text("Startup")
            }
            
            Section {
                Picker("Color Theme", selection: $appAppearance) {
                    Text("System").tag("system")
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                }
                .pickerStyle(.inline)
            } header: {
                Text("Appearance")
            }
        }
        .formStyle(.grouped)
        .onReceive(timer) { _ in
            isTrusted = AXIsProcessTrusted()
        }
    }
}

// MARK: - Shortcuts Tab

struct ShortcutsSettingsView: View {
    @ObservedObject var hotkeyManager = HotkeyManager.shared
    
    var body: some View {
        Form {
            Section {
                recorderRow(title: NSLocalizedString("Snap Left", comment: ""), action: .snapLeft)
                recorderRow(title: NSLocalizedString("Snap Right", comment: ""), action: .snapRight)
                recorderRow(title: NSLocalizedString("Maximize", comment: ""), action: .maximize)
                recorderRow(title: NSLocalizedString("Center", comment: ""), action: .center)
            } header: {
                Text("Global Hotkeys")
            }
            
            Section {
                Button("Reset to Defaults") {
                    hotkeyManager.resetToDefaults()
                }
            }
        }
        .formStyle(.grouped)
    }
    
    private func recorderRow(title: String, action: HotkeyManager.Action) -> some View {
        // Custom binding to bridge between Dictionary and View
        let binding = Binding(
            get: {
                hotkeyManager.shortcuts[action.rawValue]
            },
            set: { newCombo in
                hotkeyManager.updateShortcut(for: action, combo: newCombo)
            }
        )
        
        return ShortcutRecorder(title: title, keyCombo: binding)
    }
}

// MARK: - About Tab

struct AboutSettingsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "rectangle.inset.filled")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 80)
                .symbolRenderingMode(.hierarchical)
                .foregroundColor(.accentColor)
            
            VStack(spacing: 4) {
                Text("Magneto")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("v1.0")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Text("Copyright © 2026 Celil Öz")
                .font(.caption)
                .foregroundColor(Color(nsColor: .tertiaryLabelColor))
            
            Spacer()
        }
    }
}
