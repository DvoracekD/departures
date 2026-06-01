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
                    WaitingForTokenView()
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

private struct WaitingForTokenView: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "iphone.and.arrow.forward")
                .font(.title2)
                .foregroundStyle(.secondary)

            Text("Set Up on iPhone")
                .font(.headline)
                .multilineTextAlignment(.center)

            Text("Open the Departures app on your iPhone and save your Golemio API token.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

#Preview {
    ContentView()
}
