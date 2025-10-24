//
//  DentalBotService.swift
//  BrightBite
//
//  Created by Tuan Nguyen on 9/19/25.
//

import Foundation


class DentalBotService {
    static let shared = DentalBotService()

    
    private let useOpenAI = true

    private init() {}

    func sendMessage(_ message: String, context: DentalContext?) async throws -> String {
        if useOpenAI {
            return try await sendMessageToOpenAI(message: message, context: context)
        } else {
            return try await sendMessageMock(message: message, context: context)
        }
    }
    
    

    private func sendMessageToOpenAI(message: String, context: DentalContext?) async throws -> String {
        do {
            return try await OpenAIService.shared.sendChatMessage(message, context: context)
        } catch {
            
            print("OpenAI unavailable, falling back to mock: \(error)")
            return try await sendMessageMock(message: message, context: context)
        }
    }
    
    
    
    private func sendMessageMock(message: String, context: DentalContext?) async throws -> String {
        
        try await Task.sleep(nanoseconds: 1_000_000_000) 
        
        let hasBraces = context?.userProfile?.hasBraces ?? false
        let hasRecentProcedures = !(context?.treatmentPlan?.doctorNotes.isEmpty ?? true)
        let hasPain = !(context?.recentPainEntries?.isEmpty ?? true)
        let hasRestrictions = !(context?.treatmentPlan?.restrictions.isEmpty ?? true)
        
        
        if message.lowercased().contains("pain") {
            if hasPain {
                return "I see you have some current pain areas logged. Based on your pain map data, pain levels of 1-3 are normal after procedures, but if it's above 5, you should contact your dentist. You can update your Pain Map to track changes over time."
            } else {
                return "I don't see any current pain logged in your profile. If you're experiencing new pain, you can log it in the Pain Map to track it. For persistent pain above level 5, contact your dentist."
            }
        } else if message.lowercased().contains("food") || message.lowercased().contains("eat") {
            if hasBraces {
                return "For your current treatment with braces, I recommend sticking to soft foods to avoid damaging your brackets or wires. You can use ChewCheck to scan any food you're unsure about. Avoid hard, sticky, or chewy foods."
            } else if hasRestrictions {
                let restrictions = context?.treatmentPlan?.restrictions.map { $0.type.rawValue }.joined(separator: ", ") ?? "dietary restrictions"
                return "Based on your current treatment plan, you have some dietary restrictions: \(restrictions). You can use ChewCheck to scan foods and get personalized advice based on your situation."
            } else {
                return "Based on your current dental health profile, you can generally eat most foods. However, you can always use ChewCheck to scan specific foods for personalized advice. Maintain good oral hygiene after meals."
            }
        } else if message.lowercased().contains("braces") {
            if hasBraces {
                return "With your braces, it's important to maintain good oral hygiene and follow your orthodontist's instructions. Make sure to wear your elastics as prescribed and avoid foods that could damage the brackets or wires."
            } else {
                return "I don't see that you currently have braces in your profile. If you're considering braces or have questions about orthodontic treatment, I'd recommend discussing this with your dentist or orthodontist."
            }
        } else if message.lowercased().contains("appointment") {
            if hasRecentProcedures {
                return "Based on your recent dental procedures, regular follow-up appointments are important. You can view appointment details in your Plan tab. If you need to reschedule or have concerns, contact your dentist's office."
            } else {
                return "Regular dental checkups are important for maintaining good oral health. You can view upcoming appointments in your Plan tab. If you need to schedule or reschedule, contact your dentist's office."
            }
        } else {
            
            if hasBraces {
                return "I'm here to help with your dental care questions, especially regarding your braces treatment. I can provide guidance on diet restrictions, pain management, oral hygiene, and treatment plans. What specific concerns do you have today?"
            } else if hasRecentProcedures {
                return "I'm here to help with your dental care questions, including your recent dental procedures. I can provide guidance on recovery, diet restrictions, pain management, and oral health. What would you like to know?"
            } else {
                return "I'm here to help with your dental care questions. I can provide guidance on oral health, diet recommendations, and general dental care. You can also use ChewCheck to scan foods for personalized advice. What can I help you with today?"
            }
        }
    }
    
    func explainFoodVerdict(food: String, verdict: FoodVerdict, restrictions: [DietRestriction]) async throws -> String {
        
        try await Task.sleep(nanoseconds: 500_000_000) 
        
        switch verdict {
        case .safe:
            return "\(food) is safe for you to eat right now. It meets your current dietary restrictions and won't interfere with your treatment."
        case .caution:
            return "\(food) is okay to eat, but use caution. Make sure to rinse your mouth afterward and be gentle when chewing."
        case .avoid:
            return "You should avoid \(food) right now as it could damage your braces or interfere with your healing process."
        case .later:
            return "Wait before eating \(food). This food is typically safe for you, but timing matters based on your current treatment stage."
        case .cannotIdentify:
            return "I was unable to identify \(food) as a food item. For your safety, I recommend avoiding eating unidentified items. Try taking a clearer photo or choosing a different item to scan."
        }
    }
}

struct DentalContext {
    let userProfile: UserProfile?
    let treatmentPlan: TreatmentPlan?
    let recentPainEntries: [PainEntry]?
    let recentChewCheckResults: [ChewCheckResult]?
}


struct ChatAPIResponse: Codable {
    let response: String
    let timestamp: String
}


enum DentalBotError: Error, LocalizedError {
    case invalidURL
    case networkError
    case serverError(Int)
    case decodingError
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .networkError:
            return "Network connection failed"
        case .serverError(let code):
            return "Server error: \(code)"
        case .decodingError:
            return "Failed to decode server response"
        }
    }
}
