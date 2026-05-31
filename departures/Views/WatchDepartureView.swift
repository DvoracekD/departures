import SwiftUI

struct WatchDepartureView: View {
    let snapshot: DepartureSnapshot?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let snapshot {
                Text(snapshot.originName)
                    .font(.headline)
                    .lineLimit(1)

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(snapshot.routeShortName)
                        .font(.title3.weight(.bold))
                        .monospacedDigit()
                    Text(DepartureFormatting.departureTime.string(from: snapshot.predictedDeparture))
                        .font(.title.weight(.semibold))
                        .monospacedDigit()
                        .minimumScaleFactor(0.7)
                }

                Text(DepartureFormatting.delayText(seconds: snapshot.delaySeconds))
                    .font(.headline)
                    .foregroundStyle(delayColor(for: snapshot.delaySeconds))
                    .lineLimit(1)
            } else {
                Text("No Departure")
                    .font(.headline)
                Text("Open iPhone app")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }

    private func delayColor(for seconds: Int?) -> Color {
        guard let seconds else { return .secondary }
        if seconds > 60 { return .red }
        if seconds < 0 { return .blue }
        return .green
    }
}

#Preview {
    WatchDepartureView(snapshot: DepartureSnapshot(
        originName: "Anděl",
        destinationName: "Muzeum",
        routeShortName: "B",
        scheduledDeparture: Date(),
        predictedDeparture: Date().addingTimeInterval(120),
        delaySeconds: 120,
        platformCode: "1",
        tripId: "preview",
        destinationStopName: "Muzeum",
        updatedAt: Date()
    ))
}
