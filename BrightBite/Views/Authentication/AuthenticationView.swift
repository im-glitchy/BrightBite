//
//  AuthenticationView.swift
//  BrightBite
//
//  Created by Tuan Nguyen on 8/3/25.
//

import SwiftUI

struct AuthenticationView: View {
    @EnvironmentObject private var firebaseService: FirebaseService
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var email = ""
    @State private var password = ""
    @State private var showEmailSignIn = false
    @State private var isSignUp = false
    
    var body: some View {
        ZStack {
            
            LinearGradient(
                colors: [Color.blue.opacity(0.1), Color.cyan.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                
                VStack(spacing: 16) {
                    
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
                    
                    Text("Bite better, shine brighter")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                Spacer()
                
                
                VStack(spacing: 20) {
                    if !showEmailSignIn {
                        
                        Button(action: signInWithGoogle) {
                            HStack(spacing: 12) {
                                if isLoading || firebaseService.isSigningIn {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .tint(.white)
                                } else {
                                    Image(systemName: "globe")
                                        .font(.title3)
                                        .foregroundStyle(.white)
                                }
                                
                                Text(isLoading || firebaseService.isSigningIn ? "Signing in..." : "Continue with Google")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                            }
                        }
                        .disabled(isLoading || firebaseService.isSigningIn)
                        .liquidGlassButton(style: .accent)
                        .padding(.horizontal, 40)
                        
                        
                        Button("Sign in with Email") {
                            showEmailSignIn = true
                        }
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.blue)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 16)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                        
                        Text("Secure authentication options")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    } else {
                        
                        VStack(spacing: 16) {
                            VStack(spacing: 12) {
                                TextField("Email", text: $email)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .keyboardType(.emailAddress)
                                    .autocapitalization(.none)
                                
                                SecureField("Password", text: $password)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                            }
                            .padding(.horizontal, 40)
                            
                            Button(action: signInWithEmail) {
                                HStack(spacing: 12) {
                                    if isLoading {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                            .tint(.white)
                                    } else {
                                        Image(systemName: "envelope.fill")
                                            .font(.title3)
                                            .foregroundStyle(.white)
                                    }
                                    
                                    Text(isLoading ? "Signing in..." : (isSignUp ? "Create Account" : "Sign In"))
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                }
                            }
                            .disabled(isLoading || email.isEmpty || password.isEmpty)
                            .liquidGlassButton(style: .accent)
                            .padding(.horizontal, 40)
                            
                            Button(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up") {
                                isSignUp.toggle()
                            }
                            .font(.caption)
                            .foregroundStyle(.blue)
                            
                            Button("← Back to Social Sign-In") {
                                showEmailSignIn = false
                                email = ""
                                password = ""
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                
                Text("We never share your data; you can export or delete anytime.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 20)
            }
        }
        .fullScreenCover(isPresented: .constant(firebaseService.isAuthenticated)) {
            LoadingScreen()
        }
        .alert("Authentication Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func signInWithGoogle() {
        isLoading = true
        
        Task {
            do {
                try await firebaseService.signInWithGoogle()
                await MainActor.run {
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Failed to sign in with Google: \(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }
    
    private func signInWithEmail() {
        isLoading = true
        
        Task {
            do {
                if isSignUp {
                    try await firebaseService.signUpWithEmail(email: email, password: password)
                } else {
                    try await firebaseService.signInWithEmail(email: email, password: password)
                }
                await MainActor.run {
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Failed to \(isSignUp ? "create account" : "sign in"): \(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }
}

#Preview {
    AuthenticationView()
}
