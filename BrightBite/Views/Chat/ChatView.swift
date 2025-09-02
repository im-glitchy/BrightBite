//
//  ChatView.swift
//  BrightBite
//
//  Created by Tuan Nguyen on 9/1/25.
//

import SwiftUI

struct ChatView: View {
    @State private var messages: [ChatMessage] = [
        ChatMessage(content: "Hi! I'm DentalBot, your AI dental assistant. I can help answer questions about your treatment, diet restrictions, pain management, and more. What would you like to know?", isFromBot: true)
    ]
    @State private var newMessage = ""
    @State private var showChewCheck = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Messages list
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
                }
                
                // Input bar
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
        
        // Simulate bot response
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            let botResponse = generateBotResponse(for: messageToSend)
            messages.append(botResponse)
        }
    }
    
    private func generateBotResponse(for userMessage: String) -> ChatMessage {
        // Simple response simulation - in real app, this would call OpenAI API
        let responses = [
            "I understand your concern. Based on your treatment plan, here's what I recommend...",
            "That's a great question! For your specific situation with braces...",
            "Let me help you with that. According to your recent records...",
            "I can provide some guidance on that. Given your soft-food restriction..."
        ]
        
        let content = responses.randomElement() ?? "I'm here to help with your dental care questions."
        
        // Add some action chips for certain types of questions
        var actionChips: [ActionChip] = []
        if userMessage.lowercased().contains("pain") {
            actionChips.append(ActionChip(title: "Update Pain Map", action: .updatePainMap))
        }
        if userMessage.lowercased().contains("appointment") {
            actionChips.append(ActionChip(title: "Schedule Appointment", action: .scheduleAppointment))
        }
        
        return ChatMessage(content: content, isFromBot: true, actionChips: actionChips)
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
                
                // Action chips for bot messages
                if message.isFromBot && !message.actionChips.isEmpty {
                    HStack {
                        ForEach(message.actionChips) { chip in
                            Button(chip.title) {
                                // Handle chip action
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
        // TODO: Implement chip actions
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