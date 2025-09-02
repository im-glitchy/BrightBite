//
//  PlanView.swift
//  BrightBite
//
//  Created by Tuan Nguyen on 9/1/25.
//

import SwiftUI
import VisionKit

struct PlanView: View {
    @State private var userProfile = UserProfile(
        id: "user123",
        name: "Sarah Johnson",
        hasBraces: true,
        dentistInfo: DentistInfo(
            name: "Dr. Smith",
            phone: "(555) 123-4567",
            email: "dr.smith@dentistry.com",
            address: "123 Main St, City, State"
        )
    )
    
    @State private var treatmentPlan = TreatmentPlan(
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
    
    @State private var appointments: [Appointment] = [
        Appointment(
            date: Calendar.current.date(byAdding: .day, value: 14, to: Date()) ?? Date(),
            title: "Regular Checkup",
            dentistName: "Dr. Smith",
            location: "123 Main St"
        )
    ]
    
    @State private var showNotesScanner = false
    @State private var showEditProfile = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Profile Section
                    ProfileSection(profile: userProfile) {
                        showEditProfile = true
                    }
                    
                    // Treatment Plan Section
                    TreatmentPlanSection(plan: treatmentPlan) {
                        showNotesScanner = true
                    }
                    
                    // Appointments Section
                    AppointmentsSection(appointments: appointments)
                    
                    // Medical History Section
                    MedicalHistorySection(plan: treatmentPlan)
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
            .navigationTitle("Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showEditProfile = true }) {
                        Image(systemName: "pencil")
                            .foregroundStyle(.blue)
                    }
                }
            }
            .liquidGlassNavBar()
        }
        .sheet(isPresented: $showEditProfile) {
            EditProfileSheet(profile: $userProfile)
        }
        .sheet(isPresented: $showNotesScanner) {
            NotesDocumentScanner { scannedText in
                processScannedNotes(scannedText)
            }
        }
    }
    
    private func processScannedNotes(_ text: String) {
        // TODO: Parse scanned text and extract relevant information
        let newNote = DoctorNote(content: text, source: .scanned)
        treatmentPlan.doctorNotes.append(newNote)
    }
}

struct ProfileSection: View {
    let profile: UserProfile
    let onEdit: () -> Void
    
    var body: some View {
        GlassCard {
            VStack(spacing: 16) {
                HStack {
                    Text("Profile")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Button("Edit", action: onEdit)
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
                
                HStack(spacing: 16) {
                    // Profile avatar
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 60, height: 60)
                        .overlay(
                            Text(String(profile.name?.prefix(1) ?? "U"))
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundStyle(.blue)
                        )
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(profile.name ?? "User")
                            .font(.title3)
                            .fontWeight(.semibold)
                        
                        if profile.hasBraces {
                            StatusPill(text: "Braces Active", color: .blue)
                        }
                        
                        if let dentist = profile.dentistInfo {
                            Text(dentist.name)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Spacer()
                }
                
                // Quick actions
                HStack(spacing: 12) {
                    Button("Export Data") {
                        // TODO: Export user data
                    }
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.thinMaterial, in: Capsule())
                    
                    Button("Delete Account") {
                        // TODO: Delete account
                    }
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.red.opacity(0.2), in: Capsule())
                    .foregroundStyle(.red)
                    
                    Spacer()
                }
            }
        }
    }
}

struct TreatmentPlanSection: View {
    let plan: TreatmentPlan
    let onScanNotes: () -> Void
    
    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Treatment Plan")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Button(action: onScanNotes) {
                        Image(systemName: "doc.viewfinder")
                            .foregroundStyle(.blue)
                    }
                }
                
                // Diet Restrictions
                if !plan.restrictions.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Diet Restrictions")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        ForEach(plan.restrictions) { restriction in
                            RestrictionRow(restriction: restriction)
                        }
                    }
                }
                
                Divider()
                
                // Current Tasks
                if !plan.currentTasks.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Current Tasks")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        ForEach(plan.currentTasks) { task in
                            HStack {
                                Image(systemName: "circle")
                                    .foregroundStyle(.blue)
                                Text(task.title)
                                    .font(.body)
                                Spacer()
                            }
                        }
                    }
                }
                
                // Aligner Progress
                if let progress = plan.alignerProgress {
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Aligner Progress")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        HStack {
                            Text("Tray \(progress.currentTray) of \(progress.totalTrays)")
                                .font(.body)
                            
                            Spacer()
                            
                            if let nextChange = progress.nextChangeDate {
                                Text("Next: \(nextChange, style: .date)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        ProgressView(value: Double(progress.currentTray), total: Double(progress.totalTrays))
                            .tint(.blue)
                    }
                }
            }
        }
    }
}

