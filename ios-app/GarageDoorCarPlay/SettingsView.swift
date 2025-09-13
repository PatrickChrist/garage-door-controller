import SwiftUI

struct SettingsView: View {
    @AppStorage("garage_base_url") private var baseURL = "192.168.1.100:8000"
    @AppStorage("use_external_access") private var useExternal = false
    @AppStorage("duckdns_domain") private var duckdnsDomain = ""
    @AppStorage("enable_notifications") private var enableNotifications = true
    @AppStorage("notification_sound") private var notificationSound = "default"
    
    @State private var isTestingConnection = false
    @State private var connectionTestResult = ""
    @State private var showingConnectionTest = false
    
    private var effectiveURL: String {
        if useExternal && !duckdnsDomain.isEmpty {
            return duckdnsDomain
        } else {
            return baseURL
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                // Connection Settings
                Section("Connection Settings") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Local Server URL")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("192.168.1.100:8000", text: $baseURL)
                            .textFieldStyle(.roundedBorder)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("DuckDNS Domain")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("mygarage.duckdns.org", text: $duckdnsDomain)
                            .textFieldStyle(.roundedBorder)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                    
                    Toggle("Use External Access", isOn: $useExternal)
                        .disabled(duckdnsDomain.isEmpty)
                    
                    HStack {
                        Text("Current URL:")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(effectiveURL)
                            .font(.caption)
                            .foregroundColor(useExternal ? .blue : .primary)
                    }
                }
                
                // Connection Test
                Section("Connection Test") {
                    Button(action: testConnection) {
                        HStack {
                            if isTestingConnection {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "wifi")
                            }
                            Text("Test Connection")
                        }
                    }
                    .disabled(isTestingConnection)
                    
                    if showingConnectionTest {
                        Text(connectionTestResult)
                            .font(.caption)
                            .foregroundColor(connectionTestResult.contains("Success") ? .green : .red)
                    }
                }
                
                // Notification Settings
                Section("Notifications") {
                    Toggle("Enable Notifications", isOn: $enableNotifications)
                    
                    if enableNotifications {
                        Picker("Notification Sound", selection: $notificationSound) {
                            Text("Default").tag("default")
                            Text("Gentle").tag("gentle")
                            Text("Prominent").tag("prominent")
                            Text("Silent").tag("silent")
                        }
                    }
                }
                
                // Security Settings
                Section("Security") {
                    HStack {
                        Image(systemName: useExternal && duckdnsDomain.contains("duckdns.org") ? "lock.shield.fill" : "lock.shield")
                            .foregroundColor(useExternal && duckdnsDomain.contains("duckdns.org") ? .green : .orange)
                        
                        VStack(alignment: .leading) {
                            Text("Connection Security")
                                .font(.headline)
                            Text(securityDescription)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // App Information
                Section("Information") {
                    HStack {
                        Text("App Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Connection Type")
                        Spacer()
                        Text(useExternal ? "External (Remote)" : "Local (Wi-Fi)")
                            .foregroundColor(.secondary)
                    }
                    
                    Button("View Setup Guide") {
                        if let url = URL(string: "https://github.com/PatrickChrist/garage-door-controller/blob/main/REMOTE_ACCESS.md") {
                            UIApplication.shared.open(url)
                        }
                    }
                }
                
                // Advanced Settings
                Section("Advanced") {
                    NavigationLink("Siri Shortcuts") {
                        SiriShortcutsView()
                    }
                    
                    NavigationLink("HomeKit Setup") {
                        HomeKitSetupView()
                    }
                    
                    Button("Reset to Defaults") {
                        resetToDefaults()
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
        }
    }
    
    private var securityDescription: String {
        if useExternal && duckdnsDomain.contains("duckdns.org") {
            return "Secure HTTPS connection with SSL encryption"
        } else if useExternal {
            return "External connection - ensure HTTPS is configured"
        } else {
            return "Local network connection"
        }
    }
    
    private func testConnection() {
        isTestingConnection = true
        showingConnectionTest = false
        
        Task {
            do {
                let scheme = (useExternal && duckdnsDomain.contains("duckdns.org")) ? "https" : "http"
                let testURL = "\(scheme)://\(effectiveURL)/api/status"
                
                guard let url = URL(string: testURL) else {
                    await MainActor.run {
                        connectionTestResult = "Error: Invalid URL"
                        showingConnectionTest = true
                        isTestingConnection = false
                    }
                    return
                }
                
                let (data, response) = try await URLSession.shared.data(from: url)
                
                await MainActor.run {
                    if let httpResponse = response as? HTTPURLResponse {
                        if httpResponse.statusCode == 200 {
                            connectionTestResult = "✅ Success: Connection established"
                        } else {
                            connectionTestResult = "❌ Error: HTTP \(httpResponse.statusCode)"
                        }
                    } else {
                        connectionTestResult = "❌ Error: Invalid response"
                    }
                    showingConnectionTest = true
                    isTestingConnection = false
                }
                
            } catch {
                await MainActor.run {
                    connectionTestResult = "❌ Error: \(error.localizedDescription)"
                    showingConnectionTest = true
                    isTestingConnection = false
                }
            }
        }
    }
    
    private func resetToDefaults() {
        baseURL = "192.168.1.100:8000"
        useExternal = false
        duckdnsDomain = ""
        enableNotifications = true
        notificationSound = "default"
        connectionTestResult = ""
        showingConnectionTest = false
    }
}

struct SiriShortcutsView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "mic.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.blue)
            
            Text("Siri Shortcuts")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Control your garage doors with voice commands")
                .font(.headline)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Available Commands:")
                    .font(.headline)
                
                CommandRow(command: "Hey Siri, open garage door", description: "Opens garage door 1")
                CommandRow(command: "Hey Siri, trigger door 2", description: "Triggers garage door 2")
                CommandRow(command: "Hey Siri, check garage status", description: "Reports door status")
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            Button("Open Shortcuts App") {
                if let url = URL(string: "shortcuts://") {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
            
            Spacer()
        }
        .padding()
        .navigationTitle("Siri Shortcuts")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct HomeKitSetupView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "homekit")
                .font(.system(size: 80))
                .foregroundColor(.orange)
            
            Text("HomeKit Setup")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Add your garage doors to the Apple Home app")
                .font(.headline)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 16) {
                SetupStep(number: 1, title: "Enable HomeKit Bridge", description: "Ensure the HomeKit bridge is running on your Raspberry Pi")
                SetupStep(number: 2, title: "Open Home App", description: "Launch the Apple Home app on your iPhone or iPad")
                SetupStep(number: 3, title: "Add Accessory", description: "Tap '+' then 'Add Accessory' and scan the QR code")
                SetupStep(number: 4, title: "Setup Code", description: "Use code: 123-45-678 (change in production)")
            }
            
            Button("Open Home App") {
                if let url = URL(string: "com.apple.Home://") {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
            
            Spacer()
        }
        .padding()
        .navigationTitle("HomeKit Setup")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct CommandRow: View {
    let command: String
    let description: String
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(command)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Image(systemName: "mic.fill")
                .foregroundColor(.blue)
        }
    }
}

struct SetupStep: View {
    let number: Int
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top) {
            Text("\(number)")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(Color.blue)
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

#Preview {
    SettingsView()
}