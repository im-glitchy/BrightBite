//
//  HomeView.swift
//  BrightBite
//
//  Created by Tuan Nguyen on 8/3/25.
//

import SwiftUI
import PhotosUI
import FirebaseAuth

struct HomeView: View {
    @EnvironmentObject private var firebaseService: FirebaseService
    @EnvironmentObject private var tabNavigation: TabNavigationManager
    @State private var careTasks: [CareTask] = []
    @State private var recentActivities: [RecentActivity] = []
    @State private var dentalSummary: DentalSummary?

    @State private var showProfile = false
    @State private var showChewCheck = false
    @State private var showScanNotes = false
    @State private var showAddAppointment = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 20) {
                    
                    WelcomeCard(
                        userName: getCurrentUserEmail(),
                        statusMessage: nil
                    ) {
                        tabNavigation.switchToChat()
                    }


                    TodaysCareCard(tasks: $careTasks)

                    DentalSummaryCard(summary: dentalSummary)

                    QuickActionsCard(
                        onScanFood: { showChewCheck = true },
                        onAskBot: { tabNavigation.switchToChat() },
                        onLogPain: { tabNavigation.switchToMap() },
                        onNextAppointment: { tabNavigation.switchToPlan() }
                    )


                    RecentActivityCard(
                        activities: recentActivities,
                        onViewDocument: { documentId in
                            tabNavigation.switchToPlan()
                        },
                        onViewTooth: { toothNumber in
                            tabNavigation.switchToMap(withTooth: toothNumber)
                        }
                    )
                }
                .padding(.horizontal)
                .padding(.top)
                .padding(.bottom, 20)
            }
            .background(
                LinearGradient(
                    colors: [Color.blue.opacity(0.05), Color.clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showProfile = true }) {
                        Group {
                            if let cachedImage = firebaseService.cachedProfileImage {
                                Image(uiImage: cachedImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } else {
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        Image(systemName: "person.fill")
                                            .font(.caption)
                                            .foregroundStyle(.blue)
                                    )
                            }
                        }
                        .frame(width: 32, height: 32)
                        .clipShape(Circle())
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Scan Food with ChewCheck") {
                            showChewCheck = true
                        }
                        Button("Scan Dentist Notes") {
                            showScanNotes = true
                        }
                        Button("Add Appointment") {
                            showAddAppointment = true
                        }
                    } label: {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 32, height: 32)
                            .overlay(
                                Image(systemName: "plus")
                                    .font(.caption)
                                    .foregroundStyle(.blue)
                            )
                    }
                }
            }

        }
        .sheet(isPresented: $showProfile) {
            ProfileSheet()
        }
        .sheet(isPresented: $showChewCheck) {
            ChewCheckView()
        }
        .sheet(isPresented: $showScanNotes) {
            ScanDentistNotesView()
        }
        .sheet(isPresented: $showAddAppointment) {
            AddAppointmentView()
        }
        .onAppear {
            loadDentalData()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshHomeData"))) { _ in
            loadDentalData()
        }
    }

    private func loadDentalData() {
        guard let userId = firebaseService.currentUser?.id else { return }

        Task {
            do {
                async let summary = firebaseService.loadDentalSummary(for: userId)
                async let activities = firebaseService.loadActivities(for: userId, limit: 5)

                let (loadedSummary, loadedActivities) = try await (summary, activities)

                await MainActor.run {
                    self.dentalSummary = loadedSummary
                    self.recentActivities = loadedActivities
                }

                if loadedSummary == nil {
                    try? await firebaseService.generateDentalSummary(for: userId)
                    if let newSummary = try? await firebaseService.loadDentalSummary(for: userId) {
                        await MainActor.run {
                            self.dentalSummary = newSummary
                        }
                    }
                }
            } catch {
                print("❌ Error loading dental data: \(error)")
            }
        }
    }
    
    private func getCurrentUserEmail() -> String {
        
        if let currentUser = firebaseService.currentUser,
           let name = currentUser.name, !name.isEmpty {
            return name
        }
        
        
        if let user = Auth.auth().currentUser {
            return user.email ?? "User"
        }
        
        return "User"
    }
    
}

struct ProfileSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var firebaseService: FirebaseService
    @State private var selectedItem: PhotosPickerItem?
    @State private var profileImage: UIImage?
    @State private var isUploadingPhoto = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                
                Button(action: {}) {
                    Group {
                        if let profileImage = profileImage {
                            Image(uiImage: profileImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } else {
                            Circle()
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .font(.largeTitle)
                                        .foregroundStyle(.blue)
                                )
                        }
                    }
                    .frame(width: 80, height: 80)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(.blue.opacity(0.3), lineWidth: 2)
                    )
                    .overlay(
                        
                        PhotosPicker(
                            selection: $selectedItem,
                            matching: .images,
                            photoLibrary: .shared()
                        ) {
                            Circle()
                                .fill(.clear)
                                .frame(width: 80, height: 80)
                                .overlay(
                                    ZStack {
                                        if isUploadingPhoto {
                                            ProgressView()
                                                .scaleEffect(0.8)
                                                .tint(.white)
                                        } else {
                                            Image(systemName: "camera.fill")
                                                .font(.caption)
                                                .foregroundStyle(.white)
                                                .background(
                                                    Circle()
                                                        .fill(.blue)
                                                        .frame(width: 24, height: 24)
                                                )
                                        }
                                    }
                                    .offset(x: 25, y: 25)
                                )
                        }
                    )
                }
                .disabled(isUploadingPhoto)
                
                Text(firebaseService.currentUser?.name ?? "User")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Member since September 2025")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Button("Sign Out") {
                    Task {
                        do {
                            try await firebaseService.signOut()
                            dismiss()
                        } catch {
                            print("Error signing out: \(error)")
                        }
                    }
                }
                .foregroundStyle(.red)
            }
            .padding()
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
        .onChange(of: selectedItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await uploadProfilePhoto(image)
                }
            }
        }
        .onAppear {
            loadProfilePhoto()
        }
    }
    
    private func uploadProfilePhoto(_ image: UIImage) async {
        guard let userId = firebaseService.currentUser?.id,
              var currentUser = firebaseService.currentUser else { return }

        await MainActor.run {
            isUploadingPhoto = true
        }

        do {
            let imageData = await Task.detached {
                image.jpegData(compressionQuality: 0.8)
            }.value

            guard let imageData = imageData else {
                print("❌ Failed to convert image to data")
                await MainActor.run { isUploadingPhoto = false }
                return
            }

            print("📸 Uploading profile photo to Firebase Storage...")

            
            try? await firebaseService.ensureUserStorageFolder(for: userId)

            
            let imageURL = try await firebaseService.uploadProfileImage(imageData, for: userId)
            print("✅ Profile photo uploaded: \(imageURL)")

            
            currentUser.profileImageURL = imageURL
            try await firebaseService.updateUserProfile(currentUser)
            print("✅ Profile updated in Firestore")

            await MainActor.run {
                profileImage = image
                firebaseService.cachedProfileImage = image
                isUploadingPhoto = false
            }
        } catch {
            await MainActor.run {
                isUploadingPhoto = false
            }
            print("❌ Error uploading profile photo: \(error)")
        }
    }
    
    private func loadProfilePhoto() {
        
        if let cachedImage = firebaseService.cachedProfileImage {
            profileImage = cachedImage
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(TabNavigationManager())
        .environmentObject(FirebaseService.shared)
}
