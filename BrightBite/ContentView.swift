//
//  ContentView.swift
//  BrightBite
//
//  Created by Tuan Nguyen on 9/1/25.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var firebaseService: FirebaseService
    
    var body: some View {
        Group {
            if firebaseService.isAuthenticated {
                MainTabView()
            } else {
                AuthenticationView()
            }
        }
        .onAppear {
            // TODO: Check if user is already signed in when Firebase is configured
            // Auth.auth().addStateDidChangeListener { auth, user in
            //     firebaseService.isAuthenticated = user != nil
            // }
        }
    }
}

#Preview {
    ContentView()
}
