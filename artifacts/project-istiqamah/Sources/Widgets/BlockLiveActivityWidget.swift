import ActivityKit
import SwiftUI
import WidgetKit

struct BlockLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BlockActivityAttributes.self) { context in
            lockScreen(context)
                .activityBackgroundTint(Color(red: 0.06, green: 0.06, blue: 0.06))
                .activitySystemActionForegroundColor(.white)
                .widgetURL(context.attributes.deepLink)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    remainingTimer(context)
                        .padding(.leading, 6)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(context.isStale ? "BLOCK ENDED" : "RUNNING BLOCK")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.indigo.opacity(0.9))
                        Text(context.state.blockName)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    flame(size: 25)
                        .padding(.trailing, 8)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text(context.isStale ? "Finished your block?" : context.state.timeLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        if let deepLink = context.attributes.deepLink {
                            Link(context.isStale ? "Record complete" : "Open app", destination: deepLink)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.indigo)
                        }
                    }
                    .padding(.horizontal, 8)
                }
            } compactLeading: {
                flame(size: 16)
            } compactTrailing: {
                compactTimer(context)
            } minimal: {
                flame(size: 15)
            }
            .widgetURL(context.attributes.deepLink)
            .keylineTint(.orange)
        }
    }

    private func lockScreen(_ context: ActivityViewContext<BlockActivityAttributes>) -> some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text(context.isStale ? "BLOCK ENDED · TAP TO RECORD" : "BLOCK RUNNING")
                    .font(.caption2.bold())
                    .foregroundStyle(.indigo)
                Text(context.state.blockName)
                    .font(.headline)
                    .lineLimit(1)
                Text(context.state.timeLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 5) {
                countdown(context)
                    .font(.title3.monospacedDigit().weight(.semibold))
                Text(context.isStale ? "Tap to record" : "Tap to open")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
    }

    private func remainingTimer(_ context: ActivityViewContext<BlockActivityAttributes>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            countdown(context)
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
            Text(context.isStale ? "ENDED" : "REMAINING")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(.indigo)
        }
    }

    private func compactTimer(_ context: ActivityViewContext<BlockActivityAttributes>) -> some View {
        countdown(context)
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            .minimumScaleFactor(0.72)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background {
                Capsule()
                    .fill(Color.orange.opacity(0.16))
            }
            .overlay {
                Capsule()
                    .stroke(Color.orange.opacity(0.55), lineWidth: 0.7)
            }
            .shadow(color: .orange.opacity(0.4), radius: 3)
            .frame(maxWidth: 64)
            .accessibilityLabel("Time remaining")
    }

    @ViewBuilder
    private func countdown(_ context: ActivityViewContext<BlockActivityAttributes>) -> some View {
        if context.isStale {
            Text("00:00")
                .monospacedDigit()
                .lineLimit(1)
        } else {
            Text(context.state.endDate, style: .timer)
                .monospacedDigit()
                .lineLimit(1)
        }
    }

    private func flame(size: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            .yellow.opacity(0.5),
                            .orange.opacity(0.3),
                            .red.opacity(0.12),
                            .clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: size
                    )
                )
                .frame(width: size * 1.9, height: size * 1.9)
                .blur(radius: max(2, size * 0.12))

            Image(systemName: "flame.fill")
                .font(.system(size: size * 1.24, weight: .bold))
                .foregroundStyle(Color.orange.opacity(0.85))
                .blur(radius: max(2, size * 0.14))
                .symbolEffect(.pulse, options: .repeating.speed(0.55))

            Image(systemName: "flame.fill")
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.yellow, .orange, .red],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .shadow(color: .yellow.opacity(0.8), radius: 2)
                .shadow(color: .orange.opacity(0.85), radius: 6)
                .symbolEffect(.variableColor.iterative, options: .repeating.speed(0.62))

            Image(systemName: "flame.fill")
                .font(.system(size: size * 0.48, weight: .bold))
                .foregroundStyle(.yellow.opacity(0.95))
                .offset(y: size * 0.14)
                .blur(radius: 0.35)
        }
        .frame(width: size * 1.55, height: size * 1.55)
        .compositingGroup()
        .accessibilityElement(children: .ignore)
            .accessibilityLabel("Active focus block")
    }
}
