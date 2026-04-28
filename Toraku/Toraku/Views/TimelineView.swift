import SwiftUI

struct TimelineView: View {
    @ObservedObject var model: TrackTimerViewModel

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(model.timeline.enumerated()), id: \.element.id) { index, scheduledSegment in
                        TimelineRow(
                            scheduledSegment: scheduledSegment,
                            eventStartDate: model.eventStartDate,
                            state: rowState(for: index)
                        )
                        .id(scheduledSegment.id)
                    }
                }
                .padding(.vertical, 6)
            }
            .scrollIndicators(.hidden)
            .onChange(of: model.currentSegment?.id) { _, id in
                guard let id else {
                    return
                }

                withAnimation(.smooth(duration: 0.25)) {
                    proxy.scrollTo(id, anchor: .center)
                }
            }
        }
    }

    private func rowState(for index: Int) -> TimelineRow.State {
        switch model.eventPhase {
        case .noSchedule, .beforeStart:
            return .upcoming
        case .ended:
            return .past
        case .running:
            break
        }

        guard let currentIndex = model.currentIndex else {
            return .upcoming
        }

        if index < currentIndex {
            return .past
        }

        if index == currentIndex {
            return .current
        }

        return .upcoming
    }
}

private struct TimelineRow: View {
    enum State {
        case past
        case current
        case upcoming
    }

    let scheduledSegment: ScheduledSegment
    let eventStartDate: Date
    let state: State

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: markerImage)
                .font(.system(size: state == .current ? 15 : 11, weight: .semibold))
                .foregroundStyle(markerColor)
                .frame(width: 18, height: 20)

            VStack(alignment: .leading, spacing: 4) {
                Text(scheduledSegment.segment.title)
                    .font(titleFont)
                    .lineLimit(state == .current ? 2 : 1)
                    .minimumScaleFactor(0.8)

                HStack(spacing: 6) {
                    Image(systemName: scheduledSegment.segment.type.systemImage)
                        .foregroundStyle(scheduledSegment.segment.type.tint)

                    Text(DurationFormatting.timeRange(
                        startDate: eventStartDate,
                        startOffset: scheduledSegment.startOffset,
                        endOffset: scheduledSegment.endOffset
                    ))
                    .monospacedDigit()

                    Text(DurationFormatting.minutes(scheduledSegment.duration))
                        .monospacedDigit()
                }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                if let speaker = scheduledSegment.segment.speaker, !speaker.isEmpty {
                    Text(speaker)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            .padding(.vertical, state == .current ? 8 : 6)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 6)
        .opacity(opacity)
        .animation(.smooth(duration: 0.2), value: state)
    }

    private var titleFont: Font {
        switch state {
        case .current:
            .headline.weight(.semibold)
        case .past, .upcoming:
            .subheadline
        }
    }

    private var opacity: Double {
        switch state {
        case .current:
            1
        case .past:
            0.34
        case .upcoming:
            0.48
        }
    }

    private var markerImage: String {
        switch state {
        case .past:
            "checkmark.circle.fill"
        case .current:
            "play.circle.fill"
        case .upcoming:
            "circle"
        }
    }

    private var markerColor: Color {
        switch state {
        case .past:
            .secondary
        case .current:
            scheduledSegment.segment.type.tint
        case .upcoming:
            .secondary
        }
    }
}
