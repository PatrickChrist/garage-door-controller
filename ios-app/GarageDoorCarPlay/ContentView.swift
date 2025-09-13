import SwiftUI
import CarPlay

struct ContentView: View {
    @StateObject private var garageController = GarageController()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Text("🏠 Garage Door Controller")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.top)
                
                VStack(spacing: 20) {
                    DoorControlView(
                        doorNumber: 1,
                        status: garageController.door1Status,
                        isLoading: garageController.isLoading
                    ) {
                        Task {
                            await garageController.triggerDoor(1)
                        }
                    }
                    
                    DoorControlView(
                        doorNumber: 2,
                        status: garageController.door2Status,
                        isLoading: garageController.isLoading
                    ) {
                        Task {
                            await garageController.triggerDoor(2)
                        }
                    }
                }
                
                Spacer()
                
                HStack {
                    Circle()
                        .fill(garageController.isConnected ? Color.green : Color.red)
                        .frame(width: 12, height: 12)
                    
                    Text(garageController.isConnected ? "Connected" : "Disconnected")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.bottom)
            }
            .padding()
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .navigationBarTitleDisplayMode(.large)
            .navigationTitle("Garage Control")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: SettingsView()) {
                        Image(systemName: "gear")
                            .foregroundColor(.primary)
                    }
                }
            }
        }
        .onAppear {
            garageController.connect()
        }
    }
}

struct DoorControlView: View {
    let doorNumber: Int
    let status: DoorStatus
    let isLoading: Bool
    let onTrigger: () -> Void
    
    var statusColor: Color {
        switch status {
        case .open:
            return .red
        case .closed:
            return .green
        case .opening, .closing:
            return .orange
        case .unknown:
            return .gray
        }
    }
    
    var statusText: String {
        switch status {
        case .open:
            return "Open"
        case .closed:
            return "Closed"
        case .opening:
            return "Opening..."
        case .closing:
            return "Closing..."
        case .unknown:
            return "Unknown"
        }
    }
    
    var body: some View {
        VStack(spacing: 15) {
            HStack {
                Text("Door \(doorNumber)")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text(statusText)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(statusColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(statusColor.opacity(0.15))
                    .cornerRadius(8)
            }
            
            Button(action: onTrigger) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    }
                    
                    Text("Toggle Door")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.blue, Color.purple]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .disabled(isLoading || status == .opening || status == .closing)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

#Preview {
    ContentView()
}