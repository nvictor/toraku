import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var model = TrackTimerViewModel()
    @State private var isInspectorPresented = false

    var body: some View {
        NavigationSplitView {
            TimelineView(model: model)
                .padding(.leading, 28)
                .padding(.trailing, 22)
                .padding(.vertical, 10)
                .navigationTitle("Timeline")
                .navigationSplitViewColumnWidth(min: 320, ideal: 380, max: 440)
        } detail: {
            VStack(spacing: 24) {
                Spacer(minLength: 12)

                CurrentSegmentView(model: model)
                    .frame(maxWidth: 720)

                ControlsView(model: model)

                progressFooter

                Spacer(minLength: 12)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 40)
            .navigationTitle("Toraku")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isInspectorPresented.toggle()
                    } label: {
                        Label("Settings", systemImage: "slider.horizontal.3")
                    }
                    .help(isInspectorPresented ? "Hide inspector" : "Show inspector")
                }
            }
            .inspector(isPresented: $isInspectorPresented) {
                inspector
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

    private var inspector: some View {
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
        .padding(.vertical, 10)
        .inspectorColumnWidth(min: 320, ideal: 340, max: 420)
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
