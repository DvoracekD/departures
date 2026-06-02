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
                .tabViewStyle(.page)
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
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.circle)
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

#if DEBUG
private enum PreviewData {
    static func station(id: String, name: String, distance: Double) -> NearbyStation {
        NearbyStation(
            station: Station(
                id: id,
                name: name,
                stopIds: ["\(id)Z1", "\(id)Z2"],
                platformCodes: ["A", "B"],
                zoneIds: ["P"],
                latitude: 50.08,
                longitude: 14.43
            ),
            distanceMeters: distance
        )
    }

    static func departure(route: String, head: String, inMinutes: Int, delay: Int?, platform: String?) -> WatchDeparture {
        let predicted = Date().addingTimeInterval(TimeInterval(inMinutes * 60))
        return WatchDeparture(
            id: "\(route)-\(head)-\(inMinutes)",
            routeName: route,
            terminalName: head,
            scheduledDeparture: predicted.addingTimeInterval(TimeInterval(-(delay ?? 0))),
            predictedDeparture: predicted,
            delaySeconds: delay,
            platformCode: platform,
            updatedAt: Date()
        )
    }

    static let stationA = station(id: "U123", name: "Anděl", distance: 120)
    static let stationB = station(id: "U456", name: "Náměstí Míru", distance: 540)

    static var board: StationDepartureBoard {
        var board = StationDepartureBoard(station: stationA)
        board.departures = [
            departure(route: "5", head: "Olšanské hřbitovy", inMinutes: 2, delay: 30, platform: "A"),
            departure(route: "12", head: "Sídliště Barrandov", inMinutes: 6, delay: nil, platform: "B"),
            departure(route: "B", head: "Černý Most", inMinutes: 9, delay: -60, platform: nil),
        ]
        board.lastUpdatedAt = Date()
        return board
    }
}

@MainActor
private func previewViewModel(populated: Bool = true, refreshing: Bool = false) -> WatchDeparturesViewModel {
    let viewModel = WatchDeparturesViewModel()
    guard populated else { return viewModel }

    viewModel.nearbyStations = [PreviewData.stationA, PreviewData.stationB]
    viewModel.selectedStationID = PreviewData.stationA.id

    var board = PreviewData.board
    board.isRefreshing = refreshing
    viewModel.boards = [
        PreviewData.stationA.id: board,
        PreviewData.stationB.id: StationDepartureBoard(station: PreviewData.stationB),
    ]
    return viewModel
}

#Preview("Populated") {
    NearbyDeparturesView(viewModel: previewViewModel())
}

#Preview("Refreshing") {
    NearbyDeparturesView(viewModel: previewViewModel(refreshing: true))
}

#Preview("Empty / No Stops") {
    NearbyDeparturesView(viewModel: previewViewModel(populated: false))
}

#Preview("Station Page") {
    StationDeparturePage(
        station: PreviewData.stationA,
        board: PreviewData.board,
        refreshAction: {}
    )
}

#Preview("Departure Row") {
    DepartureRow(departure: PreviewData.departure(
        route: "5", head: "Olšanské hřbitovy", inMinutes: 2, delay: 30, platform: "A"
    ))
}
#endif
