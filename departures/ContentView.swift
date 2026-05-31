import SwiftUI

struct ContentView: View {
    @State private var viewModel = DeparturesViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isBootstrapping {
                    ProgressView("Loading")
                } else if !viewModel.hasToken {
                    TokenSetupView(viewModel: viewModel)
                } else if viewModel.connection == nil {
                    ConnectionSetupView(viewModel: viewModel)
                } else {
                    DepartureDashboardView(viewModel: viewModel)
                }
            }
        }
        .task {
            await viewModel.bootstrap()
        }
        .alert("Problem", isPresented: errorBinding) {
            Button("OK", role: .cancel) {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding {
            viewModel.errorMessage != nil
        } set: { isPresented in
            if !isPresented {
                viewModel.errorMessage = nil
            }
        }
    }
}

#Preview {
    ContentView()
}
