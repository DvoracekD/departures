import SwiftUI

struct ConnectionSetupView: View {
    @Bindable var viewModel: DeparturesViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if viewModel.isLoadingStations && viewModel.stations.isEmpty {
                    ProgressView("Loading stations")
                        .frame(maxWidth: .infinity, minHeight: 180)
                } else {
                    StationSearchPanel(
                        title: "From",
                        systemImage: "tram.fill",
                        searchText: $viewModel.originSearchText,
                        selectedStation: viewModel.selectedOrigin,
                        stations: viewModel.filteredStations(for: viewModel.originSearchText)
                    ) { station in
                        viewModel.selectOrigin(station)
                    }

                    StationSearchPanel(
                        title: "To",
                        systemImage: "mappin.and.ellipse",
                        searchText: $viewModel.destinationSearchText,
                        selectedStation: viewModel.selectedDestination,
                        stations: viewModel.filteredStations(for: viewModel.destinationSearchText)
                    ) { station in
                        viewModel.selectDestination(station)
                    }

                    Button {
                        Task { await viewModel.saveConnection() }
                    } label: {
                        if viewModel.isSavingConnection {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Label("Save Connection", systemImage: "checkmark.circle.fill")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!viewModel.canSaveConnection)
                }
            }
            .padding()
        }
        .navigationTitle("Connection")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await viewModel.loadStationsIfNeeded(forceRefresh: true) }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(viewModel.isLoadingStations)
            }

            ToolbarItem(placement: .cancellationAction) {
                Button("Token") {
                    viewModel.forgetToken()
                }
            }
        }
        .task {
            await viewModel.loadStationsIfNeeded()
        }
    }
}

private struct StationSearchPanel: View {
    let title: String
    let systemImage: String
    @Binding var searchText: String
    let selectedStation: StationSelection?
    let stations: [StationSelection]
    let onSelect: (StationSelection) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: systemImage)
                .font(.headline)

            TextField("Search station", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif

            if let selectedStation {
                SelectedStationView(station: selectedStation)
            }

            VStack(spacing: 0) {
                ForEach(stations) { station in
                    Button {
                        onSelect(station)
                    } label: {
                        StationRow(station: station, isSelected: station == selectedStation)
                    }
                    .buttonStyle(.plain)

                    if station.id != stations.last?.id {
                        Divider()
                    }
                }
            }
            .background(.background, in: RoundedRectangle(cornerRadius: 8))
        }
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct SelectedStationView: View {
    let station: StationSelection

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text(station.name)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct StationRow: View {
    let station: StationSelection
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(station.name)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(station.displayDetail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            if isSelected {
                Image(systemName: "checkmark")
                    .font(.headline)
                    .foregroundStyle(.tint)
            }
        }
        .contentShape(Rectangle())
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
    }
}

#Preview {
    NavigationStack {
        ConnectionSetupView(viewModel: DeparturesViewModel())
    }
}
