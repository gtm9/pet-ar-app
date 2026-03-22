// CatARApp.swift
// CatAR – entry point

import SwiftUI

@main
struct CatARApp: App {
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                HomeView()
            }
            .preferredColorScheme(.dark)
        }
    }
}
