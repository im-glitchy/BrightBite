//
//  OpenAIService.swift
//  BrightBite
//
//  Created by Tuan Nguyen on 9/10/25.
//

import Foundation
import UIKit

struct ParsedDentalNotes: Codable {
    var documentDate: String? 
    var treatmentPlan: ParsedTreatmentPlan?
    var postOpInstructions: ParsedPostOpInstructions?
    var appointments: [ParsedAppointment]
    var medications: [ParsedMedication]
    var dietRestrictions: [ParsedDietRestriction]
    var procedures: [ParsedProcedure]
    var generalNotes: String?
}

struct ParsedTreatmentPlan: Codable {
    var description: String
    var duration: String?
    var goals: [String]
}

struct ParsedPostOpInstructions: Codable {
    var instructions: [String]
    var duration: String?
    var warnings: [String]
}

struct ParsedAppointment: Codable {
    var title: String
    var date: String 
    var location: String?
    var dentistName: String?
    var notes: String?
}

struct ParsedMedication: Codable {
    var name: String
    var dosage: String
    var frequency: String
    var duration: String?
    var instructions: String?
}

struct ParsedDietRestriction: Codable {
    var type: String 
    var duration: String?
    var reason: String?
}

struct ParsedProcedure: Codable {
    var type: String 
    var toothNumbers: [Int]?
    var date: String?
    var notes: String?
}

class OpenAIService {
    static let shared = OpenAIService()

    private let apiKey: String
    private let baseURL = "https://api.openai.com/v1/chat/completions"

