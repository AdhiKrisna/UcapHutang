import SwiftUI
import WidgetKit

private struct CatatCepatEntry: TimelineEntry {
    let date: Date
}

private struct CatatCepatProvider: TimelineProvider {
    func placeholder(in context: Context) -> CatatCepatEntry {
        CatatCepatEntry(date: .now)
    }

    func getSnapshot(in context: Context, completion: @escaping (CatatCepatEntry) -> Void) {
        completion(CatatCepatEntry(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CatatCepatEntry>) -> Void) {
        completion(Timeline(entries: [CatatCepatEntry(date: .now)], policy: .never))
    }
}

private struct CatatCepatWidgetView: View {
    var entry: CatatCepatProvider.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "mic.fill")
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 42, height: 42)
                .background(.blue.gradient)
                .clipShape(Circle())

            Spacer(minLength: 0)

            Text("Catat Cepat")
                .font(.headline.weight(.bold))
            Text("Utang, piutang, atau Split Bill")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .widgetURL(URL(string: "ucaphutang://catat"))
        .containerBackground(.background, for: .widget)
    }
}

struct CatatCepatWidget: Widget {
    let kind = "CatatCepatWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CatatCepatProvider()) { entry in
            CatatCepatWidgetView(entry: entry)
        }
        .configurationDisplayName("Catat Cepat")
        .description("Buka UcapHutang langsung ke pilihan pencatatan.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct UcapHutangWidgetBundle: WidgetBundle {
    var body: some Widget {
        CatatCepatWidget()
    }
}
