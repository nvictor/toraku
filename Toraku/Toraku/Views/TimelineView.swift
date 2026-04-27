import SwiftUI

struct TimelineView: View {
    @ObservedObject var model: TrackTimerViewModel

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(model.timeline.enumerated()), id: \.element.id) { index, scheduledSegment in
                        TimelineRow(
                            scheduledSegment: scheduledSegment,
                            eventStartDate: model.eventStartDate,
                            state: rowState(for: index)
                        )
                        .id(scheduledSegment.id)
                    }
                }
                .padding(.vertical, 10)
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
        HStack(alignment: .top, spacing: 16) {
            VStack(spacing: 0) {
                Rectangle()
                    .fill(lineColor)
                    .frame(width: 2, height: 22)

                Image(systemName: markerImage)
                    .font(.system(size: state == .current ? 17 : 13, weight: .bold))
                    .foregroundStyle(markerColor)
                    .frame(width: 30, height: 30)

                Rectangle()
                    .fill(lineColor)
                    .frame(width: 2)
            }
            .frame(width: 34)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Label(scheduledSegment.segment.type.label, systemImage: scheduledSegment.segment.type.systemImage)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(scheduledSegment.segment.type.tint)
                        .labelStyle(.titleAndIcon)

                    Text(DurationFormatting.minutes(scheduledSegment.duration))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                Text(DurationFormatting.timeRange(
                    startDate: eventStartDate,
                    startOffset: scheduledSegment.startOffset,
                    endOffset: scheduledSegment.endOffset
                ))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)

                Text(scheduledSegment.segment.title)
                    .font(titleFont)
                    .lineLimit(state == .current ? 2 : 1)
                    .minimumScaleFactor(0.75)

                if let speaker = scheduledSegment.segment.speaker, !speaker.isEmpty {
                    Text(speaker)
                        .font(state == .current ? .headline : .subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.vertical, state == .current ? 18 : 12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .opacity(opacity)
        .scaleEffect(state == .current ? 1 : 0.96, anchor: .leading)
        .animation(.smooth(duration: 0.2), value: state)
    }

    private var titleFont: Font {
        switch state {
        case .current:
            .title2.weight(.semibold)
        case .past, .upcoming:
            .headline
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

    private var lineColor: Color {
        state == .current ? scheduledSegment.segment.type.tint.opacity(0.55) : Color.secondary.opacity(0.2)
    }
}
