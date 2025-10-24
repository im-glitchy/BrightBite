//
//  ScanConfirmationChatView.swift
//  BrightBite
//
//  Created by Tuan Nguyen on 9/1/25.
//

import SwiftUI

enum ScanFlowState {
    case summarizing 
    case chatting 
    case parsingToJSON 
    case reviewingCategories 
    case placingData 
    case completed
}

struct ScanConfirmationChatView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var firebaseService: FirebaseService

    let ocrText: String
    let scannedImages: [UIImage]

    @State private var flowState: ScanFlowState = .summarizing
    @State private var messages: [ChatMessage] = []
    @State private var conversationHistory: [[String: String]] = [] 
    @State private var userInput = ""
    @State private var isProcessing = false
    @State private var parsedData: ParsedDentalNotes?
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 16) {
                            ForEach(messages) { message in
                                MessageBubble(message: message)
                                    .id(message.id)
                            }

                            if isProcessing {
                                HStack {
                                    ProgressView()
                                    Text(processingMessage)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding()
                            }
                        }
                        .padding()
                    }
                    .onChange(of: messages.count) { _, _ in
                        if let lastMessage = messages.last {
                            withAnimation {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }

                Divider()

                
                if flowState != .completed {
                    HStack(spacing: 12) {
                        TextField("Type your message...", text: $userInput)
                            .textFieldStyle(.roundedBorder)
                            .disabled(isProcessing)

                        Button(action: sendMessage) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.title2)
                                .foregroundStyle(userInput.isEmpty ? .gray : .blue)
                        }
                        .disabled(userInput.isEmpty || isProcessing)
                    }
                    .padding()
                }
            }
            .navigationTitle("Review Scan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            startScanFlow()
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }

    private var processingMessage: String {
        switch flowState {
        case .summarizing:
            return "Creating summary..."
        case .parsingToJSON:
            return "Extracting structured data..."
        case .placingData:
            return "Saving to your profile..."
        default:
            return "Processing..."
        }
    }

    

    private func startScanFlow() {
        
        let wordCount = ocrText.split(separator: " ").count
        let characterCount = ocrText.count

        print("📊 OCR Quality Check: \(wordCount) words, \(characterCount) characters")

        
        if wordCount < 10 || characterCount < 75 {
            print("⚠️ OCR text too short - not sending to ChatGPT")

            let failureMessage = ChatMessage(
                content: """
                ⚠️ **Scan Quality Too Low**

                The scanned text is too short to process reliably:
                • Words detected: \(wordCount) (minimum: 10)
                • Characters detected: \(characterCount) (minimum: 75)

                This usually happens when:
                • The document wasn't fully in frame
                • The image is blurry or low quality
                • The lighting was poor

                **Please try again with:**
                ✓ Better lighting
                ✓ Document fully in frame
                ✓ Camera held steady
                ✓ Clear, high-resolution image

                We limit API calls to save credits and ensure accurate results.
                """,
                isFromBot: true
            )
            messages.append(failureMessage)

            flowState = .completed
            isProcessing = false

            return
        }

        
        flowState = .summarizing
        isProcessing = true

        Task {
            do {
                let summary = try await OpenAIService.shared.summarizeDentalNotes(ocrText: ocrText)

                await MainActor.run {
                    
                    let summaryMessage = ChatMessage(
                        content: summary,
                        isFromBot: true
                    )
                    messages.append(summaryMessage)

                    
                    conversationHistory.append(["role": "user", "content": "Here is the dental document text:\n\n\(ocrText)"])
                    conversationHistory.append(["role": "assistant", "content": summary])

                    
                    let confirmMessage = ChatMessage(
                        content: "Is this information correct? Feel free to ask me questions or request changes before I save it to your profile.",
                        isFromBot: true
                    )
                    messages.append(confirmMessage)

                    flowState = .chatting
                    isProcessing = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to summarize: \(error.localizedDescription)"
                    showError = true
                    isProcessing = false
                }
            }
        }
    }

    private func sendMessage() {
        let message = userInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty else { return }

        
        let userMessage = ChatMessage(content: message, isFromBot: false)
        messages.append(userMessage)
        conversationHistory.append(["role": "user", "content": message])

        userInput = ""
        isProcessing = true

        
        let lowerMessage = message.lowercased()
        let isConfirming = lowerMessage.contains("yes") || lowerMessage.contains("correct") ||
                          lowerMessage.contains("looks good") || lowerMessage.contains("confirm") ||
                          lowerMessage.contains("save") || lowerMessage.contains("ok")

        if flowState == .chatting && isConfirming {
            
            proceedToJSONParsing()
        } else if flowState == .reviewingCategories && isConfirming {
            
            placeDataIntoSections()
        } else {
            
            continueConversation(userMessage: message)
        }
    }

    private func continueConversation(userMessage: String) {
        Task {
            do {
                
                let response = try await sendChatMessage(userMessage)

                await MainActor.run {
                    let assistantMessage = ChatMessage(content: response, isFromBot: true)
                    messages.append(assistantMessage)
                    conversationHistory.append(["role": "assistant", "content": response])
                    isProcessing = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to process message: \(error.localizedDescription)"
                    showError = true
                    isProcessing = false
                }
            }
        }
    }

    private func sendChatMessage(_ message: String) async throws -> String {
        guard let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"], !apiKey.isEmpty else {
            throw OpenAIError.missingAPIKey
        }

        var messages: [[String: Any]] = []

        
        for msg in conversationHistory {
            if let role = msg["role"], let content = msg["content"] {
                messages.append(["role": role, "content": content])
            }
        }

        let requestBody: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": messages,
            "max_tokens": 500,
            "temperature": 0.7
        ]

        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw OpenAIError.invalidResponse
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let choices = json?["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw OpenAIError.invalidResponse
        }

        return content
    }

    private func proceedToJSONParsing() {
        flowState = .parsingToJSON

        Task {
            do {
                
                let parsed = try await OpenAIService.shared.parseDentalNotesWithContext(
                    ocrText: ocrText,
                    conversationHistory: conversationHistory
                )

                await MainActor.run {
                    parsedData = parsed

                    
                    let categoryMessage = buildCategoryPreviewMessage(parsed: parsed)
                    let assistantMessage = ChatMessage(content: categoryMessage, isFromBot: true)
                    messages.append(assistantMessage)

                    let confirmMessage = ChatMessage(
                        content: "Does this look correct? Reply 'yes' to save, or tell me what to change.",
                        isFromBot: true
                    )
                    messages.append(confirmMessage)

                    flowState = .reviewingCategories
                    isProcessing = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to parse data: \(error.localizedDescription)"
                    showError = true
                    isProcessing = false
                    flowState = .chatting
                }
            }
        }
    }

    private func buildCategoryPreviewMessage(parsed: ParsedDentalNotes) -> String {
        var message = "I've organized your information:\n\n"

        
        if let documentDate = parsed.documentDate {
            if let date = parseDateFromString(documentDate) {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                let monthsAgo = Calendar.current.dateComponents([.month], from: date, to: Date()).month ?? 0
                let isCurrent = monthsAgo <= 3

                message += "📅 **Document Date:** \(formatter.string(from: date))\n"
                if isCurrent {
                    message += "✅ This is current information (within last 3 months)\n\n"
                } else {
                    message += "📚 This is historical information (older than 3 months)\n"
                    message += "⚠️ Treatment plan items will be saved to medical history only\n\n"
                }
            }
        } else {
            message += "⚠️ **Document Date:** Not found - assuming current\n\n"
        }

        
        message += "**Treatment Plan:**\n"
        if let plan = parsed.treatmentPlan {
            message += "• \(plan.description)\n"
            if let duration = plan.duration {
                message += "• Duration: \(duration)\n"
            }
        }
        if !parsed.medications.isEmpty {
            message += "• \(parsed.medications.count) medication(s)\n"
        }
        if !parsed.dietRestrictions.isEmpty {
            message += "• \(parsed.dietRestrictions.count) diet restriction(s)\n"
        }

        
        message += "\n**Appointments:**\n"
        if parsed.appointments.isEmpty {
            message += "• No appointments found\n"
        } else {
            for appt in parsed.appointments {
                message += "• \(appt.title) on \(appt.date)\n"
            }
        }

        
        message += "\n**Medical History:**\n"
        if !parsed.procedures.isEmpty {
            message += "• \(parsed.procedures.count) procedure(s) recorded\n"
        }
        if let generalNotes = parsed.generalNotes, !generalNotes.isEmpty {
            message += "• General notes saved\n"
        }
        if parsed.postOpInstructions != nil {
            message += "• Post-op instructions saved\n"
        }

        return message
    }

    private func placeDataIntoSections() {
        guard let parsed = parsedData,
              let userId = firebaseService.currentUser?.id else {
            return
        }

        flowState = .placingData

        Task {
            do {
                
                for (index, image) in scannedImages.enumerated() {
                    let filename = try await PhotoStorageService.shared.savePersistentPhoto(
                        image,
                        userId: userId,
                        type: .dentistNote
                    )
                    print("Saved scanned note image \(index + 1): \(filename)")
                }

                
                let documentDate = parseDateFromString(parsed.documentDate)

                
                try await firebaseService.saveScannedNoteData(
                    parsedData: parsed,
                    documentDate: documentDate,
                    for: userId
                )

                await MainActor.run {
                    let dateInfo: String
                    if let docDate = documentDate {
                        let formatter = DateFormatter()
                        formatter.dateStyle = .medium
                        formatter.timeStyle = .none
                        dateInfo = " (document dated \(formatter.string(from: docDate)))"
                    } else {
                        dateInfo = ""
                    }

                    let successMessage = ChatMessage(
                        content: "✅ All done! Your information has been saved to your profile\(dateInfo).",
                        isFromBot: true
                    )
                    messages.append(successMessage)

                    flowState = .completed
                    isProcessing = false

                    
                    NotificationCenter.default.post(name: NSNotification.Name("RefreshUserData"), object: nil)

                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        dismiss()
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to save data: \(error.localizedDescription)"
                    showError = true
                    isProcessing = false
                }
            }
        }
    }

    private func parseDateFromString(_ dateString: String?) -> Date? {
        guard let dateString = dateString else { return nil }

        let formatter = DateFormatter()

        
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


struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if !message.isFromBot {
                Spacer()
            }

            VStack(alignment: message.isFromBot ? .leading : .trailing, spacing: 4) {
                Text(message.content)
                    .font(.body)
                    .padding(12)
                    .background(
                        message.isFromBot ? Color.gray.opacity(0.2) : Color.blue,
                        in: RoundedRectangle(cornerRadius: 16)
                    )
                    .foregroundStyle(message.isFromBot ? Color.primary : Color.white)

                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: 280, alignment: message.isFromBot ? .leading : .trailing)

            if message.isFromBot {
                Spacer()
            }
        }
    }
}

#Preview {
    ScanConfirmationChatView(
        ocrText: "Sample dental note text...",
        scannedImages: []
    )
    .environmentObject(FirebaseService.shared)
}
