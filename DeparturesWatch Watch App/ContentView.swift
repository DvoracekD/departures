//
//  ContentView.swift
//  DeparturesWatch Watch App
//
//  Created by Dominik Dvoracek on 01.06.2026.
//

import SwiftUI

struct ContentView: View {
    @State private var viewModel = WatchDeparturesViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isBootstrapping {
                    ProgressView("Loading")
                } else if !viewModel.hasToken {
                    WatchTokenSetupView(viewModel: viewModel)
                } else {
                    NearbyDeparturesView(viewModel: viewModel)
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
