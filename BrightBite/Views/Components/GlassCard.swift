//
//  GlassCard.swift
//  BrightBite
//
//  Created by Tuan Nguyen on 9/15/25.
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
                        icon: "figure.stand",
                        title: "Pain Map",
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

struct DentalSummaryCard: View {
    let summary: DentalSummary?

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Dental Summary")
                    .font(.headline)
                    .fontWeight(.semibold)

                if let summary = summary {
                    Text(summary.summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 4)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if summary.teethInPain == 0 && summary.activeTreatments == 0 && summary.upcomingAppointments == 0 {
                        Text("No treatment plans occurring")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .italic()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 8)
                    } else {
                        HStack(spacing: 16) {
                            if summary.teethInPain > 0 {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .font(.caption)
                                            .foregroundStyle(.orange)
                                        Text("\(summary.teethInPain)")
                                            .font(.title3)
                                            .fontWeight(.semibold)
                                    }
                                    Text("In Pain")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            if summary.activeTreatments > 0 {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "pills.fill")
                                            .font(.caption)
                                            .foregroundStyle(.blue)
                                        Text("\(summary.activeTreatments)")
                                            .font(.title3)
                                            .fontWeight(.semibold)
                                    }
                                    Text("Treatments")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            if summary.upcomingAppointments > 0 {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "calendar")
                                            .font(.caption)
                                            .foregroundStyle(.green)
                                        Text("\(summary.upcomingAppointments)")
                                            .font(.title3)
                                            .fontWeight(.semibold)
                                    }
                                    Text("Upcoming")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Spacer()
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Loading summary...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct RecentActivityCard: View {
    @EnvironmentObject var tabNavigation: TabNavigationManager
    let activities: [RecentActivity]
    let onViewDocument: ((String) -> Void)?
    let onViewTooth: ((Int) -> Void)?

    init(activities: [RecentActivity], onViewDocument: ((String) -> Void)? = nil, onViewTooth: ((Int) -> Void)? = nil) {
        self.activities = activities
        self.onViewDocument = onViewDocument
        self.onViewTooth = onViewTooth
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Recent Activity")
                    .font(.headline)
                    .fontWeight(.semibold)

                if activities.isEmpty {
                    Text("No recent activity")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ForEach(activities) { activity in
                        HStack {
                            Image(systemName: iconForActivityType(activity.type))
                                .font(.caption)
                                .foregroundStyle(colorForActivityType(activity.type))
                                .frame(width: 20)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(activity.date)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                Text(activity.description)
                                    .font(.subheadline)
                            }

                            Spacer()

                            if activity.type == .notesScan, activity.documentId != nil {
                                Button("View") {
                                    if let docId = activity.documentId {
                                        onViewDocument?(docId)
                                    }
                                }
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.thinMaterial, in: Capsule())
                            }

                            if activity.type == .toothUpdate, let toothNumber = activity.toothNumber {
                                Button("View") {
                                    onViewTooth?(toothNumber)
                                }
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.thinMaterial, in: Capsule())
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func iconForActivityType(_ type: ActivityType) -> String {
        switch type {
        case .chewCheck: return "camera.viewfinder"
        case .painLog: return "exclamationmark.triangle.fill"
        case .appointment: return "calendar"
        case .notesScan: return "doc.text.viewfinder"
        case .medication: return "pills.fill"
        case .toothUpdate: return "tooth.fill"
        }
    }

    private func colorForActivityType(_ type: ActivityType) -> Color {
        switch type {
        case .chewCheck: return .blue
        case .painLog: return .orange
        case .appointment: return .green
        case .notesScan: return .purple
        case .medication: return .pink
        case .toothUpdate: return .cyan
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
