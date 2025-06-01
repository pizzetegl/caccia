//
//  ARGeoAppApp.swift
//  ARGeoApp
//
//  Created by Lorenzo Conti on 20/04/25.
//

import SwiftUI

@main
struct ARGeoAppApp: App {
    init() {
        // Rimuove la barra dei suggerimenti dalla tastiera
        UITextField.appearance().inputAssistantItem.leadingBarButtonGroups = []
        UITextField.appearance().inputAssistantItem.trailingBarButtonGroups = []
    }
    @State private var showSplash = true
    @State private var isLoggedIn = false

    var body: some Scene {
        WindowGroup {
            if showSplash {
                SplashView(showSplash: $showSplash)
            }
            else if !isLoggedIn {
                LoginView(isLoggedIn: $isLoggedIn)
            }
            else {
                ContentView()
            }
        }
    }
}
