// BloomWidgetBundle.swift — home-screen garden widget + focus Live Activity.
import WidgetKit
import SwiftUI

@main
struct BloomWidgetBundle: WidgetBundle {
    var body: some Widget {
        GardenWidget()
        FocusLiveActivity()
    }
}

// Placeholder widget — replaced by the real garden snapshot widget.
struct GardenEntry: TimelineEntry { let date: Date }

struct GardenProvider: TimelineProvider {
    func placeholder(in context: Context) -> GardenEntry { GardenEntry(date: .now) }
    func getSnapshot(in context: Context, completion: @escaping (GardenEntry) -> Void) {
        completion(GardenEntry(date: .now))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<GardenEntry>) -> Void) {
        completion(Timeline(entries: [GardenEntry(date: .now)], policy: .after(.now.addingTimeInterval(3600))))
    }
}

struct GardenWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "BloomGarden", provider: GardenProvider()) { _ in
            Text("🌼")
                .containerBackground(Color("WidgetBackground"), for: .widget)
        }
        .configurationDisplayName("Garden")
        .description("Your streak and today's growth.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct FocusLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FocusActivityAttributes.self) { context in
            HStack {
                Text(context.attributes.skillName)
                Spacer()
                Text(timerInterval: context.state.startedAt...context.state.endsAt, countsDown: true)
                    .monospacedDigit()
            }
            .padding()
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.skillName)
                }
            } compactLeading: {
                Text("🌱")
            } compactTrailing: {
                Text(timerInterval: context.state.startedAt...context.state.endsAt, countsDown: true, showsHours: false)
                    .monospacedDigit()
                    .frame(maxWidth: 44)
            } minimal: {
                Text("🌱")
            }
        }
    }
}
