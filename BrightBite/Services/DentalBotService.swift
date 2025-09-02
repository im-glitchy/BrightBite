//
//  DentalBotService.swift
//  BrightBite
//
//  Created by Tuan Nguyen on 9/1/25.
//

import Foundation

// Mock DentalBot service for development
// In production, this would integrate with OpenAI API

class DentalBotService {
    static let shared = DentalBotService()
    
    private init() {}
    
    func sendMessage(_ message: String, context: DentalContext?) async throws -> String {
        // Simulate API call delay
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // Mock response based on message content
        if message.lowercased().contains("pain") {
            return "I understand you're experiencing pain. Based on your treatment plan, this could be related to your recent procedure. Pain levels of 1-3 are normal, but if it's above 5, you should contact your dentist. You can log your pain level in the Pain Map to track it over time."
        } else if message.lowercased().contains("food") || message.lowercased().contains("eat") {
            return "For your current treatment with braces, I recommend sticking to soft foods for the next few days. You can use ChewCheck to scan any food you're unsure about. Avoid hard, sticky, or chewy foods that could damage your braces."
        } else if message.lowercased().contains("braces") {
            return "With braces, it's important to maintain good oral hygiene and follow your orthodontist's instructions. Make sure to wear your elastics as prescribed and avoid foods that could damage the brackets or wires."
        } else if message.lowercased().contains("appointment") {
            return "Your next appointment is coming up in 2 weeks. You can view the details in your Plan tab. If you need to reschedule or have concerns before then, don't hesitate to contact your dentist's office."
        } else {
            return "I'm here to help with your dental care questions. I can provide guidance on diet restrictions, pain management, braces care, and treatment plans. What specific concerns do you have today?"
        }
    }
    
    func explainFoodVerdict(food: String, verdict: FoodVerdict, restrictions: [DietRestriction]) async throws -> String {
        // Simulate API call for food explanation
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        switch verdict {
        case .safe:
            return "\(food) is safe for you to eat right now. It meets your current dietary restrictions and won't interfere with your treatment."
        case .caution:
            return "\(food) is okay to eat, but use caution. Make sure to rinse your mouth afterward and be gentle when chewing."
        case .avoid:
            return "You should avoid \(food) right now as it could damage your braces or interfere with your healing process."
        case .later:
            return "Wait before eating \(food). This food is typically safe for you, but timing matters based on your current treatment stage."
        }
    }
}

struct DentalContext {
    let userProfile: UserProfile?
    let treatmentPlan: TreatmentPlan?
    let recentPainEntries: [PainEntry]?
    let recentChewCheckResults: [ChewCheckResult]?
}