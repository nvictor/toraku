import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var model = TrackTimerViewModel()
    @State private var isSettingsPresented = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                Spacer(minLength: 8)

                SegmentContextHeader(model: model)

                CurrentSegmentView(model: model)

                ControlsView(model: model)

                progressFooter

                Spacer(minLength: 8)
            }
            .frame(maxWidth: 420, maxHeight: .infinity)
            .padding(.horizontal, 24)
            .padding(.vertical, 18)
            .navigationTitle("Toraku")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isSettingsPresented.toggle()
                    } label: {
                        Label("Settings", systemImage: "slider.horizontal.3")
                    }
                    .help("Settings")
                    .popover(isPresented: $isSettingsPresented, arrowEdge: .bottom) {
                        settingsPopover
                    }
                }
            }
        }
        .frame(minWidth: 360, idealWidth: 420, minHeight: 560, idealHeight: 720)
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
        .fileImporter(
            isPresented: $model.isChoosingMusicFolder,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else {
                    return
                }
                model.grantMusicFolderAccess(from: url)
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

    private var settingsPopover: some View {
        Form {
            Section("Schedule") {
                LabeledContent("Segments") {
                    Text("\(model.timeline.count)")
                        .monospacedDigit()
                }

                LabeledContent("Duration") {
                    Text(DurationFormatting.clock(model.totalDuration))
                        .monospacedDigit()
                }

                Button {
                    model.isImporting = true
                } label: {
                    Label("Load Schedule", systemImage: "square.and.arrow.down")
                }

                Button {
                    model.isChoosingMusicFolder = true
                } label: {
                    Label("Grant Music Folder Access", systemImage: "folder.badge.gearshape")
                }
            }

            Section("Start") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Start Time")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    DatePicker(
                        "Start Time",
                        selection: $model.eventStartDate,
                        displayedComponents: [.hourAndMinute]
                    )
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .fixedSize()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .formStyle(.grouped)
        .frame(width: 320)
        .padding(.vertical, 8)
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
}

private struct SegmentContextHeader: View {
    @ObservedObject var model: TrackTimerViewModel

    var body: some View {
        Group {
            if !model.timeline.isEmpty {
                VStack(spacing: 4) {
                    contextRow(previousSegment, role: .previous)
                    contextRow(focusedSegment, role: .current)
                    contextRow(nextSegment, role: .next)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .animation(.smooth(duration: 0.2), value: focusedSegment?.id)
    }

    @ViewBuilder
    private func contextRow(_ segment: ScheduledSegment?, role: SegmentContextRole) -> some View {
        if let segment {
            HStack(spacing: 8) {
                Image(systemName: segment.segment.type.systemImage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(role == .current ? segment.segment.type.tint : .secondary)
                    .frame(width: 16)

                Text(segment.segment.title)
                    .font(role.titleFont)
                    .lineLimit(role == .current ? 2 : 1)
                    .minimumScaleFactor(0.75)

                Spacer(minLength: 6)

                Text(DurationFormatting.minutes(segment.duration))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, role == .current ? 8 : 5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .opacity(role.opacity)
        } else {
            Color.clear
                .frame(height: role.placeholderHeight)
        }
    }

    private var previousSegment: ScheduledSegment? {
        guard let focusedIndex, focusedIndex > model.timeline.startIndex else {
            return nil
        }

        return model.timeline[model.timeline.index(before: focusedIndex)]
    }

    private var focusedSegment: ScheduledSegment? {
        model.currentSegment
    }

    private var nextSegment: ScheduledSegment? {
        guard let focusedIndex else {
            return model.timeline.first
        }

        let nextIndex = model.timeline.index(after: focusedIndex)
        guard model.timeline.indices.contains(nextIndex) else {
            return nil
        }

        return model.timeline[nextIndex]
    }

    private var focusedIndex: Int? {
        guard let focusedSegment else {
            return nil
        }

        return model.timeline.firstIndex(where: { $0.id == focusedSegment.id })
    }
}

private enum SegmentContextRole {
    case previous
    case current
    case next

    var titleFont: Font {
        switch self {
        case .current:
            .subheadline.weight(.semibold)
        case .previous, .next:
            .caption
        }
    }

    var opacity: Double {
        switch self {
        case .current:
            1
        case .previous, .next:
            0.45
        }
    }

    var placeholderHeight: CGFloat {
        switch self {
        case .current:
            34
        case .previous, .next:
            26
        }
    }
}
