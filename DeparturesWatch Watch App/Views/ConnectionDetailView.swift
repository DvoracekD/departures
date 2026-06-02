import SwiftUI

/// Drill-in detail for a single departure. Shows everything the list row shows plus a
/// live, second-by-second countdown, and stays frontmost during always-on (like the
/// Workouts app) via an `ExtendedRuntimeSessionController`.
struct ConnectionDetailView: View {
    let initialDeparture: WatchDeparture
    @Bindable var viewModel: WatchDeparturesViewModel

    @State private var runtimeSession = ExtendedRuntimeSessionController()

    /// The latest data for this departure. Polling refreshes `boards`, and because the
    /// view model is `@Observable` those delay/predicted changes flow in here. The `id`
    /// (trip|stop|scheduledTimestamp) is stable across polls. Falls back to the snapshot
    /// we were pushed with once the departure ages out of the board (it only keeps 3).
    private var liveDeparture: WatchDeparture? {
        viewModel.boards.values
            .flatMap(\.departures)
            .first { $0.id == initialDeparture.id }
    }

    private var departure: WatchDeparture {
        liveDeparture ?? initialDeparture
    }

    /// The station this departure leaves from — the board that holds it.
    private var stationName: String? {
        viewModel.boards.values
            .first { board in board.departures.contains { $0.id == initialDeparture.id } }?
            .station.station.name
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                header
                CountdownView(target: departure.predictedDeparture, delaySeconds: departure.delaySeconds)
                Divider()
                details

                if liveDeparture == nil {
                    Text("No longer in the live board")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 2)
            .padding(.bottom, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle(departure.routeName)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { runtimeSession.start() }
        .onDisappear { runtimeSession.stop() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(departure.routeName)
                    .font(.title3.weight(.bold))
                    .monospacedDigit()

                Text(departure.terminalName)
                    .font(.headline)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
            }

            if let stationName {
                Label(stationName, systemImage: "mappin.and.ellipse")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 8) {
            detailRow(label: "Departs", value: DepartureFormatting.departureTime.string(from: departure.predictedDeparture))

            if departure.predictedDeparture != departure.scheduledDeparture {
                detailRow(label: "Scheduled", value: DepartureFormatting.departureTime.string(from: departure.scheduledDeparture))
            }

            if let platformCode = departure.platformCode, !platformCode.isEmpty {
                detailRow(label: "Platform", value: platformCode)
            }
        }
    }

    private func detailRow(label: String, value: String, valueColor: Color = .primary) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer(minLength: 6)
            Text(value)
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(valueColor)
                .lineLimit(1)
        }
    }
}

/// Live countdown to the departure. Ticks every second while the wrist is up; switches
/// to a coarse minutes display when dimmed in always-on, where the system only refreshes
/// the screen about once a minute (a ticking seconds value would otherwise look frozen).
private struct CountdownView: View {
    let target: Date
    let delaySeconds: Int?

    @Environment(\.isLuminanceReduced) private var isDimmed

    var body: some View {
        TimelineView(.periodic(from: .now, by: isDimmed ? 60 : 1)) { context in
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(DepartureFormatting.countdownText(to: target, now: context.date, showSeconds: !isDimmed))
                    .font(.system(.largeTitle, design: .rounded).monospacedDigit().weight(.semibold))

                Text(DepartureFormatting.delayText(seconds: delaySeconds))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(delayColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var delayColor: Color {
        guard let delaySeconds else { return .secondary }
        if delaySeconds > 60 { return .red }
        if delaySeconds < 0 { return .blue }
        return .green
    }
}

#if DEBUG
@MainActor
private func detailPreviewViewModel() -> WatchDeparturesViewModel {
    let station = NearbyStation(
        station: Station(
            id: "U123",
            name: "Anděl",
            stopIds: ["U123Z1"],
            platformCodes: ["A"],
            zoneIds: ["P"],
            latitude: 50.08,
            longitude: 14.43
        ),
        distanceMeters: 120
    )

    var board = StationDepartureBoard(station: station)
    board.departures = [previewDeparture]
    board.lastUpdatedAt = Date()

    let viewModel = WatchDeparturesViewModel()
    viewModel.nearbyStations = [station]
    viewModel.selectedStationID = station.id
    viewModel.boards = [station.id: board]
    return viewModel
}

private let previewDeparture: WatchDeparture = {
    let predicted = Date().addingTimeInterval(275)
    return WatchDeparture(
        id: "5-Olšanské-275",
        routeName: "5",
        terminalName: "Olšanské hřbitovy",
        scheduledDeparture: predicted.addingTimeInterval(-30),
        predictedDeparture: predicted,
        delaySeconds: 30,
        platformCode: "A",
        updatedAt: Date()
    )
}()

#Preview {
    NavigationStack {
        ConnectionDetailView(initialDeparture: previewDeparture, viewModel: detailPreviewViewModel())
    }
}
#endif
