//
//  FirebaseService.swift
//  BrightBite
//
//  Created by Tuan Nguyen on 9/11/25.
//

import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import GoogleSignIn
import UIKit
import FirebaseCore


class FirebaseService: ObservableObject {


    private let useFirebase = true
    static let shared = FirebaseService()

    @Published var currentUser: UserProfile?
    @Published var isAuthenticated = false
    @Published var isSigningIn = false
    @Published var cachedProfileImage: UIImage?

    private struct CacheEntry<T> {
        let data: T
        let timestamp: Date

        func isValid(ttl: TimeInterval) -> Bool {
            return Date().timeIntervalSince(timestamp) < ttl
        }
    }

    private var userProfileCache: [String: CacheEntry<UserProfile>] = [:]
    private var toothStatusesCache: [String: CacheEntry<[Int: ToothStatus]>] = [:]
    private var painEntriesCache: [String: CacheEntry<[Int: PainEntry]>] = [:]
    private var appointmentsCache: [String: CacheEntry<[Appointment]>] = [:]
    private var treatmentPlansCache: [String: CacheEntry<TreatmentPlan>] = [:]

    private let cacheTTL: TimeInterval = 300

    private func invalidateUserProfileCache(uid: String) {
        userProfileCache.removeValue(forKey: uid)
        print("🗑️ Invalidated user profile cache for \(uid)")
    }

    private func invalidateToothStatusesCache(uid: String) {
        toothStatusesCache = toothStatusesCache.filter { !$0.key.hasPrefix(uid) }
        print("🗑️ Invalidated tooth statuses cache for \(uid)")
    }

    private func invalidatePainEntriesCache(uid: String) {
        painEntriesCache = painEntriesCache.filter { !$0.key.hasPrefix(uid) }
        print("🗑️ Invalidated pain entries cache for \(uid)")
    }

    private func invalidateAppointmentsCache(uid: String) {
        appointmentsCache.removeValue(forKey: uid)
        print("🗑️ Invalidated appointments cache for \(uid)")
    }

    private func invalidateTreatmentPlanCache(uid: String) {
        treatmentPlansCache.removeValue(forKey: uid)
        print("🗑️ Invalidated treatment plan cache for \(uid)")
    }

    func invalidateAllCaches(for uid: String) {
        invalidateUserProfileCache(uid: uid)
        invalidateToothStatusesCache(uid: uid)
        invalidatePainEntriesCache(uid: uid)
        invalidateAppointmentsCache(uid: uid)
        invalidateTreatmentPlanCache(uid: uid)
        print("🗑️ Invalidated all caches for \(uid)")
    }

    private init() {
        print("DEBUG: FirebaseService initialization starting...")
        
        
        
        
        print("DEBUG: Setting initial authentication state...")
        
        self.isAuthenticated = false
        self.currentUser = nil
        
        
        print("DEBUG: Attempting to sign out existing user...")
        do {
            try Auth.auth().signOut()
            print("DEBUG: Signed out existing user for development mode")
        } catch {
            print("DEBUG: Error signing out (this might be normal if no user was signed in): \(error)")
        }
        
        print("DEBUG: Setting up auth state listener...")
        
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            print("DEBUG: Auth state changed - user: \(user?.uid ?? "nil")")
            DispatchQueue.main.async {
                if let user = user {
                    print("DEBUG: Loading user profile for: \(user.uid)")
                    self?.loadUserProfile(from: user)
                } else {
                    print("DEBUG: No user - setting to not authenticated")
                    self?.currentUser = nil
                    self?.isAuthenticated = false
                }
            }
        }
        
