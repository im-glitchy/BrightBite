//
//  WebAPIService.swift
//  BrightBite
//
//  Created by Tuan Nguyen on 9/1/25.
//

import Foundation
import UIKit

struct FoodAnalysisRequest: Codable {
    let imageBase64: String
    let userContext: UserContextData?
}

struct UserContextData: Codable {
    let hasBraces: Bool
    let dietRestrictions: [String]
    let recentProcedures: [String]
}

struct FoodAnalysisResponse: Codable {
    let foodName: String
    let confidence: Double
    let verdict: String 
    let tags: [String]
    let reasons: [String]
    let alternatives: [String]
    let source: String 
}

class WebAPIService {
    static let shared = WebAPIService()

    
    private let baseURL: String

    private init() {
        
        if let envURL = ProcessInfo.processInfo.environment["API_BASE_URL"] {
            self.baseURL = envURL
        } else {
            
            self.baseURL = "https://brightbite.tuandnguyen.dev/api"
            
        }
    }

    

    func analyzeFoodImage(_ image: UIImage, userContext: UserContextData?) async throws -> FoodAnalysisResponse {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw WebAPIError.invalidImage
        }

        let base64Image = imageData.base64EncodedString()

        let request = FoodAnalysisRequest(
            imageBase64: base64Image,
            userContext: userContext
        )

        let url = URL(string: "\(baseURL)/analyze-food")!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = 30 

        let encoder = JSONEncoder()
        urlRequest.httpBody = try encoder.encode(request)

        print("DEBUG WebAPIService: Sending request to \(url.absoluteString)")

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw WebAPIError.invalidResponse
        }

        print("DEBUG WebAPIService: Response status code: \(httpResponse.statusCode)")

        guard httpResponse.statusCode == 200 else {
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMessage = errorJson["error"] as? String {
                throw WebAPIError.apiError(errorMessage)
            }
            throw WebAPIError.httpError(httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        let analysisResponse = try decoder.decode(FoodAnalysisResponse.self, from: data)

        return analysisResponse
    }

    

    func healthCheck() async throws -> Bool {
        let url = URL(string: "\(baseURL)/health")!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        urlRequest.timeoutInterval = 5

        do {
            let (data, response) = try await URLSession.shared.data(for: urlRequest)

            guard let httpResponse = response as? HTTPURLResponse else {
                return false
            }

            if httpResponse.statusCode == 200 {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let status = json["status"] as? String {
                    return status == "healthy"
                }
            }
            return false
        } catch {
            print("DEBUG WebAPIService: Health check failed: \(error)")
            return false
        }
    }

    

    func getBaseURL() -> String {
        return baseURL
    }

    func isConfigured() -> Bool {
        return !baseURL.contains("your-domain.com")
    }
}

enum WebAPIError: LocalizedError {
    case invalidImage
    case invalidResponse
    case httpError(Int)
    case apiError(String)
    case notConfigured

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Failed to process image"
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let code):
            return "Server error: HTTP \(code)"
        case .apiError(let message):
            return "API error: \(message)"
        case .notConfigured:
            return "Web API is not configured. Please set your server URL in WebAPIService.swift"
        }
    }
}
