import SwiftUI

struct ContentView: View {
    @State private var token = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var didSync = false
    @State private var maxDistanceMeters = NearbyStationsPreferences.default.maxDistanceMeters
    @State private var maxStationCount = NearbyStationsPreferences.default.maxStationCount

    private let tokenStore = KeychainTokenStore()
    private let preferencesStore = PreferencesStore()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("X-Access-Token", text: $token)
                        .textContentType(.password)
                        .autocorrectionDisabled()
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif

                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Label("Save & Sync to Watch", systemImage: "key.fill")
                        }
                    }
                    .disabled(isSaving || trimmedToken.isEmpty)
                } header: {
                    Text("API Token")
                } footer: {
                    Text("Generate a token at api.golemio.cz/api-keys. It is stored on this iPhone and synced to your Apple Watch, which shows nearby departures.")
                }

                Section {
                    Stepper(value: $maxDistanceMeters, in: NearbyStationsPreferences.distanceRange, step: 250) {
                        LabeledContent("Search radius", value: distanceLabel)
                    }

                    Stepper(value: $maxStationCount, in: NearbyStationsPreferences.countRange) {
                        LabeledContent("Max stations", value: "\(maxStationCount)")
                    }
                } header: {
                    Text("Nearby Stations")
                } footer: {
                    Text("The watch lists stations within this radius, up to this many, closest first.")
                }

                if didSync {
                    Section {
                        Label("Token synced to Apple Watch.", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }
            }
            .navigationTitle("Departures")
        }
        .task {
            token = tokenStore.readToken() ?? ""
            let preferences = preferencesStore.read()
            maxDistanceMeters = preferences.maxDistanceMeters
            maxStationCount = preferences.maxStationCount
        }
        .onChange(of: token) {
            didSync = false
        }
        .onChange(of: maxDistanceMeters) {
            syncPreferences()
        }
        .onChange(of: maxStationCount) {
            syncPreferences()
        }
        .alert("Problem", isPresented: errorBinding) {
            Button("OK", role: .cancel) {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var trimmedToken: String {
        token.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var currentPreferences: NearbyStationsPreferences {
        NearbyStationsPreferences(maxDistanceMeters: maxDistanceMeters, maxStationCount: maxStationCount)
    }

    private var distanceLabel: String {
        if maxDistanceMeters >= 1000 {
            let km = maxDistanceMeters / 1000
            return km == km.rounded() ? "\(Int(km)) km" : String(format: "%.2f km", km)
        }
        return "\(Int(maxDistanceMeters)) m"
    }

    private func syncPreferences() {
        let preferences = currentPreferences
        preferencesStore.save(preferences)
        #if canImport(WatchConnectivity)
        WatchConnectivityService.shared.send(preferences: preferences)
        #endif
    }

    private func save() async {
        let token = trimmedToken
        guard !token.isEmpty else {
            errorMessage = "Enter a Golemio API token."
            return
        }

        isSaving = true
        defer { isSaving = false }

        do {
            try await GolemioClient(accessToken: token).validateToken()
            try tokenStore.saveToken(token)
            #if canImport(WatchConnectivity)
            WatchConnectivityService.shared.send(token: token)
            WatchConnectivityService.shared.send(preferences: currentPreferences)
            #endif
            didSync = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding {
            errorMessage != nil
        } set: { isPresented in
            if !isPresented {
                errorMessage = nil
            }
        }
    }
}

#Preview {
    ContentView()
}
