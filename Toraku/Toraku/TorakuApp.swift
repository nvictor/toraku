//
//  TorakuApp.swift
//  Toraku
//
//  Created by Victor Noagbodji on 4/26/26.
//

import SwiftUI

@main
struct TorakuApp: App {
    @StateObject private var updater = AppUpdater()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .defaultSize(width: 1280, height: 720)
        .commands {
            CheckForUpdatesCommands(updater: updater)
        }
    }
}
