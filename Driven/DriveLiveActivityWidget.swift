import SwiftUI
#if canImport(ActivityKit) && canImport(WidgetKit)
import ActivityKit
import WidgetKit

// Move this file into a Widget Extension target and
// register a WidgetBundle @main there to enable Dynamic Island UI.
struct DriveLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DriveActivityAttributes.self) { context in
            ZStack {
                Color.black
                HStack(spacing: 10) {
                    Image(systemName: "car.fill")
                        .foregroundStyle(.orange)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Driving")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white.opacity(0.7))
                        Text("\(context.state.duration) • \(context.state.distance)")
                            .font(.headline.weight(.black))
                            .foregroundStyle(.white)
                    }
                    Spacer()
                }
                .padding(.horizontal, 12)
            }
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "steeringwheel")
                        .foregroundStyle(.orange)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.duration)
                        .font(.headline.weight(.black))
                        .foregroundStyle(.white)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.distance)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                }
            } compactLeading: {
                Image(systemName: "car.fill")
                    .foregroundStyle(.orange)
            } compactTrailing: {
                Text(context.state.duration)
                    .foregroundStyle(.white)
            } minimal: {
                Image(systemName: "car.fill")
                    .foregroundStyle(.orange)
            }
        }
    }
}
#endif
