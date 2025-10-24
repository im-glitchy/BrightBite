//
//  ChewCheckMLService.swift
//  BrightBite
//
//  Created by Tuan Nguyen on 9/19/25.
//

import UIKit
import Foundation


class ChewCheckMLService {
    static let shared = ChewCheckMLService()

    
    private let useOnDeviceML = false 
    private let usePythonBackend = true 
    private let useProductionAPI = true 
    private var apiURL: String {
        if useProductionAPI {
            
            return "https://brightbite.tuandnguyen.dev/api/analyze-food"
        } else {
            
            #if targetEnvironment(simulator)
            return PythonServerManager.shared.serverURL?.appending("/analyze-food") ?? "http://127.0.0.1:8000/analyze-food"
            #else
            
            return "http://192.168.1.202:8000/analyze-food"
            #endif
        }
    }

    private init() {}

    func classifyFood(image: UIImage, userProfile: UserProfile? = nil, treatmentPlan: TreatmentPlan? = nil, painEntries: [PainEntry] = []) async throws -> FoodClassification {
        if useOnDeviceML {
            return try await classifyFoodWithTensorFlowLite(image: image, userProfile: userProfile, treatmentPlan: treatmentPlan, painEntries: painEntries)
        } else if usePythonBackend {
            return try await classifyFoodWithPythonAPI(image: image, userProfile: userProfile, treatmentPlan: treatmentPlan, painEntries: painEntries)
        } else {
            return try await classifyFoodMock(image: image)
        }
    }

    

    func analyzeCorrectedFood(foodName: String, userProfile: UserProfile? = nil, treatmentPlan: TreatmentPlan? = nil, painEntries: [PainEntry] = []) async throws -> FoodClassification {
        
        let chatGPTAnalysis = try await analyzeFoodSafetyWithChatGPT(
            foodName: foodName,
            foodTags: [], 
            userProfile: userProfile,
            treatmentPlan: treatmentPlan,
            painEntries: painEntries
        )

        let verdict: FoodVerdict
        if let verdictString = chatGPTAnalysis.verdict {
            switch verdictString.lowercased() {
            case "safe": verdict = .safe
            case "caution": verdict = .caution
            case "avoid": verdict = .avoid
            case "later": verdict = .later
            case "cannotidentify": verdict = .cannotIdentify
            default: verdict = .avoid
            }
        } else {
            verdict = .avoid
        }

        var tags: [FoodTag] = []
        let foodLower = foodName.lowercased()

        
        if foodLower.contains("popcorn") || foodLower.contains("nuts") || foodLower.contains("candy") || foodLower.contains("carrot") {
            tags.append(.hard)
        }
        if foodLower.contains("caramel") || foodLower.contains("gum") || foodLower.contains("taffy") {
            tags.append(.sticky)
        }
        if foodLower.contains("yogurt") || foodLower.contains("soup") || foodLower.contains("mashed") {
            tags.append(.soft)
        }
        if foodLower.contains("candy") || foodLower.contains("soda") || foodLower.contains("cake") || foodLower.contains("cookie") {
            tags.append(.sugary)
        }

        return FoodClassification(
            primaryResult: FoodResult(
                name: foodName,
                confidence: 1.0, 
                tags: tags
            ),
            alternatives: [],
            verdict: chatGPTAnalysis.verdict,
            reasons: chatGPTAnalysis.reasons
        )
    }

    

    private func classifyFoodWithTensorFlowLite(image: UIImage, userProfile: UserProfile? = nil, treatmentPlan: TreatmentPlan? = nil, painEntries: [PainEntry] = []) async throws -> FoodClassification {
        
        let userId = userProfile?.id ?? "unknown"
        let _ = try PhotoStorageService.shared.saveChewCheckPhoto(image, userId: userId)

        
        let tfLiteResult = try await TensorFlowLiteService.shared.classifyFood(image)

        
        let chatGPTAnalysis = try await analyzeFoodSafetyWithChatGPT(
            foodName: tfLiteResult.primaryResult.name,
            foodTags: tfLiteResult.primaryResult.tags,
            userProfile: userProfile,
            treatmentPlan: treatmentPlan,
            painEntries: painEntries
        )

        
        return FoodClassification(
            primaryResult: tfLiteResult.primaryResult,
            alternatives: tfLiteResult.alternatives,
            verdict: chatGPTAnalysis.verdict,
            reasons: chatGPTAnalysis.reasons
        )
    }

