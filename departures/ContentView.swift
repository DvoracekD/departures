import SwiftUI

struct ContentView: View {
    @State private var token = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var didSync = false

    private let tokenStore = KeychainTokenStore()

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
        }
        .onChange(of: token) {
            didSync = false
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
