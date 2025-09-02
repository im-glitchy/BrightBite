//
//  BrightBiteApp.swift
//  BrightBite
//
//  Created by Tuan Nguyen on 9/1/25.
//

import SwiftUI
// TODO: Uncomment when Firebase is added
// import FirebaseCore

@main
struct BrightBiteApp: App {
    
    init() {
        // TODO: Uncomment when Firebase is added
        // FirebaseApp.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(FirebaseService.shared)
        }
    }
}