    private func analyzeFoodSafetyWithChatGPT(foodName: String, foodTags: [FoodTag], userProfile: UserProfile?, treatmentPlan: TreatmentPlan?, painEntries: [PainEntry]) async throws -> (verdict: String?, reasons: [String]) {
        
        var contextLines: [String] = []

        
        if let profile = userProfile {
            contextLines.append("User has braces: \(profile.hasBraces)")
        }

        
        if let plan = treatmentPlan {
            for restriction in plan.restrictions {
                var restrictionText = "Restriction: \(restriction.type.rawValue)"
                if let endDate = restriction.endDate {
                    restrictionText += " (until \(endDate.formatted(.dateTime.month().day())))"
                }
                if let reason = restriction.reason {
                    restrictionText += " - \(reason)"
                }
                contextLines.append(restrictionText)
            }

            
            for medication in plan.medications {
                contextLines.append("Medication: \(medication.name) - \(medication.dosage)")
            }
        }

        
        if !painEntries.isEmpty {
            contextLines.append("Current pain levels:")
            for entry in painEntries {
                contextLines.append("Tooth #\(entry.toothNumber): pain level \(Int(entry.painLevel))/10")
            }
        }

        let userContext = contextLines.joined(separator: "\n")

        let prompt = """
        You are a dental safety advisor. Analyze if this food is safe for this user to eat.

        Food: \(foodName)
        Food characteristics: \(foodTags.map { $0.rawValue }.joined(separator: ", "))

        User context:
        \(userContext)

        Respond with:
        1. Verdict: "safe", "caution", "avoid", "later", or "cannotIdentify" (if not food or unclear)
        2. Brief reasons (1-2 sentences)

        Format your response as:
        VERDICT: [verdict]
        REASONS: [reasons]
        """

        
        let context = DentalContext(
            userProfile: userProfile,
            treatmentPlan: treatmentPlan,
            recentPainEntries: painEntries,
            recentChewCheckResults: nil
        )

        let response = try await DentalBotService.shared.sendMessage(prompt, context: context)

        
        return parseChatGPTResponse(response)
    }

    private func parseChatGPTResponse(_ response: String) -> (verdict: String?, reasons: [String]) {
        let lines = response.components(separatedBy: .newlines)

        var verdict: String?
        var reasons: [String] = []

        for line in lines {
            if line.uppercased().hasPrefix("VERDICT:") {
                verdict = String(line.dropFirst(8)).trimmingCharacters(in: .whitespaces).lowercased()
            } else if line.uppercased().hasPrefix("REASONS:") {
                let reasonsText = String(line.dropFirst(8)).trimmingCharacters(in: .whitespaces)
                reasons = [reasonsText]
            }
        }

        return (verdict: verdict, reasons: reasons)
    }

    

