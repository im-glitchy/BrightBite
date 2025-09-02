//
//  DataModels.swift
//  BrightBite
//
//  Created by Tuan Nguyen on 9/1/25.
//

import Foundation
import SwiftUI

// MARK: - User Profile
struct UserProfile: Codable, Identifiable {
    let id: String
    var name: String?
    var hasBraces: Bool = false
    var dentistInfo: DentistInfo?
    var createdAt: Date = Date()
}

struct DentistInfo: Codable {
    var name: String
    var phone: String?
    var email: String?
    var address: String?
}

// MARK: - Care Tasks
struct CareTask: Codable, Identifiable {
    let id = UUID()
    var title: String
    var isCompleted: Bool = false
    var dueDate: Date?
    var category: TaskCategory
}

enum TaskCategory: String, CaseIterable, Codable {
    case medication = "medication"
    case hygiene = "hygiene"
    case diet = "diet"
    case appliance = "appliance"
    case followup = "followup"
}

// MARK: - Recent Activity
struct RecentActivity: Codable, Identifiable {
    let id = UUID()
    let date: String
    let description: String
    let type: ActivityType
    let timestamp: Date = Date()
}

enum ActivityType: String, CaseIterable, Codable {
    case chewCheck = "chewCheck"
    case painLog = "painLog"
    case appointment = "appointment"
    case notesScan = "notesScan"
    case medication = "medication"
}

// MARK: - Treatment Plan
struct TreatmentPlan: Codable, Identifiable {
    let id = UUID()
    var restrictions: [DietRestriction]
    var currentTasks: [CareTask]
    var doctorNotes: [DoctorNote]
    var medications: [Medication]
    var alignerProgress: AlignerProgress?
}

struct DietRestriction: Codable, Identifiable {
    let id = UUID()
    var type: RestrictionType
    var endDate: Date?
    var reason: String?
}

enum RestrictionType: String, CaseIterable, Codable {
    case softOnly = "softOnly"
    case noHard = "noHard"
    case noSticky = "noSticky"
    case noChewy = "noChewy"
    case noHot = "noHot"
    case noCold = "noCold"
    case noSugary = "noSugary"
    case noAcidic = "noAcidic"
}

struct DoctorNote: Codable, Identifiable {
    let id = UUID()
    var content: String
    var createdAt: Date = Date()
    var source: NoteSource
}

enum NoteSource: String, CaseIterable, Codable {
    case manual = "manual"
    case scanned = "scanned"
    case appointment = "appointment"
}

struct Medication: Codable, Identifiable {
    let id = UUID()
    var name: String
    var dosage: String
    var frequency: String
    var endDate: Date?
    var instructions: String?
}

struct AlignerProgress: Codable {
    var currentTray: Int
    var totalTrays: Int
    var nextChangeDate: Date?
    var wearHoursPerDay: Int = 22
}

// MARK: - Pain Mapping
struct PainEntry: Codable, Identifiable {
    let id = UUID()
    var toothNumber: Int
    var painLevel: Double // 0-10
    var notes: String?
    var timestamp: Date = Date()
}

struct ToothStatus: Codable {
    var toothNumber: Int
    var procedures: [ToothProcedure]
    var currentPainLevel: Double = 0
    var lastUpdated: Date = Date()
}

struct ToothProcedure: Codable, Identifiable {
    let id = UUID()
    var type: ProcedureType
    var date: Date
    var notes: String?
}

enum ProcedureType: String, CaseIterable, Codable {
    case filling = "filling"
    case crown = "crown"
    case extraction = "extraction"
    case implant = "implant"
    case rootCanal = "rootCanal"
    case cleaning = "cleaning"
}

// MARK: - Appointments
struct Appointment: Codable, Identifiable {
    let id = UUID()
    var date: Date
    var title: String
    var dentistName: String?
    var notes: String?
    var location: String?
    var isCompleted: Bool = false
}

// MARK: - ChewCheck
struct ChewCheckResult: Codable, Identifiable {
    let id = UUID()
    var foodName: String
    var confidence: Double
    var verdict: FoodVerdict
    var tags: [FoodTag]
    var reasons: [String]
    var source: ResultSource
    var timestamp: Date = Date()
    var alternatives: [String] = []
}

enum FoodVerdict: String, CaseIterable, Codable {
    case safe = "safe"
    case caution = "caution" 
    case avoid = "avoid"
    case later = "later"
    
    var color: Color {
        switch self {
        case .safe: return .green
        case .caution: return .orange
        case .avoid: return .red
        case .later: return .yellow
        }
    }
    
    var icon: String {
        switch self {
        case .safe: return "checkmark.circle.fill"
        case .caution: return "exclamationmark.triangle.fill"
        case .avoid: return "xmark.circle.fill"
        case .later: return "clock.fill"
        }
    }
}

enum FoodTag: String, CaseIterable, Codable {
    case soft = "soft"
    case hard = "hard"
    case sticky = "sticky"
    case chewy = "chewy"
    case cold = "cold"
    case hot = "hot"
    case sugary = "sugary"
    case acidic = "acidic"
}

enum ResultSource: String, CaseIterable, Codable {
    case mlModel = "mlModel"
    case userCorrected = "userCorrected"
}

// MARK: - Chat
struct ChatMessage: Codable, Identifiable {
    let id = UUID()
    var content: String
    var isFromBot: Bool
    var timestamp: Date = Date()
    var actionChips: [ActionChip] = []
}

struct ActionChip: Codable, Identifiable {
    let id = UUID()
    var title: String
    var action: ChipAction
}

enum ChipAction: String, CaseIterable, Codable {
    case addToPlan = "addToPlan"
    case setReminder = "setReminder"
    case updatePainMap = "updatePainMap"
    case scheduleAppointment = "scheduleAppointment"
}