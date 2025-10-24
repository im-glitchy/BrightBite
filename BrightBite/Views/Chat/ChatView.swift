//
//  ChatView.swift
//  BrightBite
//
//  Created by Tuan Nguyen on 8/5/25.
//

import SwiftUI

struct ChatView: View {
    @EnvironmentObject private var firebaseService: FirebaseService
    @State private var messages: [ChatMessage] = [
        ChatMessage(content: "Hi! I'm DentalBot, your AI dental assistant. I can help answer questions about your treatment, diet restrictions, pain management, and more. What would you like to know?", isFromBot: true)
    ]
    @State private var newMessage = ""
    @State private var showChewCheck = false
    
    
    private var mockTreatmentPlan: TreatmentPlan {
        TreatmentPlan(
            restrictions: [
                DietRestriction(type: .softOnly, endDate: Calendar.current.date(byAdding: .day, value: 5, to: Date()), reason: "Recent extraction"),
                DietRestriction(type: .noSticky, reason: "Braces maintenance")
            ],
            currentTasks: [
                CareTask(title: "Switch to tray #14", category: .appliance),
                CareTask(title: "Wear elastics 12 hours/day", category: .appliance)
            ],
            doctorNotes: [
                DoctorNote(content: "Patient responding well to treatment. Continue current aligner schedule.", source: .appointment),
                DoctorNote(content: "Avoid hard foods for 1 week post-extraction", source: .scanned)
            ],
            medications: [
                Medication(name: "Ibuprofen", dosage: "400mg", frequency: "Every 6 hours", endDate: Calendar.current.date(byAdding: .day, value: 3, to: Date()), instructions: "Take with food")
            ],
            alignerProgress: AlignerProgress(currentTray: 14, totalTrays: 24, nextChangeDate: Calendar.current.date(byAdding: .day, value: 7, to: Date()))
        )
    }
    
    private var mockPainEntries: [PainEntry] {
        [
            PainEntry(toothNumber: 14, painLevel: 3.0, notes: "Mild sensitivity after extraction"),
            PainEntry(toothNumber: 18, painLevel: 2.0, notes: "Braces adjustment soreness")
        ]
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(messages) { message in
                                ChatBubble(message: message)
                                    .id(message.id)
                            }
                        }
                        .padding()
                    }
                    .onChange(of: messages.count) { _, _ in
                        if let lastMessage = messages.last {
                            withAnimation(.easeOut(duration: 0.3)) {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                    .onTapGesture {
                        
                        hideKeyboard()
                    }
                }
                
                
                HStack(spacing: 12) {
                    TextField("Ask a dental question…", text: $newMessage, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(1...4)
                    
                    Button(action: sendMessage) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundStyle(newMessage.isEmpty ? Color.secondary : Color.blue)
                    }
                    .disabled(newMessage.isEmpty)
                }
                .padding()
                .background(.ultraThinMaterial)
            }
            .background(
                LinearGradient(
                    colors: [Color.blue.opacity(0.05), Color.clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .navigationTitle("Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showChewCheck = true }) {
                        Image(systemName: "camera")
                            .foregroundStyle(Color.blue)
                    }
                }
            }
            .liquidGlassNavBar()
        }
        .sheet(isPresented: $showChewCheck) {
            ChewCheckView()
        }
    }
    
    private func sendMessage() {
        guard !newMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let userMessage = ChatMessage(content: newMessage, isFromBot: false)
        messages.append(userMessage)
        
        let messageToSend = newMessage
        newMessage = ""
        
        
        Task {
            do {
                
                let userProfile = firebaseService.currentUser ?? UserProfile(
                    id: "mock_user",
                    name: "Test User",
                    hasBraces: true
                )
                
                let context = DentalContext(
                    userProfile: userProfile,
                    treatmentPlan: mockTreatmentPlan,
                    recentPainEntries: mockPainEntries,
                    recentChewCheckResults: nil 
                )
                
                let response = try await DentalBotService.shared.sendMessage(messageToSend, context: context)
                
                await MainActor.run {
                    let botResponse = ChatMessage(content: response, isFromBot: true, actionChips: generateActionChips(for: messageToSend))
                    messages.append(botResponse)
                }
            } catch {
                await MainActor.run {
                    let errorResponse = ChatMessage(content: "I'm sorry, I'm having trouble connecting right now. Please try again later.", isFromBot: true)
                    messages.append(errorResponse)
                }
                print("DentalBot error: \(error)")
            }
        }
    }
    
    private func generateActionChips(for userMessage: String) -> [ActionChip] {
        
        var actionChips: [ActionChip] = []
        
        if userMessage.lowercased().contains("pain") {
            actionChips.append(ActionChip(title: "Update Pain Map", action: .updatePainMap))
        }
        if userMessage.lowercased().contains("appointment") {
            actionChips.append(ActionChip(title: "Schedule Appointment", action: .scheduleAppointment))
        }
        if userMessage.lowercased().contains("food") || userMessage.lowercased().contains("eat") {
            actionChips.append(ActionChip(title: "Check Food Safety", action: .addToPlan))
        }
        if userMessage.lowercased().contains("remind") || userMessage.lowercased().contains("remember") {
            actionChips.append(ActionChip(title: "Set Reminder", action: .setReminder))
        }
        
        return actionChips
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

struct ChatBubble: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if !message.isFromBot {
                Spacer(minLength: 50)
            }
            
            VStack(alignment: message.isFromBot ? .leading : .trailing, spacing: 8) {
                Text(message.content)
                    .padding()
                    .background(
                        message.isFromBot ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(.blue),
                        in: RoundedRectangle(cornerRadius: 16)
                    )
                    .foregroundStyle(message.isFromBot ? Color.primary : Color.white)
                
                
                if message.isFromBot && !message.actionChips.isEmpty {
                    HStack {
                        ForEach(message.actionChips) { chip in
                            Button(chip.title) {
                                
                                handleChipAction(chip.action)
                            }
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.thinMaterial, in: Capsule())
                            .foregroundStyle(Color.blue)
                        }
                        Spacer()
                    }
                }
            }
            
            if message.isFromBot {
                Spacer(minLength: 50)
            }
        }
    }
    
    private func handleChipAction(_ action: ChipAction) {
        
        switch action {
        case .addToPlan:
            print("Add to plan")
        case .setReminder:
            print("Set reminder")
        case .updatePainMap:
            print("Update pain map")
        case .scheduleAppointment:
            print("Schedule appointment")
        }
    }
}

#Preview {
    ChatView()
}
