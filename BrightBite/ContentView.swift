//
//  ContentView.swift
//  BrightBite
//
//  Created by Tuan Nguyen on 8/3/25.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var firebaseService: FirebaseService
    @State private var showSplash = true

    var body: some View {
        ZStack {
            if showSplash {
                
                SplashScreenView(isActive: $showSplash)
                    .zIndex(999)
            } else {
                
                Group {
                    if firebaseService.isAuthenticated {
                        LoadingScreen()
                            .transition(.opacity)
                    } else {
                        AuthenticationView()
                            .transition(.opacity)
                    }
                }
                .animation(.easeInOut(duration: 0.3), value: firebaseService.isAuthenticated)
            }
        }
    }
}

#Preview {
    ContentView()
}
