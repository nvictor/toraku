import SwiftUI

struct CurrentSegmentView: View {
    @ObservedObject var model: TrackTimerViewModel

    var body: some View {
        VStack(spacing: 16) {
            if let currentSegment = model.currentSegment {
                Label(currentSegment.segment.type.label.uppercased(), systemImage: currentSegment.segment.type.systemImage)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(currentSegment.segment.type.tint)
                    .labelStyle(.titleAndIcon)

                VStack(spacing: 6) {
                    Text(currentSegment.segment.title)
                        .font(.system(size: 36, weight: .semibold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.65)

                    if let speaker = currentSegment.segment.speaker, !speaker.isEmpty {
                        Text(speaker)
                            .font(.title3.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }

                Text(DurationFormatting.clock(model.remainingInCurrentSegment))
                    .font(.system(size: 88, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(timerColor)
                    .contentTransition(.numericText())
                    .accessibilityLabel(timerAccessibilityLabel)

                if let nextSegment = model.nextSegment {
                    Text("Up next: \(nextSegment.segment.title) - \(DurationFormatting.minutes(nextSegment.duration))")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                } else {
                    Text("Final segment")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
            } else {
                ContentUnavailableView(
                    "No Schedule",
                    systemImage: "calendar.badge.exclamationmark",
                    description: Text("Load a JSON schedule to start tracking.")
                )
            }
        }
        .frame(maxWidth: 760)
        .animation(.smooth(duration: 0.2), value: model.currentSegment?.id)
    }

    private var timerColor: Color {
        if model.isOvertime {
            return .red
        }

        if model.isWarning {
            return .orange
        }

        return .primary
    }

    private var timerAccessibilityLabel: String {
        if model.isOvertime {
            return "\(DurationFormatting.clock(model.remainingInCurrentSegment)) overtime"
        }

        return "\(DurationFormatting.clock(model.remainingInCurrentSegment)) remaining"
    }
}
