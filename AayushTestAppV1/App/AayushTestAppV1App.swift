//
//  AayushTestAppV1App.swift
//  AayushTestAppV1
//
//

import SwiftUI

/// Main application entry point for Aayush Agent.
///
/// **Purpose**: Initializes the SwiftUI app and sets up the root view hierarchy.
/// This is the top-level app structure that Xcode uses to launch the application.
///
/// **Architecture**: Uses SwiftUI's `@main` attribute to mark this as the app entry point.
/// The app structure is minimal - all initialization and dependency injection happens
/// in `ContentView`.
///
/// **Usage**: This file is automatically invoked by iOS when the app launches.
/// No manual instantiation required.
@main
struct AayushTestAppV1App: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
