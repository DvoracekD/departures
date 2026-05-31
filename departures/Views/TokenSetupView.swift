import SwiftUI

struct TokenSetupView: View {
    @Bindable var viewModel: DeparturesViewModel

    var body: some View {
        Form {
            Section {
                SecureField("X-Access-Token", text: $viewModel.tokenDraft)
                    .textContentType(.password)
                    .autocorrectionDisabled()
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif

                Button {
                    Task { await viewModel.saveToken() }
                } label: {
                    if viewModel.isSavingToken {
                        ProgressView()
                    } else {
                        Label("Save Token", systemImage: "key.fill")
                    }
                }
                .disabled(viewModel.isSavingToken)
            } header: {
                Text("API Token")
            } footer: {
                Text("Generate a token at api.golemio.cz/api-keys and paste it here.")
            }
        }
        .navigationTitle("Departures")
    }
}

#Preview {
    NavigationStack {
        TokenSetupView(viewModel: DeparturesViewModel())
    }
}
