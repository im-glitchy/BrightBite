//
//  AuthenticationView.swift
//  BrightBite
//
//  Created by Tuan Nguyen on 9/1/25.
//

import SwiftUI

struct AuthenticationView: View {
    @EnvironmentObject private var firebaseService: FirebaseService
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        ZStack {
            // Background with subtle gradient
            LinearGradient(
                colors: [Color.blue.opacity(0.1), Color.cyan.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                // Logo and branding
                VStack(spacing: 16) {
                    // BrightBite Logo
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 120, height: 120)
                            .shadow(color: .blue.opacity(0.3), radius: 20)
                        
                        Image(systemName: "mouth")
                            .font(.system(size: 50, weight: .light))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue, .cyan],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    
                    Text("BrightBite")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .cyan],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    
                    Text("Your daily dental companion")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                Spacer()
                
                // Authentication buttons
                VStack(spacing: 20) {
                    // Main Continue button
                    Button(action: signInAnonymously) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(.white)
                            }
                            
                            Text(isLoading ? "Getting started..." : "Continue")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(isLoading)
                    .liquidGlassButton(style: .accent)
                    .padding(.horizontal, 40)
                    
                    // Alternative sign-in options
                    HStack(spacing: 30) {
                        Button("Sign in with Apple") {
                            // TODO: Implement Apple Sign-In
                        }
                        .font(.subheadline)
                        .foregroundStyle(.blue)
                        
                        Button("Email sign-in") {
                            // TODO: Implement Email Sign-In
                        }
                        .font(.subheadline)
                        .foregroundStyle(.blue)
                    }
                }
                
                Spacer()
                
                // Privacy disclaimer
                Text("We never share your data; you can export or delete anytime.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 20)
            }
        }
        .fullScreenCover(isPresented: .constant(firebaseService.isAuthenticated)) {
            MainTabView()
        }
        .alert("Authentication Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func signInAnonymously() {
        isLoading = true
        
        Task {
            do {
                try await firebaseService.signInAnonymously()
                await MainActor.run {
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Failed to sign in: \(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }
}

#Preview {
    AuthenticationView()
}