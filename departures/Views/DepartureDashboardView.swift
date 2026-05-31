import SwiftUI

struct DepartureDashboardView: View {
    @Bindable var viewModel: DeparturesViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let connection = viewModel.connection {
                    RouteHeader(configuration: connection)
                }

                if let snapshot = viewModel.snapshot {
                    DepartureSnapshotPanel(snapshot: snapshot)
                } else {
                    EmptyDeparturePanel()
                }

                if let statusMessage = viewModel.statusMessage {
                    Label(statusMessage, systemImage: "info.circle")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
        }
        .navigationTitle("Next Departure")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await viewModel.refreshDeparture(showErrorsAsAlert: true) }
                } label: {
                    if viewModel.isRefreshing {
                        ProgressView()
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .disabled(viewModel.isRefreshing)
            }

            ToolbarItem(placement: .cancellationAction) {
                Button("Edit") {
                    viewModel.editConnection()
                }
            }
        }
        .onAppear {
            viewModel.startPolling()
        }
    }
}

private struct RouteHeader: View {
    let configuration: ConnectionConfiguration

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            StationLine(title: "From", stationName: configuration.origin.name, systemImage: "location.fill")
            StationLine(title: "To", stationName: configuration.destination.name, systemImage: "flag.checkered")
        }
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct StationLine: View {
    let title: String
    let stationName: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .frame(width: 24)
                .foregroundStyle(.tint)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(stationName)
                    .font(.body.weight(.semibold))
                    .lineLimit(1)
            }
        }
    }
}

private struct DepartureSnapshotPanel: View {
    let snapshot: DepartureSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline) {
                Text(snapshot.routeShortName)
                    .font(.title2.weight(.bold))
                    .monospacedDigit()
                    .padding(.vertical, 5)
                    .padding(.horizontal, 10)
                    .background(.tint.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))

                Spacer(minLength: 8)

                Text(DepartureFormatting.minutesUntilDeparture(snapshot.predictedDeparture))
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
            }

            Text(DepartureFormatting.departureTime.string(from: snapshot.predictedDeparture))
                .font(.system(size: 64, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.65)
                .lineLimit(1)

            HStack(spacing: 10) {
                Label(DepartureFormatting.delayText(seconds: snapshot.delaySeconds), systemImage: "clock.badge.exclamationmark")
                    .foregroundStyle(delayColor)

                if let platformCode = snapshot.platformCode, !platformCode.isEmpty {
                    Label(platformCode, systemImage: "square.grid.3x1.folder.badge.plus")
                }
            }
            .font(.headline)

            VStack(alignment: .leading, spacing: 6) {
                Text("Scheduled \(DepartureFormatting.fullDepartureTime.string(from: snapshot.scheduledDeparture))")
                Text("Updated \(DepartureFormatting.updatedTime.string(from: snapshot.updatedAt))")
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private var delayColor: Color {
        guard let delaySeconds = snapshot.delaySeconds else { return .secondary }
        if delaySeconds > 60 { return .red }
        if delaySeconds < 0 { return .blue }
        return .green
    }
}

private struct EmptyDeparturePanel: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "clock")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("No upcoming direct connection")
                .font(.title3.weight(.semibold))
            Text("The app will keep checking for the next matching departure.")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    NavigationStack {
        DepartureDashboardView(viewModel: DeparturesViewModel())
    }
}
