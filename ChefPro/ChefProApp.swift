//
//  ChefProApp.swift
//  ChefPro
//
//  Created by Аркадий on 14.05.2026.
//

import SwiftUI
import FirebaseCore
import FirebaseCrashlytics
import FirebaseFirestore

@main
struct ChefProApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var store = ChefProStore()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        FirebaseApp.configure()

        // Enable offline persistence with 100 MB cache
        let settings = FirestoreSettings()
        settings.cacheSettings = PersistentCacheSettings(sizeBytes: 100 * 1024 * 1024 as NSNumber)
        Firestore.firestore().settings = settings
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)
        UIApplication.shared.shortcutItems = [
            UIApplicationShortcutItem(
                type: "com.chefpro.kitchenboard",
                localizedTitle: "Kitchen Board",
                localizedSubtitle: "Активные заказы",
                icon: UIApplicationShortcutIcon(systemImageName: "rectangle.3.group.fill")
            ),
            UIApplicationShortcutItem(
                type: "com.chefpro.lowstock",
                localizedTitle: "Низкие остатки",
                localizedSubtitle: "Проверить склад",
                icon: UIApplicationShortcutIcon(systemImageName: "exclamationmark.triangle.fill")
            ),
            UIApplicationShortcutItem(
                type: "com.chefpro.addwriteoff",
                localizedTitle: "Добавить списание",
                localizedSubtitle: nil,
                icon: UIApplicationShortcutIcon(systemImageName: "trash.fill")
            ),
            UIApplicationShortcutItem(
                type: "com.chefpro.waiter",
                localizedTitle: "Режим официанта",
                localizedSubtitle: nil,
                icon: UIApplicationShortcutIcon(systemImageName: "person.wave.2.fill")
            )
        ]
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        store.syncOnForeground()
                    }
                }
        }
    }
}
