//
//  DataModels.swift
//  BrightBite
//
//  Created by Tuan Nguyen on 8/29/25.
//

import Foundation
import SwiftUI


struct UserProfile: Codable, Identifiable {
    let id: String
    var name: String?
    var hasBraces: Bool = false
    var dentistInfo: DentistInfo?
    var profileImageURL: String? 
    var createdAt: Date = Date()
}

struct DentistInfo: Codable {
    var name: String
    var phone: String?
    var email: String?
    var address: String?
}


struct InsuranceCard: Codable, Identifiable {
    var id: UUID
    var providerName: String
    var memberId: String
    var groupNumber: String?
    var policyHolderName: String
    var planType: String?
    var customerServicePhone: String?
    var coveragePreventive: Int? 
    var coverageBasic: Int? 
    var coverageMajor: Int? 
    var annualMaximum: Double? 
    var deductible: Double? 
    var cardImageURL: String? 
    var cardImageData: Data? 
    var createdAt: Date = Date()
    var lastUpdated: Date = Date()

    init(id: UUID = UUID(), providerName: String, memberId: String, groupNumber: String? = nil, policyHolderName: String, planType: String? = nil, customerServicePhone: String? = nil, coveragePreventive: Int? = nil, coverageBasic: Int? = nil, coverageMajor: Int? = nil, annualMaximum: Double? = nil, deductible: Double? = nil, cardImageURL: String? = nil, cardImageData: Data? = nil, createdAt: Date = Date(), lastUpdated: Date = Date()) {
        self.id = id
        self.providerName = providerName
        self.memberId = memberId
        self.groupNumber = groupNumber
        self.policyHolderName = policyHolderName
        self.planType = planType
        self.customerServicePhone = customerServicePhone
        self.coveragePreventive = coveragePreventive
        self.coverageBasic = coverageBasic
        self.coverageMajor = coverageMajor
        self.annualMaximum = annualMaximum
        self.deductible = deductible
        self.cardImageURL = cardImageURL
        self.cardImageData = cardImageData
        self.createdAt = createdAt
        self.lastUpdated = lastUpdated
    }

    enum CodingKeys: String, CodingKey {
        case id, providerName, memberId, groupNumber, policyHolderName, planType
        case customerServicePhone, coveragePreventive, coverageBasic, coverageMajor
        case annualMaximum, deductible, cardImageURL, createdAt, lastUpdated
    }
}


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


struct RecentActivity: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var date: String
    var description: String
    var type: ActivityType
    var timestamp: Date = Date()
    var foodName: String?
    var toothNumber: Int?
    var documentId: String?
    var metadata: [String: String]?

    static func == (lhs: RecentActivity, rhs: RecentActivity) -> Bool {
        return lhs.id == rhs.id
    }
}

enum ActivityType: String, CaseIterable, Codable {
    case chewCheck = "chewCheck"
    case painLog = "painLog"
    case appointment = "appointment"
    case notesScan = "notesScan"
    case medication = "medication"
    case toothUpdate = "toothUpdate"
}

struct DentalSummary: Codable, Identifiable {
    var id: UUID = UUID()
    var teethInPain: Int = 0
    var painfulTeeth: [Int] = []
    var activeTreatments: Int = 0
    var upcomingAppointments: Int = 0
    var nextAppointmentDate: Date?
    var activeMedications: Int = 0
    var activeRestrictions: Int = 0
    var lastUpdated: Date = Date()
    var summary: String = ""
}


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

    static func from(string: String) -> RestrictionType? {
        let normalized = string.lowercased().replacingOccurrences(of: " ", with: "")
        return RestrictionType.allCases.first { $0.rawValue.lowercased() == normalized }
    }
}

struct DoctorNote: Codable, Identifiable {
    var id: UUID
    var title: String?
    var content: String
    var createdAt: Date = Date()
    var source: NoteSource

    init(id: UUID = UUID(), title: String? = nil, content: String, createdAt: Date = Date(), source: NoteSource) {
        self.id = id
        self.title = title
        self.content = content
        self.createdAt = createdAt
        self.source = source
    }
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


struct PainEntry: Codable, Identifiable, Equatable {
    let id = UUID()
    var toothNumber: Int
    var painLevel: Double
    var notes: String?
    var timestamp: Date = Date()

