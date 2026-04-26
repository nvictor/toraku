import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var model = TrackTimerViewModel()

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                header

                Divider()

                HStack(spacing: 0) {
                    TimelineView(model: model)
                        .frame(width: timelineWidth(for: geometry.size.width))
                        .padding(.leading, 28)
                        .padding(.trailing, 22)
                        .padding(.vertical, 10)
                        .clipped()

                    Divider()

                    VStack(spacing: 24) {
                        Spacer(minLength: 12)

                        CurrentSegmentView(model: model)
                            .frame(maxWidth: 720)

                        ControlsView(model: model)

                        progressFooter

                        Spacer(minLength: 12)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, detailHorizontalPadding(for: geometry.size.width))
                }
            }
        }
        .frame(minWidth: 1024, minHeight: 576)
        .background(WindowConfigurator())
        .fileImporter(
            isPresented: $model.isImporting,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else {
                    return
                }
                model.importSchedule(from: url)
            case .failure(let error):
                model.showError(error.localizedDescription)
            }
        }
        .alert(
            "Schedule Error",
            isPresented: Binding(
                get: { model.scheduleError != nil },
                set: { isPresented in
                    if !isPresented {
                        model.clearError()
                    }
                }
            )
        ) {
            Button("OK") {
                model.clearError()
            }
        } message: {
            Text(model.scheduleError ?? "Unknown error")
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: "rectangle.stack.badge.play")
                .font(.title2)
                .foregroundStyle(.tint)

            VStack(alignment: .leading, spacing: 2) {
                Text("Toraku")
                    .font(.headline)
                Text("\(model.timeline.count) segments - \(DurationFormatting.clock(model.totalDuration))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            DatePicker(
                "Event Start",
                selection: $model.eventStartDate,
                displayedComponents: [.hourAndMinute]
            )
            .labelsHidden()
            .datePickerStyle(.compact)
            .frame(width: 120)

            Button {
                model.isImporting = true
            } label: {
                Label("Load Schedule", systemImage: "square.and.arrow.down")
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
    }

    private var progressFooter: some View {
        VStack(spacing: 8) {
            ProgressView(value: model.progress)
                .controlSize(.large)

            HStack {
                Text("Elapsed \(DurationFormatting.clock(model.clampedElapsed))")
                Spacer()
                Text("Remaining \(DurationFormatting.clock(model.totalRemaining))")
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: 640)
    }

    private func timelineWidth(for windowWidth: CGFloat) -> CGFloat {
        min(max(windowWidth * 0.34, 320), 440)
    }

    private func detailHorizontalPadding(for windowWidth: CGFloat) -> CGFloat {
        windowWidth < 1120 ? 24 : 40
    }
}