    private init() {
        
        if let key = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] {
            self.apiKey = key
        } else {
            
            self.apiKey = "" 
        }
    }

    

    func sendChatMessage(_ message: String, context: DentalContext?) async throws -> String {
        guard !apiKey.isEmpty else {
            throw OpenAIError.missingAPIKey
        }

        
        let systemPrompt = buildDentalBotSystemPrompt(context: context)

        
        let messages: [[String: Any]] = [
            ["role": "system", "content": systemPrompt],
            ["role": "user", "content": message]
        ]

        
        let requestBody: [String: Any] = [
            "model": "gpt-4o-mini", 
            "messages": messages,
            "max_tokens": 500,
            "temperature": 0.7 
        ]

        
        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorJson["error"] as? [String: Any],
               let errorMessage = error["message"] as? String {
                throw OpenAIError.apiError(errorMessage)
            }
            throw OpenAIError.httpError(httpResponse.statusCode)
        }

        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let choices = json?["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let messageDict = firstChoice["message"] as? [String: Any],
              let content = messageDict["content"] as? String else {
            throw OpenAIError.invalidResponse
        }

        return content
    }

    private func buildDentalBotSystemPrompt(context: DentalContext?) -> String {
        var prompt = """
        You are DentalBot, a friendly and knowledgeable dental care assistant for the BrightBite app.
        You provide personalized dental advice based on the user's current dental situation.

        Guidelines:
        - Be conversational, warm, and supportive
        - Provide actionable advice when possible
        - Always recommend consulting a dentist for serious concerns
        - Reference specific features in the BrightBite app (Pain Map, ChewCheck, Plan)
        - Keep responses concise (2-3 sentences)
        """

        
        if let context = context {
            prompt += "\n\nUser's Current Dental Situation:"

            if let profile = context.userProfile {
                if profile.hasBraces {
                    prompt += "\n- Has braces (orthodontic treatment in progress)"
                }
                if let dentist = profile.dentistInfo {
                    prompt += "\n- Current dentist: \(dentist.name)"
                }
            }

            if let treatmentPlan = context.treatmentPlan {
                if !treatmentPlan.restrictions.isEmpty {
                    let restrictions = treatmentPlan.restrictions.map { $0.type.rawValue }.joined(separator: ", ")
                    prompt += "\n- Dietary restrictions: \(restrictions)"
                }

                if !treatmentPlan.medications.isEmpty {
                    let meds = treatmentPlan.medications.map { "\($0.name) \($0.dosage)" }.joined(separator: ", ")
                    prompt += "\n- Current medications: \(meds)"
                }

                if let aligner = treatmentPlan.alignerProgress {
                    prompt += "\n- Aligner treatment: Tray \(aligner.currentTray) of \(aligner.totalTrays)"
                }

                if !treatmentPlan.doctorNotes.isEmpty {
                    let recentNote = treatmentPlan.doctorNotes.first?.content ?? ""
                    prompt += "\n- Recent note: \(recentNote.prefix(100))..."
                }
            }

            if let painEntries = context.recentPainEntries, !painEntries.isEmpty {
                let painAreas = painEntries.map { "Tooth #\($0.toothNumber) (level \(Int($0.painLevel)))" }.joined(separator: ", ")
                prompt += "\n- Current pain areas: \(painAreas)"
            }
        }

        return prompt
    }

    

    func summarizeDentalNotes(ocrText: String) async throws -> String {
        print("=== SUMMARIZING DENTAL NOTES ===")
        print("OCR Text length: \(ocrText.count) characters")

        guard !apiKey.isEmpty else {
            print("ERROR: OpenAI API key is missing!")
            throw OpenAIError.missingAPIKey
        }

        let systemPrompt = """
        You are a dental assistant helping patients understand their dental notes.

        CRITICAL DATE AWARENESS:
        - TODAY'S DATE is \(Date().formatted(date: .abbreviated, time: .omitted))
        - Carefully distinguish between PAST events (already happened) and FUTURE events (upcoming/planned)
        - Appointments/procedures with dates in the PAST are historical records, NOT upcoming events
        - Only appointments with dates in the FUTURE should be called "upcoming"
        - If no dates are specified, look for context clues (e.g., "completed", "performed", "scheduled for")

        Your task is to read the scanned dental document and create a friendly, easy-to-understand summary highlighting the KEY DETAILS:
        - What procedures were DONE (past) or are PLANNED (future) - be specific about timing
        - Any medications prescribed
        - Diet restrictions or care instructions
        - Upcoming appointments (FUTURE dates only)
        - Important warnings or notes
        - TOOTH NUMBERS for any procedures (e.g., "tooth #14" or "teeth #2-5") - this is critical for pain tracking

        Keep your summary conversational and clear. Use bullet points for easy reading.
        Do NOT create JSON - just a friendly summary for the patient to review.
        """

        let userPrompt = "Please summarize this dental document:\n\n\(ocrText)"

        let messages: [[String: Any]] = [
            ["role": "system", "content": systemPrompt],
            ["role": "user", "content": userPrompt]
        ]

        let requestBody: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": messages,
            "max_tokens": 800,
            "temperature": 0.7
        ]

        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorJson["error"] as? [String: Any],
               let message = error["message"] as? String {
                throw OpenAIError.apiError(message)
            }
            throw OpenAIError.httpError(httpResponse.statusCode)
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let choices = json?["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw OpenAIError.invalidResponse
        }

        print("✅ Summary created: \(content.count) characters")
        return content
    }

    

    func parseDentalNotesWithContext(ocrText: String, conversationHistory: [[String: String]]) async throws -> ParsedDentalNotes {
        print("=== PARSING DENTAL NOTES WITH CONTEXT ===")

        guard !apiKey.isEmpty else {
            throw OpenAIError.missingAPIKey
        }

        
        let dentalContext = DentalDatabase.shared.generatePromptContext()

        let systemPrompt = """
        You are a dental notes parser with access to a comprehensive dental procedures database.

        \(dentalContext)

        CRITICAL DATE AWARENESS:
        - TODAY'S DATE is \(Date().formatted(date: .abbreviated, time: .omitted))
        - Carefully distinguish between PAST dates and FUTURE dates
        - Appointments with dates in the PAST should NOT be included in the appointments array (they already happened)
        - Only FUTURE appointments should be extracted
        - Procedures with dates should ALWAYS be extracted regardless of past/future (for medical history)

        CRITICAL: TOOTH NUMBERS ARE EXTREMELY IMPORTANT
        - Extract tooth numbers for ALL procedures (e.g., tooth #14, teeth #2-5, #18)
        - Tooth numbers are essential for our pain mapping feature
        - Look for patterns like: "tooth #14", "#14", "teeth 2-5", "tooth number 14"
        - If multiple teeth are mentioned, include all numbers in the toothNumbers array
        - This data will be used to correlate procedures with pain locations

        CRITICAL: Extract the DOCUMENT DATE - this is when the document was created/issued by the dentist.
        - Look for dates in headers, footers, "Date:", "Visit Date:", "Document Date:", etc.
        - This is NOT the same as appointment dates or procedure dates
        - Format as YYYY-MM-DD
        - This determines if the information is current or historical

        Your task is to extract structured information from dental notes and format it as JSON.
        Use the database above to:
        - Identify procedure types correctly
        - Suggest appropriate diet restrictions based on the procedure
        - Recommend typical medications if not explicitly mentioned
        - Infer recovery timelines and care instructions

        Extract the following information and return ONLY valid JSON:
        {
            "documentDate": "YYYY-MM-DD",
            "treatmentPlan": { "description": "", "duration": "", "goals": [] },
            "postOpInstructions": { "instructions": [], "duration": "", "warnings": [] },
            "appointments": [{ "title": "", "date": "YYYY-MM-DD HH:mm", "location": "", "dentistName": "", "notes": "" }],
            "medications": [{ "name": "", "dosage": "", "frequency": "", "duration": "", "instructions": "" }],
            "dietRestrictions": [{ "type": "softOnly|noHard|noSticky|noChewy|noHot|noCold|noSugary|noAcidic", "duration": "", "reason": "" }],
            "procedures": [{ "type": "cleaning|filling|crown|extraction|rootCanal|implant|braces|invisalign|whitening|deepCleaning|veneer|bonding", "toothNumbers": [14, 15], "date": "YYYY-MM-DD", "notes": "" }],
            "generalNotes": ""
        }

        IMPORTANT: Only include FUTURE appointments in the appointments array. Past appointments should be recorded as procedures instead.
        If documentDate is not found, use null. If fields are not found, use null or empty arrays. Be thorough and accurate.
        """

        
        var messages: [[String: Any]] = [
            ["role": "system", "content": systemPrompt]
        ]

        
        for msg in conversationHistory {
            if let role = msg["role"], let content = msg["content"] {
                messages.append(["role": role, "content": content])
            }
        }

        
        messages.append([
            "role": "user",
            "content": "Based on our conversation, please now extract all information from the original document and return it as structured JSON."
        ])

        let requestBody: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": messages,
            "max_tokens": 2000,
            "temperature": 0.1
        ]

        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorJson["error"] as? [String: Any],
               let message = error["message"] as? String {
                throw OpenAIError.apiError(message)
            }
            throw OpenAIError.httpError(httpResponse.statusCode)
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let choices = json?["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw OpenAIError.invalidResponse
        }

        print("\n=== CHATGPT JSON RESPONSE START ===")
        print(content)
        print("=== CHATGPT JSON RESPONSE END ===\n")

        
        guard let contentData = content.data(using: .utf8) else {
            throw OpenAIError.invalidJSON
        }

        let decoder = JSONDecoder()
        do {
            let parsedNotes = try decoder.decode(ParsedDentalNotes.self, from: contentData)
            print("✅ Successfully parsed dental notes!")
            return parsedNotes
        } catch {
            print("ERROR: Failed to decode JSON: \(error)")

            
            if let jsonMatch = content.range(of: "```json\\s*([\\s\\S]*?)```", options: .regularExpression) {
                let jsonString = String(content[jsonMatch])
                    .replacingOccurrences(of: "```json", with: "")
                    .replacingOccurrences(of: "```", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                if let cleanData = jsonString.data(using: .utf8) {
                    let cleanParsed = try decoder.decode(ParsedDentalNotes.self, from: cleanData)
                    print("✅ Successfully parsed from code block!")
                    return cleanParsed
                }
            }

            throw OpenAIError.invalidJSON
        }
    }

    

    func parseDentalNotes(text: String) async throws -> ParsedDentalNotes {
        print("=== DENTAL NOTES PARSING STARTED ===")
        print("Text length: \(text.count) characters")

        guard !apiKey.isEmpty else {
            print("ERROR: OpenAI API key is missing!")
            throw OpenAIError.missingAPIKey
        }

        print("API key found: \(apiKey.prefix(10))...")

        
        let systemPrompt = """
        You are a dental notes parser. Your job is to extract structured information from dental/dentist notes, treatment plans, and appointment records.

        Extract the following information and return it as a JSON object:
        1. Treatment Plan (description, duration, goals)
        2. Post-Op Instructions (instructions array, duration, warnings)
        3. Appointments (title, date in YYYY-MM-DD or YYYY-MM-DD HH:mm format, location, dentist name, notes)
        4. Medications (name, dosage, frequency, duration, special instructions)
        5. Diet Restrictions (type: softOnly/noHard/noSticky/noChewy/noHot/noCold/noSugary/noAcidic, duration, reason)
        6. Procedures performed (type: filling/crown/extraction/implant/rootCanal/cleaning, tooth numbers, date, notes)
        7. General notes (any other important information)

        Return ONLY valid JSON matching this structure:
        {
            "treatmentPlan": { "description": "", "duration": "", "goals": [] },
            "postOpInstructions": { "instructions": [], "duration": "", "warnings": [] },
            "appointments": [{ "title": "", "date": "", "location": "", "dentistName": "", "notes": "" }],
            "medications": [{ "name": "", "dosage": "", "frequency": "", "duration": "", "instructions": "" }],
            "dietRestrictions": [{ "type": "", "duration": "", "reason": "" }],
            "procedures": [{ "type": "", "toothNumbers": [], "date": "", "notes": "" }],
            "generalNotes": ""
        }

        If a field is not found in the notes, omit it or use null. Be thorough and extract all relevant information.
        """

        let userPrompt = "Please parse the following dental notes and extract all relevant information:\n\n\(text)"

        
        let messages: [[String: Any]] = [
            ["role": "system", "content": systemPrompt],
            ["role": "user", "content": userPrompt]
        ]

        
        let requestBody: [String: Any] = [
            "model": "gpt-4o-mini", 
            "messages": messages,
            "max_tokens": 2000,
            "temperature": 0.1 
        ]

        
        print("Sending request to OpenAI API...")
        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let requestSize = request.httpBody?.count ?? 0
        print("Request body size: \(requestSize) bytes")

        let (data, response) = try await URLSession.shared.data(for: request)

        print("Received response from OpenAI")

        guard let httpResponse = response as? HTTPURLResponse else {
            print("ERROR: Invalid HTTP response")
            throw OpenAIError.invalidResponse
        }

        print("HTTP Status Code: \(httpResponse.statusCode)")

        guard httpResponse.statusCode == 200 else {
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorJson["error"] as? [String: Any],
               let message = error["message"] as? String {
                print("ERROR: OpenAI API Error: \(message)")
                if let errorData = String(data: data, encoding: .utf8) {
                    print("Full error response: \(errorData)")
                }
                throw OpenAIError.apiError(message)
            }
            print("ERROR: HTTP Error \(httpResponse.statusCode)")
            if let errorData = String(data: data, encoding: .utf8) {
                print("Response body: \(errorData)")
            }
            throw OpenAIError.httpError(httpResponse.statusCode)
        }

        
        print("Parsing JSON response...")
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let choices = json?["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            print("ERROR: Failed to extract content from response")
            if let rawResponse = String(data: data, encoding: .utf8) {
                print("Raw response: \(rawResponse)")
            }
            throw OpenAIError.invalidResponse
        }

        print("\n=== CHATGPT RESPONSE START ===")
        print(content)
        print("=== CHATGPT RESPONSE END ===\n")

        
        guard let contentData = content.data(using: .utf8) else {
            print("ERROR: Failed to convert content to UTF-8 data")
            throw OpenAIError.invalidJSON
        }

        print("Decoding JSON into ParsedDentalNotes...")
        let decoder = JSONDecoder()
        do {
            let parsedNotes = try decoder.decode(ParsedDentalNotes.self, from: contentData)
            print("✅ Successfully parsed dental notes!")
            print("  - Treatment plan: \(parsedNotes.treatmentPlan != nil ? "YES" : "NO")")
            print("  - Post-op instructions: \(parsedNotes.postOpInstructions != nil ? "YES" : "NO")")
            print("  - Appointments: \(parsedNotes.appointments.count)")
            print("  - Medications: \(parsedNotes.medications.count)")
            print("  - Diet restrictions: \(parsedNotes.dietRestrictions.count)")
            print("  - Procedures: \(parsedNotes.procedures.count)")
            print("  - General notes: \(parsedNotes.generalNotes != nil ? "YES" : "NO")")
            print("=== DENTAL NOTES PARSING COMPLETED ===\n")
            return parsedNotes
        } catch {
            print("ERROR: Failed to decode JSON: \(error)")
            print("Trying to extract JSON from markdown code block...")

            
            if let jsonMatch = content.range(of: "```json\\s*([\\s\\S]*?)```", options: .regularExpression) {
                let jsonString = String(content[jsonMatch]).replacingOccurrences(of: "```json", with: "").replacingOccurrences(of: "```", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                print("Found JSON in code block, trying to parse...")
                if let cleanData = jsonString.data(using: .utf8) {
                    let cleanParsed = try decoder.decode(ParsedDentalNotes.self, from: cleanData)
                    print("✅ Successfully parsed from code block!")
                    return cleanParsed
                }
            }

            print("ERROR: Could not parse JSON response")
            throw OpenAIError.invalidJSON
        }
    }

    

    func parseDentalNotes(images: [UIImage]) async throws -> ParsedDentalNotes {
        print("=== DENTAL NOTES PARSING STARTED ===")
        print("Number of images to process: \(images.count)")

        guard !apiKey.isEmpty else {
            print("ERROR: OpenAI API key is missing!")
            throw OpenAIError.missingAPIKey
        }

        print("API key found: \(apiKey.prefix(10))...")


        let base64Images = await withTaskGroup(of: (Int, String?).self) { group in
            for (index, image) in images.enumerated() {
                group.addTask {
                    await Task.detached {
                        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
                            return (index, nil)
                        }
                        let base64String = imageData.base64EncodedString()
                        return (index, base64String)
                    }.value
                }
            }

            var results: [(Int, String)] = []
            for await (index, base64String) in group {
                if let base64String = base64String {
                    results.append((index, base64String))
                    print("Image \(index + 1): Converted to base64 (size: \(base64String.count) chars)")
                } else {
                    print("WARNING: Failed to convert image \(index + 1) to JPEG data")
                }
            }

            return results.sorted(by: { $0.0 < $1.0 }).map { $0.1 }
        }

        print("Total base64 images: \(base64Images.count)")

        
        let systemPrompt = """
        You are a dental notes parser. Your job is to extract structured information from dental/dentist notes, treatment plans, and appointment records.

        Extract the following information and return it as a JSON object:
        1. Treatment Plan (description, duration, goals)
        2. Post-Op Instructions (instructions array, duration, warnings)
        3. Appointments (title, date in YYYY-MM-DD or YYYY-MM-DD HH:mm format, location, dentist name, notes)
        4. Medications (name, dosage, frequency, duration, special instructions)
        5. Diet Restrictions (type: softOnly/noHard/noSticky/noChewy/noHot/noCold/noSugary/noAcidic, duration, reason)
        6. Procedures performed (type: filling/crown/extraction/implant/rootCanal/cleaning, tooth numbers, date, notes)
        7. General notes (any other important information)

        Return ONLY valid JSON matching this structure:
        {
            "treatmentPlan": { "description": "", "duration": "", "goals": [] },
            "postOpInstructions": { "instructions": [], "duration": "", "warnings": [] },
            "appointments": [{ "title": "", "date": "", "location": "", "dentistName": "", "notes": "" }],
            "medications": [{ "name": "", "dosage": "", "frequency": "", "duration": "", "instructions": "" }],
            "dietRestrictions": [{ "type": "", "duration": "", "reason": "" }],
            "procedures": [{ "type": "", "toothNumbers": [], "date": "", "notes": "" }],
            "generalNotes": ""
        }

        If a field is not found in the notes, omit it or use null. Be thorough and extract all relevant information.
        """

        let userPrompt = "Please parse the following dental notes and extract all relevant information."

        
        var messages: [[String: Any]] = [
            ["role": "system", "content": systemPrompt]
        ]

        
        var userContent: [[String: Any]] = [
            ["type": "text", "text": userPrompt]
        ]

        for base64Image in base64Images {
            userContent.append([
                "type": "image_url",
                "image_url": [
                    "url": "data:image/jpeg;base64,\(base64Image)"
                ]
            ])
        }

        messages.append([
            "role": "user",
            "content": userContent
        ])

        
        let requestBody: [String: Any] = [
            "model": "gpt-4o", 
            "messages": messages,
            "max_tokens": 2000,
            "temperature": 0.1 
        ]

        
        print("Sending request to OpenAI API...")
        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let requestSize = request.httpBody?.count ?? 0
        print("Request body size: \(requestSize) bytes")

        let (data, response) = try await URLSession.shared.data(for: request)

        print("Received response from OpenAI")

        guard let httpResponse = response as? HTTPURLResponse else {
            print("ERROR: Invalid HTTP response")
            throw OpenAIError.invalidResponse
        }

        print("HTTP Status Code: \(httpResponse.statusCode)")

        guard httpResponse.statusCode == 200 else {
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorJson["error"] as? [String: Any],
               let message = error["message"] as? String {
                print("ERROR: OpenAI API Error: \(message)")
                if let errorData = String(data: data, encoding: .utf8) {
                    print("Full error response: \(errorData)")
                }
                throw OpenAIError.apiError(message)
            }
            print("ERROR: HTTP Error \(httpResponse.statusCode)")
            if let errorData = String(data: data, encoding: .utf8) {
                print("Response body: \(errorData)")
            }
            throw OpenAIError.httpError(httpResponse.statusCode)
        }

        
        print("Parsing JSON response...")
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let choices = json?["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            print("ERROR: Failed to extract content from response")
            if let rawResponse = String(data: data, encoding: .utf8) {
                print("Raw response: \(rawResponse)")
            }
            throw OpenAIError.invalidResponse
        }

        print("\n=== CHATGPT RESPONSE START ===")
        print(content)
        print("=== CHATGPT RESPONSE END ===\n")

        
        guard let contentData = content.data(using: .utf8) else {
            print("ERROR: Failed to convert content to UTF-8 data")
            throw OpenAIError.invalidJSON
        }

        print("Decoding JSON into ParsedDentalNotes...")
        let decoder = JSONDecoder()
        do {
            let parsedNotes = try decoder.decode(ParsedDentalNotes.self, from: contentData)
            print("✅ Successfully parsed dental notes!")
            print("  - Treatment plan: \(parsedNotes.treatmentPlan != nil ? "YES" : "NO")")
            print("  - Post-op instructions: \(parsedNotes.postOpInstructions != nil ? "YES" : "NO")")
            print("  - Appointments: \(parsedNotes.appointments.count)")
            print("  - Medications: \(parsedNotes.medications.count)")
            print("  - Diet restrictions: \(parsedNotes.dietRestrictions.count)")
            print("  - Procedures: \(parsedNotes.procedures.count)")
            print("  - General notes: \(parsedNotes.generalNotes != nil ? "YES" : "NO")")
            print("=== DENTAL NOTES PARSING COMPLETED ===\n")
            return parsedNotes
        } catch {
            print("ERROR: Failed to decode JSON: \(error)")
            print("Trying to extract JSON from markdown code block...")

            
            if let jsonMatch = content.range(of: "```json\\s*([\\s\\S]*?)```", options: .regularExpression) {
                let jsonString = String(content[jsonMatch]).replacingOccurrences(of: "```json", with: "").replacingOccurrences(of: "```", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                print("Found JSON in code block, trying to parse...")
                if let cleanData = jsonString.data(using: .utf8) {
                    let cleanParsed = try decoder.decode(ParsedDentalNotes.self, from: cleanData)
                    print("✅ Successfully parsed from code block!")
                    return cleanParsed
                }
            }

            print("ERROR: Could not parse JSON response")
            throw OpenAIError.invalidJSON
        }
    }
}

enum OpenAIError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case invalidJSON
    case httpError(Int)
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "OpenAI API key is not configured"
        case .invalidResponse:
            return "Invalid response from OpenAI"
        case .invalidJSON:
            return "Failed to parse JSON from OpenAI response"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .apiError(let message):
            return "OpenAI API error: \(message)"
        }
    }
}
