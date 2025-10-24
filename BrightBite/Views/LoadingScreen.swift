//
//  LoadingScreen.swift
//  BrightBite
//
//  Created by Tuan Nguyen on 9/1/25.
//

import SwiftUI

struct LoadingScreen: View {
    @EnvironmentObject private var firebaseService: FirebaseService
    @ObservedObject private var meshCache = MeshCache.shared
    @State private var currentStep = 0
    @State private var loadingComplete = false
    @State private var progress: Double = 0.0

    let loadingSteps = [
        "Loading your profile...",
        "Fetching your data...",
        "Preparing 3D tooth models..."
    ]

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

                VStack(spacing: 16) {
                    
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 8)

                        RoundedRectangle(cornerRadius: 10)
                            .fill(
                                LinearGradient(
                                    colors: [.blue, .cyan],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: progress * UIScreen.main.bounds.width * 0.7, height: 8)
                            .animation(.easeInOut(duration: 0.3), value: progress)
                    }
                    .frame(width: UIScreen.main.bounds.width * 0.7)

                    
                    Text(currentStep < loadingSteps.count ? loadingSteps[currentStep] : "Ready!")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .animation(.easeInOut, value: currentStep)
                }

                
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(0..<min(currentStep + 1, loadingSteps.count), id: \.self) { index in
                        HStack(spacing: 12) {
                            Image(systemName: index < currentStep ? "checkmark.circle.fill" : "circle.fill")
                                .foregroundStyle(index < currentStep ? .green : .blue)
                                .font(.caption)

                            Text(loadingSteps[index])
                                .font(.caption)
                                .foregroundStyle(index < currentStep ? .secondary : .primary)
                        }
                        .transition(.move(edge: .leading).combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 40)
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer()

                Text("Bite better, shine brighter")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 20)
            }
        }
        .onAppear {
            startLoading()
        }
        .fullScreenCover(isPresented: $loadingComplete) {
            MainTabView()
        }
    }

    private func startLoading() {
        guard let userId = firebaseService.currentUser?.id else {
            loadingComplete = true
            return
        }

        Task {
            await performStep(0) {
                let profile = try await firebaseService.getUserProfile(uid: userId)

                await MainActor.run {
                    firebaseService.currentUser = profile
                }

                try? await firebaseService.ensureUserStorageFolder(for: userId)
            }

            await performStep(1) {
                async let profileImage = firebaseService.loadAndCacheProfileImage(for: userId)
                async let treatmentPlan = firebaseService.loadTreatmentPlan(for: userId)
                async let appointments = firebaseService.loadAppointments(for: userId)
                async let toothStatuses = firebaseService.getToothStatuses(for: userId, on: nil)
                async let painEntries = firebaseService.getPainEntries(for: userId, on: nil)
                async let insuranceCard = firebaseService.loadInsuranceCard(for: userId)

                _ = try? await (profileImage, treatmentPlan, appointments, toothStatuses, painEntries, insuranceCard)
            }

            await performStep(2) {
                await meshCache.preloadAllTeeth()
            }

            await MainActor.run {
                withAnimation {
                    loadingComplete = true
                }
            }
        }
    }

    private func performStep(_ step: Int, action: @escaping () async throws -> Void) async {
        await MainActor.run {
            currentStep = step
            progress = Double(step) / Double(loadingSteps.count)
        }

        do {
            try await action()
        } catch {
            print("⚠️ Error in loading step \(step): \(error)")
            
        }

        
        try? await Task.sleep(nanoseconds: 100_000_000) 
    }
}

#Preview {
    LoadingScreen()
        .environmentObject(FirebaseService.shared)
}
