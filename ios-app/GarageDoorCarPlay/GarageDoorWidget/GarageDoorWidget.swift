import WidgetKit
import SwiftUI
import Intents

struct Provider: IntentTimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), door1Status: "Closed", door2Status: "Open", configuration: ConfigurationIntent())
    }

    func getSnapshot(for configuration: ConfigurationIntent, in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date(), door1Status: "Closed", door2Status: "Open", configuration: configuration)
        completion(entry)
    }

    func getTimeline(for configuration: ConfigurationIntent, in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        Task {
            let entry = await fetchCurrentStatus(configuration: configuration)
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
        }
    }
    
    private func fetchCurrentStatus(configuration: ConfigurationIntent) async -> SimpleEntry {
        do {
            let baseURL = UserDefaults.standard.string(forKey: "garage_base_url") ?? "192.168.1.100:8000"
            guard let url = URL(string: "http://\(baseURL)/api/status") else {
                return SimpleEntry(date: Date(), door1Status: "Unknown", door2Status: "Unknown", configuration: configuration)
            }
            
            let (data, _) = try await URLSession.shared.data(from: url)
            
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: String] {
                let door1 = json["1"]?.capitalized ?? "Unknown"
                let door2 = json["2"]?.capitalized ?? "Unknown"
                return SimpleEntry(date: Date(), door1Status: door1, door2Status: door2, configuration: configuration)
            }
        } catch {
            print("Widget fetch error: \(error)")
        }
        
        return SimpleEntry(date: Date(), door1Status: "Unknown", door2Status: "Unknown", configuration: configuration)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let door1Status: String
    let door2Status: String
    let configuration: ConfigurationIntent
}

struct GarageDoorWidgetEntryView : View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var widgetFamily

    var body: some View {
        switch widgetFamily {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        case .systemLarge:
            LargeWidgetView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

struct SmallWidgetView: View {
    var entry: Provider.Entry
    
    var body: some View {
        VStack(spacing: 8) {
            Text("Garage")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 4) {
                HStack {
                    Text("1:")
                        .font(.caption)
                    Text(entry.door1Status)
                        .font(.caption)
                        .foregroundColor(statusColor(entry.door1Status))
                }
                
                HStack {
                    Text("2:")
                        .font(.caption)
                    Text(entry.door2Status)
                        .font(.caption)
                        .foregroundColor(statusColor(entry.door2Status))
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }
    
    private func statusColor(_ status: String) -> Color {
        switch status.lowercased() {
        case "open": return .red
        case "closed": return .green
        case "opening", "closing": return .orange
        default: return .gray
        }
    }
}

struct MediumWidgetView: View {
    var entry: Provider.Entry
    
    var body: some View {
        HStack(spacing: 20) {
            VStack {
                Text("🚪")
                    .font(.title)
                Text("Garage")
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                DoorStatusRow(doorNumber: "Door 1", status: entry.door1Status)
                DoorStatusRow(doorNumber: "Door 2", status: entry.door2Status)
                
                Text("Tap to open app")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
    }
}

struct LargeWidgetView: View {
    var entry: Provider.Entry
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("🚪")
                    .font(.largeTitle)
                VStack(alignment: .leading) {
                    Text("Garage Door Controller")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text("Last updated: \(entry.date, style: .time)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            
            VStack(spacing: 12) {
                DoorCard(title: "Door 1", status: entry.door1Status, doorNumber: 1)
                DoorCard(title: "Door 2", status: entry.door2Status, doorNumber: 2)
            }
            
            Text("Tap doors to trigger, or use Siri: 'Hey Siri, open garage door'")
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color(.systemBackground))
    }
}

struct DoorStatusRow: View {
    let doorNumber: String
    let status: String
    
    var body: some View {
        HStack {
            Text(doorNumber)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Text(status)
                .font(.subheadline)
                .foregroundColor(statusColor(status))
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(statusColor(status).opacity(0.2))
                .cornerRadius(4)
        }
    }
    
    private func statusColor(_ status: String) -> Color {
        switch status.lowercased() {
        case "open": return .red
        case "closed": return .green
        case "opening", "closing": return .orange
        default: return .gray
        }
    }
}

struct DoorCard: View {
    let title: String
    let status: String
    let doorNumber: Int
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(status)
                    .font(.subheadline)
                    .foregroundColor(statusColor(status))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(statusColor(status).opacity(0.2))
                    .cornerRadius(6)
            }
            
            Spacer()
            
            Button(intent: TriggerGarageDoorIntent()) {
                Image(systemName: "arrow.up.arrow.down.circle.fill")
                    .font(.title2)
                    .foregroundColor(.accentColor)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }
    
    private func statusColor(_ status: String) -> Color {
        switch status.lowercased() {
        case "open": return .red
        case "closed": return .green
        case "opening", "closing": return .orange
        default: return .gray
        }
    }
}

@main
struct GarageDoorWidget: Widget {
    let kind: String = "GarageDoorWidget"

    var body: some WidgetConfiguration {
        IntentConfiguration(kind: kind, intent: ConfigurationIntent.self, provider: Provider()) { entry in
            GarageDoorWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Garage Door Controller")
        .description("Monitor and control your garage doors.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}