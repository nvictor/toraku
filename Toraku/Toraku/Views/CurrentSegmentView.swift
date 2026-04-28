import SwiftUI

struct CurrentSegmentView: View {
    @ObservedObject var model: TrackTimerViewModel

    var body: some View {
        VStack(spacing: 12) {
            switch model.eventPhase {
            case .noSchedule:
                emptyState
            case .beforeStart(let remaining):
                countdownState(remaining: remaining)
            case .running:
                runningState
            case .ended(let elapsed):
                endedState(elapsed: elapsed)
            }
        }
        .frame(maxWidth: .infinity)
        .animation(.smooth(duration: 0.2), value: model.currentSegment?.id)
    }

    private var runningState: some View {
        Group {
            if let currentSegment = model.currentSegment {
                Label(currentSegment.segment.type.label.uppercased(), systemImage: currentSegment.segment.type.systemImage)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(currentSegment.segment.type.tint)
                    .labelStyle(.titleAndIcon)

                VStack(spacing: 6) {
                    Text(currentSegment.segment.title)
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .minimumScaleFactor(0.7)

                    if let speaker = currentSegment.segment.speaker, !speaker.isEmpty {
                        Text(speaker)
                            .font(.headline.weight(.medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }

                Text(DurationFormatting.clock(model.remainingInCurrentSegment))
                    .font(.system(size: 76, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(timerColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                    .contentTransition(.numericText())
                    .accessibilityLabel(timerAccessibilityLabel)

                if let nextSegment = model.nextSegment {
                    Text("Up next: \(nextSegment.segment.title) - \(DurationFormatting.minutes(nextSegment.duration))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
            } else {
                emptyState
            }
        }
    }

    private func countdownState(remaining: TimeInterval) -> some View {
        VStack(spacing: 12) {
            Label("STARTING SOON", systemImage: "timer")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tint)
                .labelStyle(.titleAndIcon)

            Text(DurationFormatting.clock(remaining))
                .font(.system(size: 76, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.tint)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .contentTransition(.numericText())
                .accessibilityLabel("\(DurationFormatting.clock(remaining)) until event starts")

            if let firstSegment = model.timeline.first {
                Text("First: \(firstSegment.segment.title) - \(DurationFormatting.minutes(firstSegment.duration))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
        }
    }

    private func endedState(elapsed: TimeInterval) -> some View {
        VStack(spacing: 12) {
            Label("EVENT ENDED", systemImage: "checkmark.circle.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .labelStyle(.titleAndIcon)

            Text(DurationFormatting.clock(elapsed))
                .font(.system(size: 76, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .contentTransition(.numericText())
                .accessibilityLabel("\(DurationFormatting.clock(elapsed)) since event ended")

            Text("Total duration: \(DurationFormatting.clock(model.totalDuration))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "No Schedule",
            systemImage: "calendar.badge.exclamationmark",
            description: Text("Load a JSON schedule to start tracking.")
        )
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