struct RestrictionRow: View {
    let restriction: DietRestriction
    
    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.caption)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(restriction.type.rawValue.capitalized)
                    .font(.body)
                
                if let endDate = restriction.endDate {
                    Text("Until \(endDate, style: .date)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                if let reason = restriction.reason {
                    Text(reason)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
        }
    }
}

struct AppointmentsSection: View {
    let appointments: [Appointment]
    
    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("Appointments")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                ForEach(appointments) { appointment in
                    AppointmentRow(appointment: appointment)
                }
                
                Button("Add Appointment") {
                    // TODO: Add appointment
                }
                .font(.caption)
                .foregroundStyle(.blue)
            }
        }
    }
}

struct AppointmentRow: View {
    let appointment: Appointment
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(appointment.title)
                    .font(.body)
                    .fontWeight(.medium)
                
                Text(appointment.date, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                if let dentist = appointment.dentistName {
                    Text(dentist)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            Button("View") {
                // TODO: View appointment details
            }
            .font(.caption)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.thinMaterial, in: Capsule())
        }
    }
}

struct MedicalHistorySection: View {
    let plan: TreatmentPlan
    
    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("Medical History")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                // Recent notes
                ForEach(plan.doctorNotes.prefix(3)) { note in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(note.createdAt, style: .date)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Text(note.content)
                            .font(.body)
                        
                        StatusPill(text: note.source.rawValue.capitalized, color: .gray)
                    }
                    .padding(.bottom, 8)
                }
                
                Button("View All History") {
                    // TODO: View full medical history
                }
                .font(.caption)
                .foregroundStyle(.blue)
            }
        }
    }
}

struct EditProfileSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var profile: UserProfile
    
    var body: some View {
        NavigationView {
            Form {
                Section("Personal Information") {
                    TextField("Name", text: Binding(
                        get: { profile.name ?? "" },
                        set: { profile.name = $0.isEmpty ? nil : $0 }
                    ))
                    
                    Toggle("Has Braces", isOn: $profile.hasBraces)
                }
                
                Section("Dentist Information") {
                    TextField("Dentist Name", text: Binding(
                        get: { profile.dentistInfo?.name ?? "" },
                        set: { 
                            if profile.dentistInfo == nil {
                                profile.dentistInfo = DentistInfo(name: $0)
                            } else {
                                profile.dentistInfo?.name = $0
                            }
                        }
                    ))
                    
                    TextField("Phone", text: Binding(
                        get: { profile.dentistInfo?.phone ?? "" },
                        set: { profile.dentistInfo?.phone = $0.isEmpty ? nil : $0 }
                    ))
                    
                    TextField("Email", text: Binding(
                        get: { profile.dentistInfo?.email ?? "" },
                        set: { profile.dentistInfo?.email = $0.isEmpty ? nil : $0 }
                    ))
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { 
                        // TODO: Save profile changes
                        dismiss() 
                    }
                }
            }
        }
    }
}

struct NotesDocumentScanner: UIViewControllerRepresentable {
    let onTextScanned: (String) -> Void
    
    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let scanner = VNDocumentCameraViewController()
        scanner.delegate = context.coordinator
        return scanner
    }
    
    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onTextScanned: onTextScanned)
    }
    
    class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let onTextScanned: (String) -> Void
        
        init(onTextScanned: @escaping (String) -> Void) {
            self.onTextScanned = onTextScanned
        }
        
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            // TODO: Process scanned document with Vision framework
            onTextScanned("Scanned document text would appear here")
            controller.dismiss(animated: true)
        }
        
        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            controller.dismiss(animated: true)
        }
    }
}

#Preview {
    PlanView()
}