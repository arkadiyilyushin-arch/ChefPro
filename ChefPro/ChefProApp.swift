//
//  ChefProApp.swift
//  ChefPro
//
//  Created by Аркадий on 14.05.2026.
//

import SwiftUI
import FirebaseCore

@main
struct ChefProApp: App {
    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