    private func classifyFoodWithPythonAPI(image: UIImage, userProfile: UserProfile? = nil, treatmentPlan: TreatmentPlan? = nil, painEntries: [PainEntry] = []) async throws -> FoodClassification {
        
        if !useProductionAPI {
            do {
                try await PythonServerManager.shared.ensureServerRunning()
            } catch {
                print("Failed to start Python server: \(error)")
                print("Falling back to mock mode...")
                return try await classifyFoodMock(image: image)
            }
        }


        let userId = userProfile?.id ?? "unknown"
        let _ = try PhotoStorageService.shared.saveChewCheckPhoto(image, userId: userId)

        let imageData = await Task.detached {
            image.jpegData(compressionQuality: 0.8)
        }.value

        guard let imageData = imageData else {
            throw ChewCheckError.imageProcessingFailed
        }

        guard let url = URL(string: apiURL) else {
            throw ChewCheckError.invalidURL
        }

        print("🔍 Sending food image to Python backend: \(apiURL)")

        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30.0
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        
        let base64Image = imageData.base64EncodedString()

        
        let dietRestrictions = (treatmentPlan?.restrictions.map { $0.type.rawValue } ?? [])
        let recentProcedures = (treatmentPlan?.doctorNotes.prefix(3).map { $0.content } ?? [])

        let requestBody: [String: Any] = [
            "imageBase64": base64Image,
            "userContext": [
                "hasBraces": userProfile?.hasBraces ?? false,
                "dietRestrictions": dietRestrictions,
                "recentProcedures": recentProcedures
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw ChewCheckError.networkError
            }

            print("📡 Railway API response: \(httpResponse.statusCode)")

            guard httpResponse.statusCode == 200 else {
                if let errorString = String(data: data, encoding: .utf8) {
                    print("❌ API Error: \(errorString)")
                }
                throw ChewCheckError.serverError(httpResponse.statusCode)
            }

            
            let apiResponse = try JSONDecoder().decode(RailwayAPIResponse.self, from: data)

            print("✅ Food identified: \(apiResponse.foodName) (confidence: \(apiResponse.confidence), source: \(apiResponse.source))")

            return FoodClassification(
                primaryResult: FoodResult(
                    name: apiResponse.foodName,
                    confidence: apiResponse.confidence,
                    tags: apiResponse.tags.compactMap { FoodTag(rawValue: $0) }
                ),
                alternatives: apiResponse.alternatives.map { altName in
                    FoodResult(
                        name: altName,
                        confidence: 0.6,
                        tags: []
                    )
                },
                verdict: apiResponse.verdict,
                reasons: apiResponse.reasons
            )
        } catch {
            
            print("❌ Railway API unavailable, falling back to mock: \(error)")
            return try await classifyFoodMock(image: image)
        }
    }
    
    
    
    private func classifyFoodMock(image: UIImage) async throws -> FoodClassification {
        
        try await Task.sleep(nanoseconds: 2_000_000_000)
        
        let mockFoods: [(String, Double, [FoodTag])] = [
            ("Yogurt", 0.89, [FoodTag.soft, FoodTag.cold]),
            ("Apple", 0.92, [FoodTag.hard, FoodTag.sugary]),
            ("Ice Cream", 0.87, [FoodTag.soft, FoodTag.cold, FoodTag.sugary]),
            ("Carrot", 0.91, [FoodTag.hard]),
            ("Pasta", 0.85, [FoodTag.soft, FoodTag.hot]),
            ("Granola Bar", 0.88, [FoodTag.hard, FoodTag.sticky, FoodTag.sugary]),
            ("Soup", 0.90, [FoodTag.soft, FoodTag.hot]),
            ("Bread", 0.86, [FoodTag.soft]),
            ("Nuts", 0.93, [FoodTag.hard]),
            ("Banana", 0.89, [FoodTag.soft])
        ]
        
        let classification = mockFoods.randomElement()!
        
        return FoodClassification(
            primaryResult: FoodResult(
                name: classification.0,
                confidence: classification.1,
                tags: classification.2
            ),
            alternatives: mockFoods
                .filter { $0.0 != classification.0 }
                .prefix(3)
                .map { FoodResult(name: $0.0, confidence: $0.1 * 0.8, tags: $0.2) },
            verdict: classification.2.contains(.soft) ? "safe" : "caution",
            reasons: ["Mock classification result"]
        )
    }
    
    
    
