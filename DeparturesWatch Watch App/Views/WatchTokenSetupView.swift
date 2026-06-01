import SwiftUI

struct WatchTokenSetupView: View {
    @Bindable var viewModel: WatchDeparturesViewModel

    var body: some View {
        Form {
            Section {
                SecureField("X-Access-Token", text: $viewModel.tokenDraft)
                    .textContentType(.password)
                    .autocorrectionDisabled()

                Button {
                    Task { await viewModel.saveToken() }
                } label: {
                    if viewModel.isSavingToken {
                        ProgressView()
                    } else {
                        Label("Save", systemImage: "key.fill")
                    }
                }
                .disabled(viewModel.isSavingToken)
            } header: {
                Text("Golemio")
            }
        }
        .navigationTitle("Departures")
    }
}

#Preview {
    NavigationStack {
        WatchTokenSetupView(viewModel: WatchDeparturesViewModel())
    }
}
