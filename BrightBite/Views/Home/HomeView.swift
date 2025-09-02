//
//  HomeView.swift
//  BrightBite
//
//  Created by Tuan Nguyen on 9/1/25.
//

import SwiftUI

struct HomeView: View {
    @State private var careTasks: [CareTask] = [
        CareTask(title: "Rinse with salt water", category: .hygiene),
        CareTask(title: "Take ibuprofen", category: .medication),
        CareTask(title: "Switch to tray #14", category: .appliance),
        CareTask(title: "Avoid hard foods", category: .diet)
    ]
    
    @State private var recentActivities: [RecentActivity] = [
        RecentActivity(date: "Yesterday", description: "ChewCheck — Yogurt: Safe", type: .chewCheck),
        RecentActivity(date: "Tuesday", description: "Filling #19 recorded", type: .painLog),
        RecentActivity(date: "Monday", description: "Notes scanned", type: .notesScan)
    ]
    
    @State private var showProfile = false
    @State private var showChewCheck = false
    @State private var showPainLog = false
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Welcome Card
                    WelcomeCard(
                        userName: "Sarah",
                        statusMessage: "Soft foods for 5 more days"
                    ) {
                        // Jump to Chat tab
                        selectedTab = 1
                    }
                    
                    // Today's Care Card
                    TodaysCareCard(tasks: $careTasks)
                    
                    // Quick Actions Card
                    QuickActionsCard(
                        onScanFood: { showChewCheck = true },
                        onAskBot: { selectedTab = 1 },
                        onLogPain: { showPainLog = true },
                        onNextAppointment: { /* Show appointment details */ }
                    )
                    
                    // Recent Activity Card
                    RecentActivityCard(activities: recentActivities)
                }
                .padding(.horizontal)
                .padding(.top)
            }
            .background(
                LinearGradient(
                    colors: [Color.blue.opacity(0.05), Color.clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showProfile = true }) {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 32, height: 32)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.caption)
                                    .foregroundStyle(.blue)
                            )
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Scan Food with ChewCheck") {
                            showChewCheck = true
                        }
                        Button("Log Pain") {
                            showPainLog = true
                        }
                        Button("Scan Dentist Notes") {
                            // TODO: Implement notes scanning
                        }
                        Button("Add Appointment") {
                            // TODO: Implement appointment creation
                        }
                    } label: {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 32, height: 32)
                            .overlay(
                                Image(systemName: "plus")
                                    .font(.caption)
                                    .foregroundStyle(.blue)
                            )
                    }
                }
            }
            .liquidGlassNavBar()
        }
        .sheet(isPresented: $showProfile) {
            ProfileSheet()
        }
        .sheet(isPresented: $showChewCheck) {
            ChewCheckView()
        }
        .sheet(isPresented: $showPainLog) {
            PainLogView()
        }
    }
}

struct ProfileSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Profile avatar
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 80, height: 80)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.blue)
                    )
                
                Text("Sarah Johnson")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Member since September 2025")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Button("Sign Out") {
                    // TODO: Implement sign out
                    dismiss()
                }
                .foregroundStyle(.red)
            }
            .padding()
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    HomeView()
}