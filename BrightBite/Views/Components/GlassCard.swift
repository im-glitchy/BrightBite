//
//  GlassCard.swift
//  BrightBite
//
//  Created by Tuan Nguyen on 9/1/25.
//

import SwiftUI

struct GlassCard<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding()
            .liquidGlassCard()
    }
}

struct WelcomeCard: View {
    let userName: String?
    let statusMessage: String?
    let onDentalBotTap: () -> Void
    
    var body: some View {
        GlassCard {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    if let userName = userName {
                        Text("Good morning, \(userName)")
                            .font(.title2)
                            .fontWeight(.medium)
                    } else {
                        Text("Welcome to BrightBite")
                            .font(.title2)
                            .fontWeight(.medium)
                    }
                    
                    if let statusMessage = statusMessage {
                        Text(statusMessage)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                Button("Ask DentalBot", action: onDentalBotTap)
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.thinMaterial, in: Capsule())
            }
        }
    }
}

struct TodaysCareCard: View {
    @Binding var tasks: [CareTask]
    
    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Today's Care")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                ForEach($tasks) { $task in
                    HStack {
                        Button(action: { task.isCompleted.toggle() }) {
                            Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(task.isCompleted ? .green : .secondary)
                        }
                        .dentalAccessibility(
                            label: task.isCompleted ? "Completed: \(task.title)" : "Mark \(task.title) as complete",
                            hint: task.isCompleted ? "Double tap to mark as incomplete" : "Double tap to mark as complete"
                        )
                        
                        Text(task.title)
                            .strikethrough(task.isCompleted)
                            .foregroundStyle(task.isCompleted ? .secondary : .primary)
                            .opacity(task.isCompleted ? 0.7 : 1.0)
                        
                        Spacer()
                    }
                }
            }
        }
    }
}

struct QuickActionsCard: View {
    let onScanFood: () -> Void
    let onAskBot: () -> Void
    let onLogPain: () -> Void
    let onNextAppointment: () -> Void
    
    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("Quick Actions")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                    QuickActionButton(
                        icon: "camera.viewfinder",
                        title: "Scan Food",
                        action: onScanFood
                    )
                    
                    QuickActionButton(
                        icon: "bubble.left",
                        title: "Ask DentalBot",
                        action: onAskBot
                    )
                    
                    QuickActionButton(
                        icon: "waveform.path.ecg",
                        title: "Log Pain",
                        action: onLogPain
                    )
                    
                    QuickActionButton(
                        icon: "calendar.badge.clock",
                        title: "Next Appointment",
                        action: onNextAppointment
                    )
                }
            }
        }
    }
}

struct QuickActionButton: View {
    let icon: String
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(.blue)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
            }
            .frame(height: 60)
        }
        .liquidGlassButton(style: .secondary)
    }
}

struct RecentActivityCard: View {
    let activities: [RecentActivity]
    
    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Recent Activity")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                ForEach(activities) { activity in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(activity.date)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            Text(activity.description)
                                .font(.subheadline)
                        }
                        
                        Spacer()
                    }
                }
            }
        }
    }
}

#Preview {
    VStack {
        WelcomeCard(userName: "Sarah", statusMessage: "Soft foods for 5 more days") {
            print("DentalBot tapped")
        }
        
        QuickActionsCard(
            onScanFood: { print("Scan food") },
            onAskBot: { print("Ask bot") },
            onLogPain: { print("Log pain") },
            onNextAppointment: { print("Next appointment") }
        )
    }
    .padding()
}