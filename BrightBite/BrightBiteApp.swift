//
//  BrightBiteApp.swift
//  BrightBite
//
//  Created by Tuan Nguyen on 8/3/25.
//

import SwiftUI
import FirebaseCore
import GoogleSignIn

@main
struct BrightBiteApp: App {
    @StateObject private var pythonServerManager = PythonServerManager.shared

    init() {
        
        FirebaseApp.configure()

        
        if let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
           let plist = NSDictionary(contentsOfFile: path),
           let clientId = plist["CLIENT_ID"] as? String {
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientId)
        }

        
        PythonServerManager.shared.checkServerHealth()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(FirebaseService.shared)
                .environmentObject(pythonServerManager)
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
    }
}
