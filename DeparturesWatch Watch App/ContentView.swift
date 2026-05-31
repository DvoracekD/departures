//
//  ContentView.swift
//  DeparturesWatch Watch App
//
//  Created by Dominik Dvoracek on 01.06.2026.
//

import SwiftUI

struct ContentView: View {
    @State private var store = WatchConnectivityStore()

    var body: some View {
        WatchDepartureView(snapshot: store.snapshot)
    }
}

#Preview {
    ContentView()
}
