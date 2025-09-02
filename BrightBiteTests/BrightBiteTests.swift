//
//  BrightBiteTests.swift
//  BrightBiteTests
//
//  Created by Tuan Nguyen on 9/1/25.
//

import Testing
@testable import BrightBite

struct BrightBiteTests {
    
    @Test func userProfileCreation() async throws {
        let profile = UserProfile(id: "test123", name: "Test User")
        #expect(profile.id == "test123")
        #expect(profile.name == "Test User")
        #expect(profile.hasBraces == false)
    }
    
    @Test func careTaskCompletion() async throws {
        var task = CareTask(title: "Rinse with salt water", category: .hygiene)
        #expect(task.isCompleted == false)
        
        task.isCompleted = true
        #expect(task.isCompleted == true)
    }
    
    @Test func foodVerdictLogic() async throws {
        let mlService = ChewCheckMLService.shared
        
        // Test soft-only restriction with hard food
        let hardTags: [FoodTag] = [.hard]
        let softOnlyRestriction = [DietRestriction(type: .softOnly)]
        
        let verdict = mlService.analyzeFoodTags(hardTags, against: softOnlyRestriction)
        #expect(verdict == .avoid)
        
        // Test safe food with soft-only restriction
        let softTags: [FoodTag] = [.soft]
        let safeVerdict = mlService.analyzeFoodTags(softTags, against: softOnlyRestriction)
        #expect(safeVerdict == .safe)
    }
    
    @Test func painLevelRange() async throws {
        let painEntry = PainEntry(toothNumber: 14, painLevel: 7.5)
        #expect(painEntry.toothNumber == 14)
        #expect(painEntry.painLevel == 7.5)
        #expect(painEntry.painLevel >= 0 && painEntry.painLevel <= 10)
    }
    
    @Test func chewCheckResultCreation() async throws {
        let result = ChewCheckResult(
            foodName: "Yogurt",
            confidence: 0.89,
            verdict: .safe,
            tags: [.soft, .cold],
            reasons: ["Soft texture", "Cool temperature"],
            source: .mlModel
        )
        
        #expect(result.foodName == "Yogurt")
        #expect(result.confidence == 0.89)
        #expect(result.verdict == .safe)
        #expect(result.source == .mlModel)
    }
    
    @Test func dietRestrictionValidation() async throws {
        let restriction = DietRestriction(
            type: .softOnly,
            endDate: Calendar.current.date(byAdding: .day, value: 7, to: Date()),
            reason: "Recent extraction"
        )
        
        #expect(restriction.type == .softOnly)
        #expect(restriction.reason == "Recent extraction")
        #expect(restriction.endDate != nil)
    }
    
    @Test func appointmentScheduling() async throws {
        let appointment = Appointment(
            date: Date(),
            title: "Regular Checkup",
            dentistName: "Dr. Smith",
            location: "123 Main St"
        )
        
        #expect(appointment.title == "Regular Checkup")
        #expect(appointment.dentistName == "Dr. Smith")
        #expect(appointment.isCompleted == false)
    }

}
