import SwiftUI
import WatchConnectivity

struct ContentView: View {
    @StateObject private var connectivityManager = WatchConnectivityManager()
    @State private var door1Status: String = "Unknown"
    @State private var door2Status: String = "Unknown"
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 15) {
                // Door Status Cards
                VStack(spacing: 10) {
                    DoorCard(
                        title: "Door 1",
                        status: door1Status,
                        isLoading: isLoading
                    ) {
                        triggerDoor(1)
                    }
                    
                    DoorCard(
                        title: "Door 2", 
                        status: door2Status,
                        isLoading: isLoading
                    ) {
                        triggerDoor(2)
                    }
                }
                
                // Connection Status
                HStack {
                    Circle()
                        .fill(connectivityManager.isConnected ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    Text(connectivityManager.isConnected ? "Connected" : "Disconnected")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Garage")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onReceive(connectivityManager.$door1Status) { status in
            door1Status = status
        }
        .onReceive(connectivityManager.$door2Status) { status in
            door2Status = status
        }
        .onAppear {
            connectivityManager.requestStatus()
        }
    }
    
    private func triggerDoor(_ doorId: Int) {
        isLoading = true
        connectivityManager.triggerDoor(doorId) { success in
            DispatchQueue.main.async {
                isLoading = false
                if !success {
                    // Show error feedback
                    WKInterfaceDevice.current().play(.failure)
                } else {
                    // Haptic feedback for success
                    WKInterfaceDevice.current().play(.success)
                }
            }
        }
    }
}

struct DoorCard: View {
    let title: String
    let status: String
    let isLoading: Bool
    let action: () -> Void
    
    var statusColor: Color {
        switch status.lowercased() {
        case "open": return .red
        case "closed": return .green
        case "opening", "closing": return .orange
        default: return .gray
        }
    }
    
    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(status)
                .font(.caption)
                .foregroundColor(statusColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(statusColor.opacity(0.2))
                .cornerRadius(8)
            
            Button(action: action) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "arrow.up.arrow.down.circle")
                    }
                    Text("Toggle")
                        .font(.caption)
                }
            }
            .disabled(isLoading || status == "opening" || status == "closing")
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(statusColor, lineWidth: 1)
        )
    }
}

#Preview {
    ContentView()
}