//
//  FirebaseService.swift
//  BrightBite
//
//  Created by Tuan Nguyen on 9/1/25.
//
//  FIREBASE SECURITY RULES - Deploy these rules to Firebase Console:
//
//  ============ FIRESTORE RULES ============
//  (Deploy to: Firebase Console → Firestore Database → Rules)
//
//  rules_version = '2';
//  
//  service cloud.firestore {
//    match /databases/{database}/documents {
//      
//      // Users can only access their own data
//      match /users/{userId} {
//        allow read, write: if request.auth != null && request.auth.uid == userId;
//        
//        // User profile
//        match /profile/{document} {
//          allow read, write: if request.auth != null && request.auth.uid == userId;
//        }
//        
//        // Treatment plan
//        match /plan/{document} {
//          allow read, write: if request.auth != null && request.auth.uid == userId;
//        }
//        
//        // Pain map data
//        match /painmap/{document} {
//          allow read, write: if request.auth != null && request.auth.uid == userId;
//        }
//        
//        // ChewCheck history
//        match /chewcheck/{document} {
//          allow read, write: if request.auth != null && request.auth.uid == userId;
//        }
//        
//        // Appointments
//        match /appointments/{document} {
//          allow read, write: if request.auth != null && request.auth.uid == userId;
//        }
//        
//        // Medical history
//        match /history/{document} {
//          allow read, write: if request.auth != null && request.auth.uid == userId;
//        }
//        
//        // Chat messages (if storing chat history)
//        match /chat/{document} {
//          allow read, write: if request.auth != null && request.auth.uid == userId;
//        }
//      }
//      
//      // Deny all other access
//      match /{document=**} {
//        allow read, write: if false;
//      }
//    }
//  }
//
//  ============ STORAGE RULES ============
//  (Deploy to: Firebase Console → Storage → Rules)
//
//  rules_version = '2';
//  
//  // Firebase Storage security rules for BrightBite
//  service firebase.storage {
//    match /b/{bucket}/o {
//      
//      // Users can only access their own files
//      match /users/{userId}/{allPaths=**} {
//        allow read, write: if request.auth != null && request.auth.uid == userId;
//      }
//      
//      // ChewCheck food photos (user-specific)
//      match /chewcheck/{userId}/{allPaths=**} {
//        allow read, write: if request.auth != null && request.auth.uid == userId
//                           && resource.size < 10 * 1024 * 1024  // Max 10MB
//                           && resource.contentType.matches('image/.*');
//      }
//      
//      // Scanned dentist notes (user-specific)
//      match /notes/{userId}/{allPaths=**} {
//        allow read, write: if request.auth != null && request.auth.uid == userId
//                           && resource.size < 20 * 1024 * 1024  // Max 20MB
//                           && (resource.contentType.matches('image/.*') || 
//                               resource.contentType == 'application/pdf');
//      }
//      
//      // Profile avatars (user-specific)
//      match /avatars/{userId}/{allPaths=**} {
//        allow read, write: if request.auth != null && request.auth.uid == userId
//                           && resource.size < 5 * 1024 * 1024   // Max 5MB
//                           && resource.contentType.matches('image/.*');
//      }
//      
//      // Deny all other access
//      match /{allPaths=**} {
//        allow read, write: if false;
//      }
//    }
//  }

import Foundation
import Combine

// TODO: Uncomment when Firebase is added
// import FirebaseAuth
// import FirebaseFirestore
// import FirebaseStorage

// Firebase service - switches between mock and real Firebase based on configuration
class FirebaseService: ObservableObject {
    
    // Configuration flag - set to true when Firebase is properly set up
    private let useFirebase = false // TODO: Change to true when Firebase is configured
    static let shared = FirebaseService()
    
    @Published var currentUser: UserProfile?
    @Published var isAuthenticated = false
    
    private init() {}
    
    // MARK: - Authentication
    func signInAnonymously() async throws {
        if useFirebase {
            // TODO: Real Firebase implementation
            /*
            let result = try await Auth.auth().signInAnonymously()
            let firebaseUser = result.user
            
            let userProfile = UserProfile(
                id: firebaseUser.uid,
                name: nil,
                hasBraces: false
            )
            
            await MainActor.run {
                self.currentUser = userProfile
                self.isAuthenticated = true
            }
            */
        } else {
            // Mock implementation
            try await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
            
            let mockUser = UserProfile(
                id: UUID().uuidString,
                name: nil,
                hasBraces: false
            )
            
            await MainActor.run {
                self.currentUser = mockUser
                self.isAuthenticated = true
            }
        }
    }
    
    func signOut() {
        currentUser = nil
        isAuthenticated = false
    }
    
    // MARK: - User Profile
    func updateUserProfile(_ profile: UserProfile) async throws {
        // Simulate Firestore update
        await MainActor.run {
            self.currentUser = profile
        }
    }
    
    func getUserProfile(uid: String) async throws -> UserProfile? {
        // Simulate Firestore read
        return currentUser
    }
    
    // MARK: - Treatment Plan
    func saveTreatmentPlan(_ plan: TreatmentPlan, for uid: String) async throws {
        if useFirebase {
            // TODO: Real Firebase implementation
            /*
            let db = Firestore.firestore()
            try await db.collection("users").document(uid).collection("plan").document("treatment").setData([
                "restrictions": plan.restrictions.map { restriction in
                    [
                        "type": restriction.type.rawValue,
                        "endDate": restriction.endDate?.timeIntervalSince1970 ?? NSNull(),
                        "reason": restriction.reason ?? NSNull()
                    ]
                },
                "medications": plan.medications.map { med in
                    [
                        "name": med.name,
                        "dosage": med.dosage,
                        "frequency": med.frequency,
                        "endDate": med.endDate?.timeIntervalSince1970 ?? NSNull()
                    ]
                }
                // Add other plan fields as needed
            ])
            */
        } else {
            // Mock implementation
            print("Saving treatment plan for user: \(uid)")
        }
    }
    
    func getTreatmentPlan(for uid: String) async throws -> TreatmentPlan? {
        // Simulate Firestore read
        return nil
    }
    
    // MARK: - Pain Map
    func savePainEntry(_ entry: PainEntry, for uid: String) async throws {
        // Simulate Firestore save
        print("Saving pain entry for tooth \(entry.toothNumber), user: \(uid)")
    }
    
    func getPainEntries(for uid: String) async throws -> [PainEntry] {
        // Simulate Firestore read
        return []
    }
    
    // MARK: - ChewCheck Results
    func saveChewCheckResult(_ result: ChewCheckResult, for uid: String) async throws {
        // Simulate Firestore save
        print("Saving ChewCheck result for \(result.foodName), user: \(uid)")
    }
    
    func getChewCheckHistory(for uid: String) async throws -> [ChewCheckResult] {
        // Simulate Firestore read
        return []
    }
    
    // MARK: - Appointments
    func saveAppointment(_ appointment: Appointment, for uid: String) async throws {
        // Simulate Firestore save
        print("Saving appointment for user: \(uid)")
    }
    
    func getAppointments(for uid: String) async throws -> [Appointment] {
        // Simulate Firestore read
        return []
    }
}