    static func == (lhs: PainEntry, rhs: PainEntry) -> Bool {
        return lhs.id == rhs.id &&
               lhs.toothNumber == rhs.toothNumber &&
               lhs.painLevel == rhs.painLevel &&
               lhs.notes == rhs.notes &&
               lhs.timestamp == rhs.timestamp
    }
}

struct ToothStatus: Codable, Identifiable, Equatable {
    var id: String { "\(toothNumber)" }
    var toothNumber: Int
    var condition: ToothCondition = .healthy
    var procedures: [ToothProcedure] = []
    var currentPainLevel: Double = 0
    var lastUpdated: Date = Date()

    static func == (lhs: ToothStatus, rhs: ToothStatus) -> Bool {
        return lhs.toothNumber == rhs.toothNumber &&
               lhs.condition == rhs.condition &&
               lhs.procedures == rhs.procedures &&
               lhs.currentPainLevel == rhs.currentPainLevel &&
               lhs.lastUpdated == rhs.lastUpdated
    }
}

enum ToothCondition: String, CaseIterable, Codable {
    case healthy = "healthy"
    case filling = "filling"
    case crown = "crown"
    case broken = "broken"
    case chipped = "chipped"
    case missing = "missing"
    case implant = "implant"
    case rootCanal = "rootCanal"

    var displayName: String {
        switch self {
        case .healthy: return "Healthy"
        case .filling: return "Has Filling"
        case .crown: return "Has Crown"
        case .broken: return "Broken"
        case .chipped: return "Chipped"
        case .missing: return "Missing"
        case .implant: return "Has Implant"
        case .rootCanal: return "Root Canal"
        }
    }

    var shouldHide: Bool {
        return self == .missing
    }
}

struct ToothProcedure: Codable, Identifiable, Equatable {
    let id = UUID()
    var type: ProcedureType
    var date: Date
    var notes: String?

    static func == (lhs: ToothProcedure, rhs: ToothProcedure) -> Bool {
        return lhs.id == rhs.id &&
               lhs.type == rhs.type &&
               lhs.date == rhs.date &&
               lhs.notes == rhs.notes
    }
}

enum ProcedureType: String, CaseIterable, Codable {
    case filling = "filling"
    case crown = "crown"
    case extraction = "extraction"
    case implant = "implant"
    case rootCanal = "rootCanal"
    case cleaning = "cleaning"

    static func from(string: String) -> ProcedureType? {
        let normalized = string.lowercased().replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "-", with: "")
        return ProcedureType.allCases.first { $0.rawValue.lowercased() == normalized }
    }
}


struct Appointment: Codable, Identifiable {
    var id: UUID
    var date: Date
    var title: String
    var dentistName: String?
    var notes: String?
    var location: String?
    var isCompleted: Bool = false
    var isAllDay: Bool = false

    init(id: UUID = UUID(), date: Date, title: String, dentistName: String? = nil, notes: String? = nil, location: String? = nil, isCompleted: Bool = false, isAllDay: Bool = false) {
        self.id = id
        self.date = date
        self.title = title
        self.dentistName = dentistName
        self.notes = notes
        self.location = location
        self.isCompleted = isCompleted
        self.isAllDay = isAllDay
    }
}


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
    case cannotIdentify = "cannotIdentify"

    var color: Color {
        switch self {
        case .safe: return .green
        case .caution: return .orange
        case .avoid: return .red
        case .later: return .yellow
        case .cannotIdentify: return .orange
        }
    }

    var icon: String {
        switch self {
        case .safe: return "checkmark.circle.fill"
        case .caution: return "exclamationmark.triangle.fill"
        case .avoid: return "xmark.circle.fill"
        case .later: return "clock.fill"
        case .cannotIdentify: return "questionmark.circle.fill"
        }
    }

    var displayName: String {
        switch self {
        case .safe: return "Safe"
        case .caution: return "Caution"
        case .avoid: return "Not Safe"
        case .later: return "Wait"
        case .cannotIdentify: return "Cannot Identify"
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

    var color: Color {
        switch self {
        case .soft: return .green
        case .hard: return .red
        case .sticky: return .orange
        case .chewy: return .orange
        case .cold: return .blue
        case .hot: return .red
        case .sugary: return .purple
        case .acidic: return .yellow
        }
    }
}

enum ResultSource: String, CaseIterable, Codable {
    case tensorflowFood101 = "TensorFlow (Food-101)"    
    case chatgptVision = "ChatGPT-4o Vision"            
    case mock = "Mock Data"                             

    var displayName: String {
        return self.rawValue
    }
}


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
