import SwiftUI

struct NearbyDeparturesView: View {
    @Bindable var viewModel: WatchDeparturesViewModel

    var body: some View {
        Group {
            if viewModel.nearbyStations.isEmpty {
                LoadingOrEmptyStationsView(viewModel: viewModel)
            } else {
                TabView(selection: $viewModel.selectedStationID) {
                    ForEach(viewModel.nearbyStations) { station in
                        StationDeparturePage(
                            station: station,
                            board: viewModel.boards[station.id],
                            refreshAction: {
                                await viewModel.refreshDepartures(for: station, showErrorsAsAlert: true)
                            }
                        )
                        .tag(station.id)
                    }
                }
                .tabViewStyle(.carousel)
                .onChange(of: viewModel.selectedStationID) {
                    viewModel.selectedStationDidChange()
                }
            }
        }
    }
}

private struct LoadingOrEmptyStationsView: View {
    @Bindable var viewModel: WatchDeparturesViewModel

    var body: some View {
        VStack(spacing: 12) {
            if viewModel.isLocating || viewModel.isLoadingStations {
                ProgressView()
                Text(viewModel.isLocating ? "Locating" : "Loading stops")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Image(systemName: "location.slash")
                    .font(.title2)
                    .foregroundStyle(.secondary)

                Text("No Stops")
                    .font(.headline)

                Button {
                    Task { await viewModel.reloadNearbyStations() }
                } label: {
                    Label("Retry", systemImage: "location.fill")
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

private struct StationDeparturePage: View {
    let station: NearbyStation
    let board: StationDepartureBoard?
    let refreshAction: () async -> Void

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 10) {
                header

                if let board, board.isRefreshing && board.departures.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 64)
                } else if let board, !board.departures.isEmpty {
                    VStack(spacing: 7) {
                        ForEach(board.departures) { departure in
                            DepartureRow(departure: departure)
                        }
                    }
                } else {
                    EmptyDeparturesView()
                }

                if let errorMessage = board?.errorMessage {
                    Text(errorMessage)
                        .font(.caption2)
                        .foregroundStyle(.red)
                        .lineLimit(2)
                } else if let lastUpdatedAt = board?.lastUpdatedAt {
                    Text("Updated \(DepartureFormatting.updatedTime.string(from: lastUpdatedAt))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 2)
            .padding(.bottom, 8)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: 6) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(station.station.name)
                        .font(.headline)
                        .lineLimit(2)
                        .minimumScaleFactor(0.75)

                    Text(DepartureFormatting.distanceText(meters: station.distanceMeters))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 4)

                Button {
                    Task { await refreshAction() }
                } label: {
                    Image(systemName: board?.isRefreshing == true ? "hourglass" : "arrow.clockwise")
                        .font(.headline)
                }
                .buttonStyle(.bordered)
                .disabled(board?.isRefreshing == true)
                .controlSize(.mini)
            }
        }
    }
}

private struct DepartureRow: View {
    let departure: WatchDeparture

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(departure.routeName)
                .font(.headline.weight(.bold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(width: 38, alignment: .leading)

            VStack(alignment: .leading, spacing: 3) {
                Text(departure.terminalName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                HStack(spacing: 6) {
                    Text(DepartureFormatting.minutesUntilDeparture(departure.predictedDeparture))
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()

                    Text(DepartureFormatting.delayText(seconds: departure.delaySeconds))
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(delayColor)
                        .lineLimit(1)

                    if let platformCode = departure.platformCode, !platformCode.isEmpty {
                        Text(platformCode)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 7)
        .padding(.horizontal, 8)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.thinMaterial)
        }
    }

    private var delayColor: Color {
        guard let delaySeconds = departure.delaySeconds else { return .secondary }
        if delaySeconds > 60 { return .red }
        if delaySeconds < 0 { return .blue }
        return .green
    }
}

private struct EmptyDeparturesView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "clock")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("No Departures")
                .font(.subheadline.weight(.semibold))
        }
        .frame(maxWidth: .infinity, minHeight: 72)
    }
}

#Preview {
    NearbyDeparturesView(viewModel: WatchDeparturesViewModel())
}