    private func buildUserProfileFormData(userProfile: UserProfile?, treatmentPlan: TreatmentPlan?, painEntries: [PainEntry]) -> [String: String] {
        var formData: [String: String] = [:]
        
        
        formData["has_braces"] = "\(userProfile?.hasBraces ?? false)"
        formData["has_dental_work"] = "\(treatmentPlan?.doctorNotes.isEmpty == false || false)"
        formData["has_sensitive_teeth"] = "\(!painEntries.isEmpty)"
        formData["dietary_restrictions"] = treatmentPlan?.restrictions.map { $0.type.rawValue }.joined(separator: ", ") ?? "none"
        
        
        let currentTreatment = treatmentPlan?.currentTasks.first?.title ?? "none"
        formData["current_treatment"] = currentTreatment
        formData["treatment_phase"] = treatmentPlan?.alignerProgress != nil ? "aligner_\(treatmentPlan?.alignerProgress?.currentTray ?? 0)" : "none"
        formData["next_appointment"] = "none" 
        
        
        let recentProcedures = treatmentPlan?.doctorNotes.prefix(3).map { $0.content }.joined(separator: "; ") ?? "none"
        formData["recent_procedures"] = recentProcedures.isEmpty ? "none" : recentProcedures
        formData["ongoing_issues"] = treatmentPlan?.currentTasks.map { $0.title }.joined(separator: "; ") ?? "none"
        
        
        let currentMeds = treatmentPlan?.medications.map { "\($0.name) \($0.dosage)" }.joined(separator: "; ") ?? "none"
        formData["current_medications"] = currentMeds.isEmpty ? "none" : currentMeds
        let painMeds = treatmentPlan?.medications.filter { $0.name.lowercased().contains("pain") || $0.name.lowercased().contains("ibuprofen") || $0.name.lowercased().contains("acetaminophen") }.map { $0.name }.joined(separator: "; ") ?? "none"
        formData["pain_medications"] = painMeds.isEmpty ? "none" : painMeds
        
        
        let currentPainAreas = painEntries.map { "tooth_\($0.toothNumber)" }.joined(separator: ", ")
        formData["current_pain_areas"] = currentPainAreas.isEmpty ? "none" : currentPainAreas
        let painLevels = painEntries.map { "tooth_\($0.toothNumber):level_\(Int($0.painLevel))" }.joined(separator: ", ")
        formData["pain_levels"] = painLevels.isEmpty ? "none" : painLevels
        
        
        formData["age_group"] = "adult" 
        formData["treatment_duration"] = treatmentPlan?.alignerProgress != nil ? "\(treatmentPlan?.alignerProgress?.currentTray ?? 0)_weeks" : "none"
        
        return formData
    }
    
    func analyzeFoodTags(_ tags: [FoodTag], against restrictions: [DietRestriction]) -> FoodVerdict {
        
        for restriction in restrictions {
            switch restriction.type {
            case .softOnly:
                if tags.contains(.hard) || tags.contains(.chewy) {
                    return .avoid
                }
            case .noHard:
                if tags.contains(.hard) {
                    return .avoid
                }
            case .noSticky:
                if tags.contains(.sticky) {
                    return .avoid
                }
            case .noChewy:
                if tags.contains(.chewy) {
                    return .avoid
                }
            case .noHot:
                if tags.contains(.hot) {
                    return .avoid
                }
            case .noCold:
                if tags.contains(.cold) {
                    return .avoid
                }
            case .noSugary:
                if tags.contains(.sugary) {
                    return .caution
                }
            case .noAcidic:
                if tags.contains(.acidic) {
                    return .caution
                }
            }
        }
        
        
        if tags.contains(.sugary) || tags.contains(.acidic) {
            return .caution
        }
        
        
        if tags.contains(.hot) {
            return .later 
        }
        
        return .safe
    }
}

struct FoodClassification {
    let primaryResult: FoodResult
    let alternatives: [FoodResult]
    let verdict: String?
    let reasons: [String]
}

struct FoodResult {
    let name: String
    let confidence: Double
    let tags: [FoodTag]
}


struct PythonAPIResponse: Codable {
    let food_name: String
    let confidence: Double
    let alternatives: [String]
    let tags: [String]
    let verdict: String
    let reasons: [String]
    let timestamp: String
}


struct RailwayAPIResponse: Codable {
    let foodName: String
    let confidence: Double
    let verdict: String
    let tags: [String]
    let reasons: [String]
    let alternatives: [String]
    let source: String 
}


enum ChewCheckError: Error, LocalizedError {
    case imageProcessingFailed
    case invalidURL
    case networkError
    case serverError(Int)
    case decodingError
    
    var errorDescription: String? {
        switch self {
        case .imageProcessingFailed:
            return "Failed to process the image"
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