        print("DEBUG: FirebaseService initialization completed")
    }
    
    
    
    @MainActor
    func signInWithEmail(email: String, password: String) async throws {
        isSigningIn = true
        defer { isSigningIn = false }
        
        let authResult = try await Auth.auth().signIn(withEmail: email, password: password)
        let firebaseUser = authResult.user
        
        
        if let existingProfile = try await getUserProfile(uid: firebaseUser.uid) {
            self.currentUser = existingProfile
            self.isAuthenticated = true
        } else {
            
            let userProfile = UserProfile(
                id: firebaseUser.uid,
                name: firebaseUser.displayName,
                hasBraces: false
            )
            try await createOrUpdateUserProfile(userProfile)
            self.currentUser = userProfile
            self.isAuthenticated = true
        }
    }
    
    @MainActor
    func signUpWithEmail(email: String, password: String) async throws {
        print("DEBUG: Starting email sign-up for: \(email)")
        isSigningIn = true
        defer { isSigningIn = false }
        
        do {
            print("DEBUG: About to call Auth.auth().createUser")
            let authResult = try await Auth.auth().createUser(withEmail: email, password: password)
            let firebaseUser = authResult.user
            print("DEBUG: Firebase user created with UID: \(firebaseUser.uid)")
            
            
            let userProfile = UserProfile(
                id: firebaseUser.uid,
                name: firebaseUser.displayName,
                hasBraces: false
            )
            print("DEBUG: User profile created: \(userProfile)")
            
            
            try await createOrUpdateUserProfile(userProfile)
            print("DEBUG: Profile saved to Firestore")
            
            self.currentUser = userProfile
            self.isAuthenticated = true
            print("DEBUG: Sign-up completed successfully")
        } catch {
            print("DEBUG: Sign-up error: \(error)")
            throw error
        }
    }
    
    @MainActor
    func signInWithGoogle() async throws {
        isSigningIn = true
        defer { isSigningIn = false }
        
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            throw AuthError.noRootViewController
        }
        
        guard let firebaseApp = FirebaseApp.app() else {
            print("DEBUG: Firebase app is nil")
            throw AuthError.noClientID
        }
        
        guard let clientID = firebaseApp.options.clientID else {
            print("DEBUG: Firebase clientID is nil")
            throw AuthError.noClientID
        }
        
        
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        
        
        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
        let googleUser = result.user
        
        guard let idToken = googleUser.idToken?.tokenString else {
            throw AuthError.noIDToken
        }
        
        let accessToken = googleUser.accessToken.tokenString
        let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)
        
        
        let authResult = try await Auth.auth().signIn(with: credential)
        let firebaseUser = authResult.user

        
        if let existingProfile = try await getUserProfile(uid: firebaseUser.uid) {
            
            self.currentUser = existingProfile
            self.isAuthenticated = true
        } else {
            
            let userProfile = UserProfile(
                id: firebaseUser.uid,
                name: firebaseUser.displayName,
                hasBraces: false 
            )

            
            try await createOrUpdateUserProfile(userProfile)

            
            self.currentUser = userProfile
            self.isAuthenticated = true
        }
    }
    
    func signOut() async throws {
        try Auth.auth().signOut()
        GIDSignIn.sharedInstance.signOut()

        await MainActor.run {
            self.currentUser = nil
            self.isAuthenticated = false
        }
    }

    func deleteAccount() async throws {
        guard let user = Auth.auth().currentUser else {
            throw AuthError.noIDToken
        }

        let uid = user.uid

        
        let db = Firestore.firestore()
        let userDoc = db.collection("users").document(uid)

        
        let collections = ["painEntries", "toothStatuses", "chewcheck", "appointments", "history", "chat"]
        for collection in collections {
            let snapshot = try await userDoc.collection(collection).getDocuments()
            for document in snapshot.documents {
                try await document.reference.delete()
            }
        }

        
        try await userDoc.delete()

        
        try await user.delete()

        
        GIDSignIn.sharedInstance.signOut()

        
        await MainActor.run {
            self.currentUser = nil
            self.isAuthenticated = false
        }
    }
    
    private func loadUserProfile(from user: User) {
        Task {
            do {
                if let profile = try await getUserProfile(uid: user.uid) {
                    await MainActor.run {
                        self.currentUser = profile
                        self.isAuthenticated = true
                    }
                } else {
                    
                    let newProfile = UserProfile(
                        id: user.uid,
                        name: user.displayName,
                        hasBraces: false
                    )
                    try await createOrUpdateUserProfile(newProfile)
                    await MainActor.run {
                        self.currentUser = newProfile
                        self.isAuthenticated = true
                    }
                }
            } catch {
                print("Error loading user profile: \(error)")
                await MainActor.run {
                    self.currentUser = nil
                    self.isAuthenticated = false
                }
            }
        }
    }
    
    private func createOrUpdateUserProfile(_ profile: UserProfile) async throws {
        print("DEBUG: Creating/updating profile for user: \(profile.id)")
        let db = Firestore.firestore()
        
        
        let dentistInfoData: Any
        if let dentistInfo = profile.dentistInfo {
            dentistInfoData = [
                "name": dentistInfo.name,
                "phone": dentistInfo.phone as Any? ?? NSNull(),
                "email": dentistInfo.email as Any? ?? NSNull(),
                "address": dentistInfo.address as Any? ?? NSNull()
            ]
        } else {
            dentistInfoData = NSNull()
        }
        
        
        let userData: [String: Any] = [
            "name": profile.name as Any? ?? NSNull(),
            "hasBraces": profile.hasBraces,
            "createdAt": profile.createdAt.timeIntervalSince1970,
            "dentistInfo": dentistInfoData,
            "profileImageURL": profile.profileImageURL as Any? ?? NSNull()
        ]
        
        print("DEBUG: Saving user data to Firestore: \(userData)")
        
        do {
            try await db.collection("users").document(profile.id).setData(userData, merge: true)
            print("DEBUG: Successfully saved to Firestore")
        } catch {
            print("DEBUG: Firestore save error: \(error)")
            throw error
        }
    }
    
    
    func updateUserProfile(_ profile: UserProfile) async throws {
        try await createOrUpdateUserProfile(profile)
        invalidateUserProfileCache(uid: profile.id)
        await MainActor.run {
            self.currentUser = profile
        }
    }
    
    func getUserProfile(uid: String) async throws -> UserProfile? {
        if let cached = userProfileCache[uid], cached.isValid(ttl: cacheTTL) {
            print("📦 Using cached user profile for \(uid)")
            return cached.data
        }

        let db = Firestore.firestore()
        let document = try await db.collection("users").document(uid).getDocument()

        guard document.exists, let data = document.data() else {
            return nil
        }

        let dentistInfo: DentistInfo?
        if let dentistData = data["dentistInfo"] as? [String: Any] {
            dentistInfo = DentistInfo(
                name: dentistData["name"] as? String ?? "",
                phone: dentistData["phone"] as? String,
                email: dentistData["email"] as? String,
                address: dentistData["address"] as? String
            )
        } else {
            dentistInfo = nil
        }

        let profile = UserProfile(
            id: uid,
            name: data["name"] as? String,
            hasBraces: data["hasBraces"] as? Bool ?? false,
            dentistInfo: dentistInfo,
            profileImageURL: data["profileImageURL"] as? String,
            createdAt: Date(timeIntervalSince1970: data["createdAt"] as? TimeInterval ?? Date().timeIntervalSince1970)
        )

        userProfileCache[uid] = CacheEntry(data: profile, timestamp: Date())
        print("💾 Cached user profile for \(uid)")

        return profile
    }

    func uploadProfileImage(_ imageData: Data, for uid: String) async throws -> String {
        let storage = Storage.storage()
        let path = "users/\(uid)/profileImage.jpg"
        let storageRef = storage.reference(withPath: path)

        print("📤 Uploading to path: \(path)")
        print("📦 Image size: \(imageData.count / 1024)KB")

        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        do {
            _ = try await storageRef.putDataAsync(imageData, metadata: metadata)
            print("✅ Upload completed, fetching download URL...")

            let downloadURL = try await storageRef.downloadURL()
            print("✅ Download URL: \(downloadURL.absoluteString)")

            return downloadURL.absoluteString
        } catch {
            print("❌ Upload failed: \(error.localizedDescription)")
            throw error
        }
    }

    func deleteProfileImage(for uid: String) async throws {
        let storage = Storage.storage()
        let storageRef = storage.reference(withPath: "users/\(uid)/profileImage.jpg")

        try? await storageRef.delete()
        print("✅ Deleted profile image from Firebase Storage")
    }

    func loadAndCacheProfileImage(for uid: String) async {
        guard let imageURL = currentUser?.profileImageURL,
              let url = URL(string: imageURL) else {
            print("⚠️ No profile image URL available")
            return
        }

        do {
            print("📥 Downloading profile image from: \(imageURL)")
            let (data, _) = try await URLSession.shared.data(from: url)

            if let image = UIImage(data: data) {
                await MainActor.run {
                    self.cachedProfileImage = image
                    print("✅ Profile image cached successfully")
                }
            } else {
                print("⚠️ Failed to convert data to UIImage")
            }
        } catch {
            print("⚠️ Error downloading profile image: \(error.localizedDescription)")
        }
    }

    func ensureUserStorageFolder(for uid: String) async throws {
        let storage = Storage.storage()
        let path = "users/\(uid)/.placeholder"
        let storageRef = storage.reference(withPath: path)

        print("📁 Ensuring storage folder exists at: \(path)")

        
        let placeholderData = "folder_initialized".data(using: .utf8)!

        let metadata = StorageMetadata()
        metadata.contentType = "text/plain"

        do {
            _ = try await storageRef.putDataAsync(placeholderData, metadata: metadata)
            print("✅ Created storage folder for user: \(uid)")
        } catch {
            
            print("ℹ️ Storage folder initialization: \(error)")

            
            do {
                _ = try await storage.reference(withPath: "users/\(uid)").listAll()
                print("✅ Storage folder already exists and is accessible")
            } catch {
                print("❌ Storage access error: \(error)")
                throw error
            }
        }
    }
    
    
    func saveTreatmentPlan(_ plan: TreatmentPlan, for uid: String) async throws {
        let db = Firestore.firestore()

        
        let restrictionsData = plan.restrictions.map { restriction -> [String: Any] in
            [
                "id": restriction.id.uuidString,
                "type": restriction.type.rawValue,
                "endDate": restriction.endDate?.timeIntervalSince1970 ?? NSNull(),
                "reason": restriction.reason ?? NSNull()
            ]
        }

        let tasksData = plan.currentTasks.map { task -> [String: Any] in
            [
                "id": task.id.uuidString,
                "title": task.title,
                "isCompleted": task.isCompleted,
                "dueDate": task.dueDate?.timeIntervalSince1970 ?? NSNull(),
                "category": task.category.rawValue
            ]
        }

        let notesData = plan.doctorNotes.map { note -> [String: Any] in
            [
                "id": note.id.uuidString,
                "content": note.content,
                "createdAt": note.createdAt.timeIntervalSince1970,
                "source": note.source.rawValue
            ]
        }

        let medicationsData = plan.medications.map { med -> [String: Any] in
            [
                "id": med.id.uuidString,
                "name": med.name,
                "dosage": med.dosage,
                "frequency": med.frequency,
                "endDate": med.endDate?.timeIntervalSince1970 ?? NSNull(),
                "instructions": med.instructions ?? NSNull()
            ]
        }

        let alignerProgressData: Any
        if let progress = plan.alignerProgress {
            alignerProgressData = [
                "currentTray": progress.currentTray,
                "totalTrays": progress.totalTrays,
                "nextChangeDate": progress.nextChangeDate?.timeIntervalSince1970 ?? NSNull(),
                "wearHoursPerDay": progress.wearHoursPerDay
            ]
        } else {
            alignerProgressData = NSNull()
        }

        let planData: [String: Any] = [
            "restrictions": restrictionsData,
            "currentTasks": tasksData,
            "doctorNotes": notesData,
            "medications": medicationsData,
            "alignerProgress": alignerProgressData,
            "lastUpdated": Date().timeIntervalSince1970
        ]

        try await db.collection("users").document(uid)
            .collection("treatmentPlan").document("current")
            .setData(planData, merge: true)

        print("✅ Saved treatment plan to Firebase")
    }
    
    func getTreatmentPlan(for uid: String) async throws -> TreatmentPlan? {
        return try await loadTreatmentPlan(for: uid)
    }

    func loadTreatmentPlan(for uid: String) async throws -> TreatmentPlan {
        if let cached = treatmentPlansCache[uid], cached.isValid(ttl: cacheTTL) {
            print("📦 Using cached treatment plan for \(uid)")
            return cached.data
        }

        let db = Firestore.firestore()


        var restrictions: [DietRestriction] = []
        var medications: [Medication] = []
        var doctorNotes: [DoctorNote] = []

        
        let restrictionsSnapshot = try await db.collection("users").document(uid)
            .collection("dietRestrictions")
            .order(by: "createdAt", descending: true)
            .getDocuments()

        for doc in restrictionsSnapshot.documents {
            let data = doc.data()
            if let typeStr = data["type"] as? String,
               let type = RestrictionType.from(string: typeStr) {
                let restriction = DietRestriction(
                    type: type,
                    endDate: (data["endDate"] as? Double).map { Date(timeIntervalSince1970: $0) },
                    reason: data["reason"] as? String
                )
                restrictions.append(restriction)
            }
        }

        
        let medicationsSnapshot = try await db.collection("users").document(uid)
            .collection("medications")
            .order(by: "createdAt", descending: true)
            .getDocuments()

        for doc in medicationsSnapshot.documents {
            let data = doc.data()
            if let name = data["name"] as? String,
               let dosage = data["dosage"] as? String,
               let frequency = data["frequency"] as? String {
                let medication = Medication(
                    name: name,
                    dosage: dosage,
                    frequency: frequency,
                    endDate: (data["endDate"] as? Double).map { Date(timeIntervalSince1970: $0) },
                    instructions: data["instructions"] as? String
                )
                medications.append(medication)
            }
        }

        
        let notesSnapshot = try await db.collection("users").document(uid)
            .collection("doctorNotes")
            .order(by: "createdAt", descending: true)
            .getDocuments()

        for doc in notesSnapshot.documents {
            let data = doc.data()
            if let content = data["content"] as? String,
               let sourceStr = data["source"] as? String,
               let source = NoteSource(rawValue: sourceStr) {
                
                let noteId = UUID(uuidString: doc.documentID) ?? UUID()
                let note = DoctorNote(
                    id: noteId,
                    title: data["title"] as? String,
                    content: content,
                    createdAt: (data["createdAt"] as? Double).map { Date(timeIntervalSince1970: $0) } ?? Date(),
                    source: source
                )
                print("  📄 Loaded note: \(note.title ?? "Untitled") (ID: \(noteId.uuidString))")
                doctorNotes.append(note)
            }
        }

        print("✅ Loaded treatment plan: \(doctorNotes.count) notes, \(medications.count) medications, \(restrictions.count) restrictions")

        let plan = TreatmentPlan(
            restrictions: restrictions,
            currentTasks: [],
            doctorNotes: doctorNotes,
            medications: medications,
            alignerProgress: nil
        )

        treatmentPlansCache[uid] = CacheEntry(data: plan, timestamp: Date())
        print("💾 Cached treatment plan for \(uid)")

        return plan
    }
    
    
    func savePainEntry(_ entry: PainEntry, for uid: String) async throws {
        let db = Firestore.firestore()

        let entryData: [String: Any] = [
            "toothNumber": entry.toothNumber,
            "painLevel": entry.painLevel,
            "notes": entry.notes as Any? ?? NSNull(),
            "timestamp": entry.timestamp.timeIntervalSince1970
        ]


        try await db.collection("users").document(uid)
            .collection("painEntries").document(entry.id.uuidString)
            .setData(entryData)

        invalidatePainEntriesCache(uid: uid)

        print("DEBUG: Saved pain entry for tooth #\(entry.toothNumber) at \(entry.timestamp)")
    }

    func getPainEntries(for uid: String, on date: Date? = nil) async throws -> [Int: PainEntry] {
        let cacheKey = "\(uid)_\(date?.timeIntervalSince1970 ?? 0)"
        if let cached = painEntriesCache[cacheKey], cached.isValid(ttl: cacheTTL) {
            print("📦 Using cached pain entries for \(cacheKey)")
            return cached.data
        }

        let db = Firestore.firestore()


        if let date = date {
            let calendar = Calendar.current
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date))!

            
            let query = db.collection("users").document(uid).collection("painEntries")
                .whereField("timestamp", isLessThan: endOfDay.timeIntervalSince1970)
                .order(by: "timestamp", descending: true)

            let snapshot = try await query.getDocuments()

            var entries: [Int: PainEntry] = [:]

            for document in snapshot.documents {
                let data = document.data()

                guard let toothNumber = data["toothNumber"] as? Int else { continue }

                
                if entries[toothNumber] == nil {
                    let painLevel = data["painLevel"] as? Double ?? 0
                    let notes = data["notes"] as? String
                    let timestamp = Date(timeIntervalSince1970: data["timestamp"] as? TimeInterval ?? Date().timeIntervalSince1970)

                    let entry = PainEntry(
                        toothNumber: toothNumber,
                        painLevel: painLevel,
                        notes: notes,
                        timestamp: timestamp
                    )

                    entries[toothNumber] = entry
                }
            }

            print("📅 Loaded \(entries.count) pain entries up to \(date) (sustained data)")
            painEntriesCache[cacheKey] = CacheEntry(data: entries, timestamp: Date())
            print("💾 Cached pain entries for \(cacheKey)")
            return entries
        } else {
            
            let query = db.collection("users").document(uid).collection("painEntries")
                .order(by: "timestamp", descending: true)

            let snapshot = try await query.getDocuments()

            var entries: [Int: PainEntry] = [:]

            for document in snapshot.documents {
                let data = document.data()

                guard let toothNumber = data["toothNumber"] as? Int else { continue }

                
                if entries[toothNumber] == nil {
                    let painLevel = data["painLevel"] as? Double ?? 0
                    let notes = data["notes"] as? String
                    let timestamp = Date(timeIntervalSince1970: data["timestamp"] as? TimeInterval ?? Date().timeIntervalSince1970)

                    let entry = PainEntry(
                        toothNumber: toothNumber,
                        painLevel: painLevel,
                        notes: notes,
                        timestamp: timestamp
                    )

                    entries[toothNumber] = entry
                }
            }

            print("📊 Loaded \(entries.count) pain entries (all time)")
            painEntriesCache[cacheKey] = CacheEntry(data: entries, timestamp: Date())
            print("💾 Cached all-time pain entries for \(cacheKey)")
            return entries
        }
    }

    func getDateRange(for uid: String) async throws -> (oldest: Date, newest: Date)? {
        let db = Firestore.firestore()

        
        let oldestSnapshot = try await db.collection("users").document(uid)
            .collection("painEntries")
            .order(by: "timestamp", descending: false)
            .limit(to: 1)
            .getDocuments()

        
        let newestSnapshot = try await db.collection("users").document(uid)
            .collection("painEntries")
            .order(by: "timestamp", descending: true)
            .limit(to: 1)
            .getDocuments()

        guard let oldestData = oldestSnapshot.documents.first?.data(),
              let newestData = newestSnapshot.documents.first?.data(),
              let oldestTimestamp = oldestData["timestamp"] as? TimeInterval,
              let newestTimestamp = newestData["timestamp"] as? TimeInterval else {
            return nil
        }

        return (Date(timeIntervalSince1970: oldestTimestamp), Date(timeIntervalSince1970: newestTimestamp))
    }

    
    func saveToothStatus(_ status: ToothStatus, for uid: String) async throws {
        let db = Firestore.firestore()

        let statusData: [String: Any] = [
            "toothNumber": status.toothNumber,
            "condition": status.condition.rawValue,
            "currentPainLevel": status.currentPainLevel,
            "lastUpdated": status.lastUpdated.timeIntervalSince1970,
            "procedures": status.procedures.map { procedure in
                [
                    "type": procedure.type.rawValue,
                    "date": procedure.date.timeIntervalSince1970,
                    "notes": procedure.notes as Any? ?? NSNull()
                ]
            }
        ]

        
        try await db.collection("users").document(uid)
            .collection("toothStatuses").document("\(status.toothNumber)")
            .setData(statusData)

        print("✅ Saved current tooth status for tooth #\(status.toothNumber)")

        
        let historyData: [String: Any] = [
            "toothNumber": status.toothNumber,
            "condition": status.condition.rawValue,
            "currentPainLevel": status.currentPainLevel,
            "timestamp": status.lastUpdated.timeIntervalSince1970,
            "procedures": status.procedures.map { procedure in
                [
                    "type": procedure.type.rawValue,
                    "date": procedure.date.timeIntervalSince1970,
                    "notes": procedure.notes as Any? ?? NSNull()
                ]
            }
        ]

        try await db.collection("users").document(uid)
            .collection("toothStatuses").document("\(status.toothNumber)")
            .collection("history").addDocument(data: historyData)

        invalidateToothStatusesCache(uid: uid)

        print("📝 Saved tooth status history for tooth #\(status.toothNumber)")
    }

    func getToothStatuses(for uid: String, on date: Date? = nil) async throws -> [Int: ToothStatus] {
        let cacheKey = "\(uid)_\(date?.timeIntervalSince1970 ?? 0)"
        if let cached = toothStatusesCache[cacheKey], cached.isValid(ttl: cacheTTL) {
            print("📦 Using cached tooth statuses for \(cacheKey)")
            return cached.data
        }

        let db = Firestore.firestore()


        if let date = date {
            let targetTimestamp = date.timeIntervalSince1970
            var statuses: [Int: ToothStatus] = [:]

            let toothDocsSnapshot = try await db.collection("users").document(uid)
                .collection("toothStatuses")
                .getDocuments()

            print("📊 Looking for tooth statuses at timestamp: \(targetTimestamp) (\(date))")

            await withTaskGroup(of: (Int, QuerySnapshot?).self) { group in
                for toothDoc in toothDocsSnapshot.documents {
                    guard let toothNumber = toothDoc.data()["toothNumber"] as? Int else { continue }

                    group.addTask {
                        let historySnapshot = try? await db.collection("users").document(uid)
                            .collection("toothStatuses").document("\(toothNumber)")
                            .collection("history")
                            .whereField("timestamp", isLessThanOrEqualTo: targetTimestamp)
                            .order(by: "timestamp", descending: true)
                            .limit(to: 1)
                            .getDocuments()

                        return (toothNumber, historySnapshot)
                    }
                }

                for await (toothNumber, historySnapshot) in group {
                    guard let historySnapshot = historySnapshot else { continue }

                    print("  🔍 Tooth #\(toothNumber): Found \(historySnapshot.documents.count) history entries before target date")

                    if let historyDoc = historySnapshot.documents.first {
                        let data = historyDoc.data()
                        let historyTimestamp = data["timestamp"] as? TimeInterval ?? 0

                        let condition = ToothCondition(rawValue: data["condition"] as? String ?? "healthy") ?? .healthy
                        let currentPainLevel = data["currentPainLevel"] as? Double ?? 0
                        let timestamp = Date(timeIntervalSince1970: historyTimestamp)

                        print("    ✅ Using history from \(timestamp) - condition: \(condition.rawValue), pain: \(currentPainLevel)")

                        var procedures: [ToothProcedure] = []
                        if let proceduresData = data["procedures"] as? [[String: Any]] {
                            procedures = proceduresData.compactMap { procData in
                                guard let typeString = procData["type"] as? String,
                                      let type = ProcedureType(rawValue: typeString),
                                      let dateTimestamp = procData["date"] as? TimeInterval else {
                                    return nil
                                }

                                return ToothProcedure(
                                    type: type,
                                    date: Date(timeIntervalSince1970: dateTimestamp),
                                    notes: procData["notes"] as? String
                                )
                            }
                        }

                        let status = ToothStatus(
                            toothNumber: toothNumber,
                            condition: condition,
                            procedures: procedures,
                            currentPainLevel: currentPainLevel,
                            lastUpdated: timestamp
                        )

                        statuses[toothNumber] = status
                    } else {
                        if let toothDoc = toothDocsSnapshot.documents.first(where: { ($0.data()["toothNumber"] as? Int) == toothNumber }) {
                            let currentData = toothDoc.data()
                            if let lastUpdated = currentData["lastUpdated"] as? TimeInterval,
                               lastUpdated <= targetTimestamp {
                                let condition = ToothCondition(rawValue: currentData["condition"] as? String ?? "healthy") ?? .healthy
                                let currentPainLevel = currentData["currentPainLevel"] as? Double ?? 0

                                print("    ⚠️ No history, but current status from \(Date(timeIntervalSince1970: lastUpdated)) is before target - using it")

                                var procedures: [ToothProcedure] = []
                                if let proceduresData = currentData["procedures"] as? [[String: Any]] {
                                    procedures = proceduresData.compactMap { procData in
                                        guard let typeString = procData["type"] as? String,
                                              let type = ProcedureType(rawValue: typeString),
                                              let dateTimestamp = procData["date"] as? TimeInterval else {
                                            return nil
                                        }

                                        return ToothProcedure(
                                            type: type,
                                            date: Date(timeIntervalSince1970: dateTimestamp),
                                            notes: procData["notes"] as? String
                                        )
                                    }
                                }

                                let status = ToothStatus(
                                    toothNumber: toothNumber,
                                    condition: condition,
                                    procedures: procedures,
                                    currentPainLevel: currentPainLevel,
                                    lastUpdated: Date(timeIntervalSince1970: lastUpdated)
                                )

                                statuses[toothNumber] = status
                            } else {
                                print("    ❌ No history and current status is after target date - tooth didn't exist yet")
                            }
                        }
                    }
                }
            }

            print("✅ Loaded \(statuses.count) historical tooth statuses for \(date)")
            toothStatusesCache[cacheKey] = CacheEntry(data: statuses, timestamp: Date())
            print("💾 Cached tooth statuses for \(cacheKey)")
            return statuses
        } else {
            
            let snapshot = try await db.collection("users").document(uid)
                .collection("toothStatuses")
                .getDocuments()

            var statuses: [Int: ToothStatus] = [:]

            for document in snapshot.documents {
                let data = document.data()

                guard let toothNumber = data["toothNumber"] as? Int else { continue }

                let condition = ToothCondition(rawValue: data["condition"] as? String ?? "healthy") ?? .healthy
                let currentPainLevel = data["currentPainLevel"] as? Double ?? 0
                let lastUpdated = Date(timeIntervalSince1970: data["lastUpdated"] as? TimeInterval ?? Date().timeIntervalSince1970)

                var procedures: [ToothProcedure] = []
                if let proceduresData = data["procedures"] as? [[String: Any]] {
                    procedures = proceduresData.compactMap { procData in
                        guard let typeString = procData["type"] as? String,
                              let type = ProcedureType(rawValue: typeString),
                              let dateTimestamp = procData["date"] as? TimeInterval else {
                            return nil
                        }

                        return ToothProcedure(
                            type: type,
                            date: Date(timeIntervalSince1970: dateTimestamp),
                            notes: procData["notes"] as? String
                        )
                    }
                }

                let status = ToothStatus(
                    toothNumber: toothNumber,
                    condition: condition,
                    procedures: procedures,
                    currentPainLevel: currentPainLevel,
                    lastUpdated: lastUpdated
                )

                statuses[toothNumber] = status
            }

            print("✅ Loaded \(statuses.count) current tooth statuses")
            toothStatusesCache[cacheKey] = CacheEntry(data: statuses, timestamp: Date())
            print("💾 Cached current tooth statuses for \(cacheKey)")
            return statuses
        }
    }
    
    
    func saveInsuranceCard(_ card: InsuranceCard, for uid: String) async throws {
        let db = Firestore.firestore()
        let storage = Storage.storage()

        var cardImageURL: String? = card.cardImageURL

        
        if let imageData = card.cardImageData {
            let storageRef = storage.reference(withPath: "users/\(uid)/insuranceCard/\(card.id.uuidString).jpg")

            let metadata = StorageMetadata()
            metadata.contentType = "image/jpeg"

            _ = try await storageRef.putDataAsync(imageData, metadata: metadata)
            cardImageURL = try await storageRef.downloadURL().absoluteString

            print("✅ Uploaded insurance card image to Firebase Storage")
        }

        let cardData: [String: Any] = [
            "providerName": card.providerName,
            "memberId": card.memberId,
            "groupNumber": card.groupNumber as Any? ?? NSNull(),
            "policyHolderName": card.policyHolderName,
            "planType": card.planType as Any? ?? NSNull(),
            "customerServicePhone": card.customerServicePhone as Any? ?? NSNull(),
            "coveragePreventive": card.coveragePreventive as Any? ?? NSNull(),
            "coverageBasic": card.coverageBasic as Any? ?? NSNull(),
            "coverageMajor": card.coverageMajor as Any? ?? NSNull(),
            "annualMaximum": card.annualMaximum as Any? ?? NSNull(),
            "deductible": card.deductible as Any? ?? NSNull(),
            "cardImageURL": cardImageURL as Any? ?? NSNull(),
            "createdAt": card.createdAt.timeIntervalSince1970,
            "lastUpdated": card.lastUpdated.timeIntervalSince1970
        ]

        try await db.collection("users").document(uid)
            .collection("insuranceCards").document(card.id.uuidString)
            .setData(cardData)

        print("✅ Saved insurance card for user \(uid)")
    }

    func loadInsuranceCard(for uid: String) async throws -> InsuranceCard? {
        let db = Firestore.firestore()

        let snapshot = try await db.collection("users").document(uid)
            .collection("insuranceCards")
            .order(by: "lastUpdated", descending: true)
            .limit(to: 1)
            .getDocuments()

        guard let document = snapshot.documents.first else {
            print("ℹ️ No insurance card found for user")
            return nil
        }

        let data = document.data()
        guard let idString = document.documentID as String?,
              let id = UUID(uuidString: idString),
              let providerName = data["providerName"] as? String,
              let memberId = data["memberId"] as? String,
              let policyHolderName = data["policyHolderName"] as? String else {
            print("⚠️ Invalid insurance card data")
            return nil
        }

        let card = InsuranceCard(
            id: id,
            providerName: providerName,
            memberId: memberId,
            groupNumber: data["groupNumber"] as? String,
            policyHolderName: policyHolderName,
            planType: data["planType"] as? String,
            customerServicePhone: data["customerServicePhone"] as? String,
            coveragePreventive: data["coveragePreventive"] as? Int,
            coverageBasic: data["coverageBasic"] as? Int,
            coverageMajor: data["coverageMajor"] as? Int,
            annualMaximum: data["annualMaximum"] as? Double,
            deductible: data["deductible"] as? Double,
            cardImageURL: data["cardImageURL"] as? String,
            createdAt: Date(timeIntervalSince1970: data["createdAt"] as? TimeInterval ?? Date().timeIntervalSince1970),
            lastUpdated: Date(timeIntervalSince1970: data["lastUpdated"] as? TimeInterval ?? Date().timeIntervalSince1970)
        )

        print("✅ Loaded insurance card for user \(uid)")
        return card
    }

    func deleteInsuranceCard(_ card: InsuranceCard, for uid: String) async throws {
        let db = Firestore.firestore()
        let storage = Storage.storage()

        
        if let imageURL = card.cardImageURL {
            let storageRef = storage.reference(forURL: imageURL)
            try? await storageRef.delete()
            print("✅ Deleted insurance card image from Storage")
        }

        
        try await db.collection("users").document(uid)
            .collection("insuranceCards").document(card.id.uuidString)
            .delete()

        print("✅ Deleted insurance card from Firestore")
    }

    
    func saveChewCheckResult(_ result: ChewCheckResult, for uid: String) async throws {
        
        print("Saving ChewCheck result for \(result.foodName), user: \(uid)")
    }
    
    func getChewCheckHistory(for uid: String) async throws -> [ChewCheckResult] {
        
        return []
    }
    
    
    func saveAppointment(_ appointment: Appointment, for uid: String) async throws {
        let db = Firestore.firestore()

        let appointmentData: [String: Any] = [
            "id": appointment.id.uuidString,
            "date": appointment.date.timeIntervalSince1970,
            "title": appointment.title,
            "dentistName": appointment.dentistName ?? NSNull(),
            "notes": appointment.notes ?? NSNull(),
            "location": appointment.location ?? NSNull(),
            "isCompleted": appointment.isCompleted,
            "isAllDay": appointment.isAllDay
        ]

        try await db.collection("users").document(uid)
            .collection("appointments").document(appointment.id.uuidString)
            .setData(appointmentData)

        invalidateAppointmentsCache(uid: uid)

        print("✅ Saved appointment to Firebase: \(appointment.title)")
    }

    func getAppointments(for uid: String) async throws -> [Appointment] {
        return try await loadAppointments(for: uid)
    }

    func loadAppointments(for uid: String) async throws -> [Appointment] {
        if let cached = appointmentsCache[uid], cached.isValid(ttl: cacheTTL) {
            print("📦 Using cached appointments for \(uid)")
            return cached.data
        }

        let db = Firestore.firestore()
        let snapshot = try await db.collection("users").document(uid)
            .collection("appointments")
            .order(by: "date", descending: false)
            .getDocuments()

        var appointments: [Appointment] = []
        for document in snapshot.documents {
            let data = document.data()
            guard let dateTimestamp = data["date"] as? TimeInterval,
                  let title = data["title"] as? String else {
                continue
            }


            let appointmentId = UUID(uuidString: document.documentID) ?? UUID()
            let appointment = Appointment(
                id: appointmentId,
                date: Date(timeIntervalSince1970: dateTimestamp),
                title: title,
                dentistName: data["dentistName"] as? String,
                notes: data["notes"] as? String,
                location: data["location"] as? String,
                isCompleted: data["isCompleted"] as? Bool ?? false,
                isAllDay: data["isAllDay"] as? Bool ?? false
            )
            print("  📅 Loaded appointment: \(appointment.title) (ID: \(appointmentId.uuidString))")
            appointments.append(appointment)
        }

        print("✅ Loaded \(appointments.count) appointments from Firebase")
        appointmentsCache[uid] = CacheEntry(data: appointments, timestamp: Date())
        print("💾 Cached appointments for \(uid)")
        return appointments
    }

    func saveDentalSummary(_ summary: DentalSummary, for uid: String) async throws {
        let db = Firestore.firestore()

        let summaryData: [String: Any] = [
            "teethInPain": summary.teethInPain,
            "painfulTeeth": summary.painfulTeeth,
            "activeTreatments": summary.activeTreatments,
            "upcomingAppointments": summary.upcomingAppointments,
            "nextAppointmentDate": summary.nextAppointmentDate?.timeIntervalSince1970 ?? NSNull(),
            "activeMedications": summary.activeMedications,
            "activeRestrictions": summary.activeRestrictions,
            "lastUpdated": summary.lastUpdated.timeIntervalSince1970,
            "summary": summary.summary
        ]

        try await db.collection("users").document(uid)
            .collection("dentalSummary").document("current")
            .setData(summaryData)

        print("✅ Saved dental summary for \(uid)")
    }

    func loadDentalSummary(for uid: String) async throws -> DentalSummary? {
        let db = Firestore.firestore()

        let document = try await db.collection("users").document(uid)
            .collection("dentalSummary").document("current")
            .getDocument()

        guard document.exists, let data = document.data() else {
            return nil
        }

        var summary = DentalSummary()
        summary.teethInPain = data["teethInPain"] as? Int ?? 0
        summary.painfulTeeth = data["painfulTeeth"] as? [Int] ?? []
        summary.activeTreatments = data["activeTreatments"] as? Int ?? 0
        summary.upcomingAppointments = data["upcomingAppointments"] as? Int ?? 0
        summary.activeMedications = data["activeMedications"] as? Int ?? 0
        summary.activeRestrictions = data["activeRestrictions"] as? Int ?? 0
        summary.summary = data["summary"] as? String ?? ""

        if let nextApptTimestamp = data["nextAppointmentDate"] as? TimeInterval {
            summary.nextAppointmentDate = Date(timeIntervalSince1970: nextApptTimestamp)
        }

        if let lastUpdatedTimestamp = data["lastUpdated"] as? TimeInterval {
            summary.lastUpdated = Date(timeIntervalSince1970: lastUpdatedTimestamp)
        }

        print("✅ Loaded dental summary for \(uid)")
        return summary
    }

    func saveActivity(_ activity: RecentActivity, for uid: String) async throws {
        let db = Firestore.firestore()

        var activityData: [String: Any] = [
            "id": activity.id.uuidString,
            "date": activity.date,
            "description": activity.description,
            "type": activity.type.rawValue,
            "timestamp": activity.timestamp.timeIntervalSince1970
        ]

        if let foodName = activity.foodName {
            activityData["foodName"] = foodName
        }
        if let toothNumber = activity.toothNumber {
            activityData["toothNumber"] = toothNumber
        }
        if let documentId = activity.documentId {
            activityData["documentId"] = documentId
        }
        if let metadata = activity.metadata {
            activityData["metadata"] = metadata
        }

        try await db.collection("users").document(uid)
            .collection("activities").document(activity.id.uuidString)
            .setData(activityData)

        print("✅ Saved activity: \(activity.description)")
    }

    func loadActivities(for uid: String, limit: Int = 5) async throws -> [RecentActivity] {
        let db = Firestore.firestore()

        let snapshot = try await db.collection("users").document(uid)
            .collection("activities")
            .order(by: "timestamp", descending: true)
            .limit(to: limit)
            .getDocuments()

        var activities: [RecentActivity] = []
        for document in snapshot.documents {
            let data = document.data()

            guard let date = data["date"] as? String,
                  let description = data["description"] as? String,
                  let typeString = data["type"] as? String,
                  let type = ActivityType(rawValue: typeString),
                  let timestampValue = data["timestamp"] as? TimeInterval else {
                continue
            }

            let activityId = UUID(uuidString: document.documentID) ?? UUID()

            var activity = RecentActivity(
                id: activityId,
                date: date,
                description: description,
                type: type,
                timestamp: Date(timeIntervalSince1970: timestampValue)
            )

            activity.foodName = data["foodName"] as? String
            activity.toothNumber = data["toothNumber"] as? Int
            activity.documentId = data["documentId"] as? String
            activity.metadata = data["metadata"] as? [String: String]

            activities.append(activity)
        }

        print("✅ Loaded \(activities.count) activities for \(uid)")
        return activities
    }

    func generateDentalSummary(for uid: String) async throws -> DentalSummary {
        async let painEntries = getPainEntries(for: uid, on: nil)
        async let toothStatuses = getToothStatuses(for: uid, on: nil)
        async let appointments = loadAppointments(for: uid)
        async let treatmentPlan = loadTreatmentPlan(for: uid)

        let (loadedPainEntries, loadedToothStatuses, loadedAppointments, loadedTreatmentPlan) = try await (painEntries, toothStatuses, appointments, treatmentPlan)

        var summary = DentalSummary()

        let painfulTeeth = loadedPainEntries.filter { $0.value.painLevel > 0 }
        summary.teethInPain = painfulTeeth.count
        summary.painfulTeeth = Array(painfulTeeth.keys).sorted()

        let futureAppointments = loadedAppointments.filter { $0.date > Date() && !$0.isCompleted }
        summary.upcomingAppointments = futureAppointments.count
        summary.nextAppointmentDate = futureAppointments.first?.date

        summary.activeMedications = loadedTreatmentPlan.medications.filter {
            if let endDate = $0.endDate {
                return endDate > Date()
            }
            return true
        }.count

        summary.activeRestrictions = loadedTreatmentPlan.restrictions.filter {
            if let endDate = $0.endDate {
                return endDate > Date()
            }
            return true
        }.count

        summary.activeTreatments = summary.activeMedications + summary.activeRestrictions

        var summaryText = ""
        if summary.teethInPain > 0 {
            summaryText += "\(summary.teethInPain) teeth with pain. "
        }
        if summary.activeTreatments > 0 {
            summaryText += "\(summary.activeTreatments) active treatments. "
        }
        if summary.upcomingAppointments > 0 {
            summaryText += "\(summary.upcomingAppointments) upcoming appointments."
        }
        if summaryText.isEmpty {
            summaryText = "All teeth healthy! Keep up the great work."
        }

        summary.summary = summaryText.trimmingCharacters(in: .whitespaces)
        summary.lastUpdated = Date()

        try await saveDentalSummary(summary, for: uid)

        return summary
    }


    func saveScannedNoteData(
        parsedData: ParsedDentalNotes,
        documentDate: Date?,
        for uid: String
    ) async throws {
        let db = Firestore.firestore()

        
        let isCurrent: Bool
        if let docDate = documentDate {
            let monthsAgo = Calendar.current.dateComponents([.month], from: docDate, to: Date()).month ?? 0
            isCurrent = monthsAgo <= 3 
        } else {
            isCurrent = true 
        }

        print("📅 Document date: \(documentDate?.description ?? "unknown") - \(isCurrent ? "CURRENT" : "HISTORICAL")")

        
        print("\n📦 PARSED DATA SUMMARY:")
        print("  - Treatment Plan: \(parsedData.treatmentPlan != nil ? "YES" : "NO")")
        print("  - Post-Op Instructions: \(parsedData.postOpInstructions != nil ? "YES" : "NO")")
        print("  - Appointments: \(parsedData.appointments.count)")
        print("  - Medications: \(parsedData.medications.count)")
        print("  - Diet Restrictions: \(parsedData.dietRestrictions.count)")
        print("  - Procedures: \(parsedData.procedures.count)")
        print("  - General Notes: \(parsedData.generalNotes != nil ? "YES" : "NO")")

        
        let metadata: [String: Any] = [
            "scannedAt": Date().timeIntervalSince1970,
            "documentDate": documentDate?.timeIntervalSince1970 ?? NSNull(),
            "isCurrent": isCurrent
        ]

        let documentRef = db.collection("users").document(uid)
            .collection("scannedNotes").document()

        try await documentRef.setData(metadata)
        let docId = documentRef.documentID
        print("\n💾 Created scanned note document: \(docId)")

        
        var consolidatedNote = ""
        var noteTitle = "Scanned Document"

        
        if let treatmentPlan = parsedData.treatmentPlan {
            
            let mainTreatment = treatmentPlan.description.split(separator: " ").prefix(3).joined(separator: " ")
            noteTitle = mainTreatment.isEmpty ? "Treatment Plan" : String(mainTreatment)
        } else if !parsedData.procedures.isEmpty {
            
            let firstProcedure = parsedData.procedures[0]
            noteTitle = firstProcedure.type.capitalized
            if let toothNumbers = firstProcedure.toothNumbers, !toothNumbers.isEmpty {
                noteTitle += " - Tooth #\(toothNumbers.map { String($0) }.joined(separator: ", #"))"
            }
        } else if !parsedData.appointments.isEmpty {
            
            noteTitle = "Dental Appointment"
        }

        
        if let docDateStr = parsedData.documentDate {
            consolidatedNote += "Document Date: \(docDateStr)\n\n"
        }

        
        if isCurrent, let treatmentPlan = parsedData.treatmentPlan {
            consolidatedNote += "Treatment Plan:\n"
            consolidatedNote += treatmentPlan.description + "\n"
            if let duration = treatmentPlan.duration {
                consolidatedNote += "Duration: \(duration)\n"
            }
            if !treatmentPlan.goals.isEmpty {
                consolidatedNote += "Goals:\n"
                consolidatedNote += treatmentPlan.goals.map { "• \($0)" }.joined(separator: "\n") + "\n"
            }
            consolidatedNote += "\n"
        }


        if isCurrent && !parsedData.medications.isEmpty {
            print("\n💊 Saving \(parsedData.medications.count) medications...")
            try await withThrowingTaskGroup(of: Void.self) { group in
                for medication in parsedData.medications {
                    group.addTask {
                        print("  - \(medication.name) \(medication.dosage)")
                        try await self.saveMedication(medication, for: uid, documentId: docId)
                    }
                }
                try await group.waitForAll()
            }
            print("  ✅ All medications saved")
        } else if !isCurrent && !parsedData.medications.isEmpty {
            print("\n⏸️ Skipping \(parsedData.medications.count) medications (document is historical)")
        }

        if isCurrent && !parsedData.dietRestrictions.isEmpty {
            print("\n🥗 Saving \(parsedData.dietRestrictions.count) diet restrictions...")
            try await withThrowingTaskGroup(of: Void.self) { group in
                for restriction in parsedData.dietRestrictions {
                    group.addTask {
                        print("  - \(restriction.type)")
                        try await self.saveDietRestriction(restriction, for: uid, documentId: docId)
                    }
                }
                try await group.waitForAll()
            }
            print("  ✅ All restrictions saved")
        } else if !isCurrent && !parsedData.dietRestrictions.isEmpty {
            print("\n⏸️ Skipping \(parsedData.dietRestrictions.count) diet restrictions (document is historical)")
        }

        print("\n📋 Saving \(parsedData.procedures.count) procedures to Firebase...")
        try await withThrowingTaskGroup(of: Void.self) { group in
            for (index, procedure) in parsedData.procedures.enumerated() {
                group.addTask {
                    print("  Procedure \(index + 1): \(procedure.type) - Teeth: \(procedure.toothNumbers ?? []) - Date: \(procedure.date ?? "unknown")")
                    try await self.saveProcedure(procedure, for: uid, documentId: docId)
                }
            }
            try await group.waitForAll()
        }
        print("✅ All procedures saved")


        if !parsedData.appointments.isEmpty {
            print("\n📅 Saving \(parsedData.appointments.count) appointments...")
            try await withThrowingTaskGroup(of: Void.self) { group in
                for parsedAppt in parsedData.appointments {
                    group.addTask {
                        if let date = await self.parseDateStringToDate(parsedAppt.date) {
                            let isAllDay = !parsedAppt.date.contains(":")

                            let appointment = Appointment(
                                date: date,
                                title: "Dental Appointment",
                                dentistName: parsedAppt.dentistName,
                                notes: parsedAppt.notes,
                                location: parsedAppt.location,
                                isCompleted: false,
                                isAllDay: isAllDay
                            )
                            print("  - Dental Appointment on \(parsedAppt.date) \(isAllDay ? "(All Day)" : "")")
                            try await self.saveAppointment(appointment, for: uid)

                            do {
                                try await CalendarService.shared.addAppointmentToCalendar(appointment: appointment)
                                print("    ✅ Added to device calendar")
                            } catch {
                                print("    ⚠️ Could not add to calendar: \(error.localizedDescription)")
                            }
                        } else {
                            print("  ⚠️ Could not parse date for appointment: \(parsedAppt.date)")
                        }
                    }
                }
                try await group.waitForAll()
            }
            print("  ✅ All appointments saved")
        }

        
        if !parsedData.procedures.isEmpty {
            consolidatedNote += "Procedures:\n"
            for procedure in parsedData.procedures {
                consolidatedNote += "• \(procedure.type)"
                if let toothNumbers = procedure.toothNumbers, !toothNumbers.isEmpty {
                    consolidatedNote += " (Teeth: \(toothNumbers.map { "#\($0)" }.joined(separator: ", ")))"
                }
                if let date = procedure.date {
                    consolidatedNote += " - \(date)"
                }
                if let notes = procedure.notes, !notes.isEmpty {
                    consolidatedNote += "\n  \(notes)"
                }
                consolidatedNote += "\n"
            }
            consolidatedNote += "\n"
        }

        
        if !parsedData.appointments.isEmpty {
            consolidatedNote += "Appointments:\n"
            for appointment in parsedData.appointments {
                consolidatedNote += "• \(appointment.title) - \(appointment.date)\n"
                if let location = appointment.location {
                    consolidatedNote += "  Location: \(location)\n"
                }
            }
            consolidatedNote += "\n"
        }

        
        if isCurrent && !parsedData.medications.isEmpty {
            consolidatedNote += "Medications:\n"
            for medication in parsedData.medications {
                consolidatedNote += "• \(medication.name) \(medication.dosage) - \(medication.frequency)\n"
            }
            consolidatedNote += "\n"
        }

        
        if isCurrent, let postOp = parsedData.postOpInstructions {
            consolidatedNote += "Post-Op Instructions:\n"
            consolidatedNote += postOp.instructions.map { "• \($0)" }.joined(separator: "\n") + "\n"
            if !postOp.warnings.isEmpty {
                consolidatedNote += "\nWarnings:\n"
                consolidatedNote += postOp.warnings.map { "⚠️ \($0)" }.joined(separator: "\n") + "\n"
            }
            consolidatedNote += "\n"
        }

        
        if let generalNotes = parsedData.generalNotes, !generalNotes.isEmpty {
            consolidatedNote += "Additional Notes:\n"
            consolidatedNote += generalNotes + "\n"
        }

        
        if !consolidatedNote.isEmpty {
            print("\n📝 Saving consolidated doctor note: \"\(noteTitle)\"...")
            let note = DoctorNote(content: consolidatedNote.trimmingCharacters(in: .whitespacesAndNewlines), source: .scanned)
            try await saveDoctorNoteWithTitle(note, title: noteTitle, for: uid, documentId: docId)
            print("  ✅ Consolidated note saved")
        }

        print("\n" + String(repeating: "=", count: 50))
        print("✅ SUCCESSFULLY SAVED ALL DATA TO FIREBASE")
        print("   Document Status: \(isCurrent ? "CURRENT" : "HISTORICAL")")
        print("   Document ID: \(docId)")
        print(String(repeating: "=", count: 50) + "\n")
    }

    private func saveDoctorNote(_ note: DoctorNote, for uid: String, documentId: String) async throws {
        let db = Firestore.firestore()
        let noteData: [String: Any] = [
            "id": note.id.uuidString,
            "title": note.title ?? NSNull(),
            "content": note.content,
            "createdAt": note.createdAt.timeIntervalSince1970,
            "source": note.source.rawValue,
            "scannedDocumentId": documentId
        ]
        try await db.collection("users").document(uid)
            .collection("doctorNotes").document(note.id.uuidString)
            .setData(noteData)
        invalidateTreatmentPlanCache(uid: uid)
    }

    private func saveDoctorNoteWithTitle(_ note: DoctorNote, title: String, for uid: String, documentId: String) async throws {
        let db = Firestore.firestore()
        let noteData: [String: Any] = [
            "id": note.id.uuidString,
            "title": title,
            "content": note.content,
            "createdAt": note.createdAt.timeIntervalSince1970,
            "source": note.source.rawValue,
            "scannedDocumentId": documentId
        ]
        try await db.collection("users").document(uid)
            .collection("doctorNotes").document(note.id.uuidString)
            .setData(noteData)
        invalidateTreatmentPlanCache(uid: uid)
    }

    func deleteDoctorNote(_ note: DoctorNote, for uid: String) async throws {
        let db = Firestore.firestore()

        let documentPath = "users/\(uid)/doctorNotes/\(note.id.uuidString)"
        print("🗑️ Deleting doctor note from path: \(documentPath)")
        print("   Title: \(note.title ?? "No title")")

        try await db.collection("users").document(uid)
            .collection("doctorNotes").document(note.id.uuidString)
            .delete()

        print("✅ Successfully deleted doctor note from Firebase")
        print("   Document ID: \(note.id.uuidString)")
    }

    func deleteAppointment(_ appointment: Appointment, for uid: String) async throws {
        let db = Firestore.firestore()

        let documentPath = "users/\(uid)/appointments/\(appointment.id.uuidString)"
        print("🗑️ Deleting appointment from path: \(documentPath)")
        print("   Title: \(appointment.title)")

        try await db.collection("users").document(uid)
            .collection("appointments").document(appointment.id.uuidString)
            .delete()

        print("✅ Successfully deleted appointment from Firebase")
        print("   Document ID: \(appointment.id.uuidString)")
    }

    func deleteMedication(medicationId: String, for uid: String) async throws {
        let db = Firestore.firestore()

        let documentPath = "users/\(uid)/medications/\(medicationId)"
        print("🗑️ Deleting medication from path: \(documentPath)")

        try await db.collection("users").document(uid)
            .collection("medications").document(medicationId)
            .delete()

        print("✅ Successfully deleted medication from Firebase")
    }

    func deleteDietRestriction(restrictionId: String, for uid: String) async throws {
        let db = Firestore.firestore()

        let documentPath = "users/\(uid)/dietRestrictions/\(restrictionId)"
        print("🗑️ Deleting diet restriction from path: \(documentPath)")

        try await db.collection("users").document(uid)
            .collection("dietRestrictions").document(restrictionId)
            .delete()

        print("✅ Successfully deleted diet restriction from Firebase")
    }

    private func saveMedication(_ parsedMed: ParsedMedication, for uid: String, documentId: String) async throws {
        let db = Firestore.firestore()
        let endDate = parseDateString(parsedMed.duration)
        let medicationData: [String: Any] = [
            "name": parsedMed.name,
            "dosage": parsedMed.dosage,
            "frequency": parsedMed.frequency,
            "endDate": endDate?.timeIntervalSince1970 ?? NSNull(),
            "instructions": parsedMed.instructions ?? NSNull(),
            "scannedDocumentId": documentId,
            "createdAt": Date().timeIntervalSince1970
        ]
        try await db.collection("users").document(uid)
            .collection("medications").document()
            .setData(medicationData)
        invalidateTreatmentPlanCache(uid: uid)
    }

    private func saveDietRestriction(_ parsedRestriction: ParsedDietRestriction, for uid: String, documentId: String) async throws {
        guard let type = RestrictionType.from(string: parsedRestriction.type) else { return }
        let db = Firestore.firestore()
        let endDate = parseDateString(parsedRestriction.duration)
        let restrictionData: [String: Any] = [
            "type": type.rawValue,
            "endDate": endDate?.timeIntervalSince1970 ?? NSNull(),
            "reason": parsedRestriction.reason ?? NSNull(),
            "scannedDocumentId": documentId,
            "createdAt": Date().timeIntervalSince1970
        ]
        try await db.collection("users").document(uid)
            .collection("dietRestrictions").document()
            .setData(restrictionData)
        invalidateTreatmentPlanCache(uid: uid)
    }

    private func saveProcedure(_ parsedProc: ParsedProcedure, for uid: String, documentId: String) async throws {
        guard let type = ProcedureType.from(string: parsedProc.type) else {
            print("⚠️ Could not map procedure type '\(parsedProc.type)' to ProcedureType enum - SKIPPING")
            return
        }

        let db = Firestore.firestore()

        
        var procedureDate: Double? = nil
        if let dateStr = parsedProc.date {
            if let date = parseDateStringToDate(dateStr) {
                procedureDate = date.timeIntervalSince1970
            }
        }

        let procedureData: [String: Any] = [
            "type": type.rawValue,
            "toothNumbers": parsedProc.toothNumbers ?? [],
            "date": parsedProc.date ?? "",
            "procedureDate": procedureDate ?? NSNull(),
            "notes": parsedProc.notes ?? "",
            "scannedDocumentId": documentId,
            "recordedAt": Date().timeIntervalSince1970
        ]

        let docRef = db.collection("users").document(uid)
            .collection("procedures").document()

        try await docRef.setData(procedureData)

        print("    ✅ Saved procedure \(type.rawValue) (doc ID: \(docRef.documentID))")

        
        if let toothNumbers = parsedProc.toothNumbers, !toothNumbers.isEmpty {
            for toothNum in toothNumbers {
                try await updateToothStatusWithProcedure(
                    toothNumber: toothNum,
                    procedureType: type,
                    procedureDate: procedureDate != nil ? Date(timeIntervalSince1970: procedureDate!) : Date(),
                    notes: parsedProc.notes,
                    for: uid
                )
            }
        }
    }

    
    private func updateToothStatusWithProcedure(
        toothNumber: Int,
        procedureType: ProcedureType,
        procedureDate: Date,
        notes: String?,
        for uid: String
    ) async throws {
        let db = Firestore.firestore()
        let toothRef = db.collection("users").document(uid)
            .collection("toothStatus").document("\(toothNumber)")

        
        let toothDoc = try? await toothRef.getDocument()
        var procedures: [[String: Any]] = []

        if let toothDoc = toothDoc, toothDoc.exists,
           let existingProcedures = toothDoc.data()?["procedures"] as? [[String: Any]] {
            procedures = existingProcedures
        }

        
        let newProcedure: [String: Any] = [
            "id": UUID().uuidString,
            "type": procedureType.rawValue,
            "date": procedureDate.timeIntervalSince1970,
            "notes": notes ?? ""
        ]
        procedures.append(newProcedure)

        
        var condition = ToothCondition.healthy.rawValue
        switch procedureType {
        case .filling:
            condition = ToothCondition.filling.rawValue
        case .crown:
            condition = ToothCondition.crown.rawValue
        case .rootCanal:
            condition = ToothCondition.rootCanal.rawValue
        case .implant:
            condition = ToothCondition.implant.rawValue
        case .extraction:
            condition = ToothCondition.missing.rawValue
        case .cleaning:
            condition = ToothCondition.healthy.rawValue
        }

        let toothData: [String: Any] = [
            "toothNumber": toothNumber,
            "condition": condition,
            "procedures": procedures,
            "lastUpdated": Date().timeIntervalSince1970
        ]

        try await toothRef.setData(toothData, merge: true)
        print("      🦷 Updated tooth #\(toothNumber) status with \(procedureType.rawValue)")
    }

    private func parseDateString(_ dateString: String?) -> Date? {
        guard let dateString = dateString else { return nil }
        let components = dateString.lowercased().components(separatedBy: " ")
        if let numberIndex = components.firstIndex(where: { Int($0) != nil }),
           let number = Int(components[numberIndex]),
           numberIndex + 1 < components.count {
            let unit = components[numberIndex + 1]
            if unit.contains("day") {
                return Calendar.current.date(byAdding: .day, value: number, to: Date())
            } else if unit.contains("week") {
                return Calendar.current.date(byAdding: .weekOfYear, value: number, to: Date())
            } else if unit.contains("month") {
                return Calendar.current.date(byAdding: .month, value: number, to: Date())
            }
        }
        return nil
    }

    private func parseDateStringToDate(_ dateString: String) -> Date? {
        let formatter = DateFormatter()

        
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        if let date = formatter.date(from: dateString) {
            return date
        }

        
        formatter.dateFormat = "yyyy-MM-dd"
        if let date = formatter.date(from: dateString) {
            return date
        }

        
        formatter.dateFormat = "MM/dd/yyyy"
        if let date = formatter.date(from: dateString) {
            return date
        }

        
        formatter.dateFormat = "MMM dd, yyyy"
        if let date = formatter.date(from: dateString) {
            return date
        }

        return nil
    }
}


enum AuthError: Error, LocalizedError {
    case noRootViewController
    case noClientID
    case noIDToken
    
    var errorDescription: String? {
        switch self {
        case .noRootViewController:
            return "Could not find root view controller for Google Sign-In"
        case .noClientID:
            return "Firebase client ID not found"
        case .noIDToken:
            return "Google Sign-In did not return an ID token"
        }
    }
}
