//
//  DrivenApp.swift
//  Driven
//
//  Created by Raygorodsky on 24/04/2026.
//

import SwiftUI
import SwiftData

@main
struct DrivenApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Trip.self])
    }
}
