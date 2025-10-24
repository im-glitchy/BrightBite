//
//  PlanView.swift
//  BrightBite
//
//  Created by Tuan Nguyen on 9/1/25.
//

import SwiftUI
import VisionKit
import Vision

struct PlanView: View {
    @EnvironmentObject private var firebaseService: FirebaseService
    @State private var userProfile: UserProfile?

    @State private var treatmentPlan = TreatmentPlan(
        restrictions: [],
        currentTasks: [],
        doctorNotes: [],
        medications: [],
        alignerProgress: nil
    )

    @State private var appointments: [Appointment] = []
    
    @State private var showNotesScanner = false
    @State private var showEditProfile = false
    @State private var isProcessingNotes = false
    @State private var showProcessingAlert = false
    @State private var processingError: String?
    @State private var showAddAppointment = false
    @State private var showMedicalHistory = false
    @State private var selectedAppointment: Appointment?
    @State private var showDeleteAccountAlert = false
    @State private var showScanConfirmationChat = false
    @State private var scannedOCRText = ""
    @State private var scannedImages: [UIImage] = []
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 20) {
                    
                    if let userProfile = userProfile {
                        ProfileSection(
                            profile: userProfile,
                            onEdit: { showEditProfile = true },
                            onDeleteAccount: { showDeleteAccountAlert = true }
                        )
                    } else {
                        
                        GlassCard {
                            VStack {
                                ProgressView()
                                Text("Loading profile...")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(height: 80)
                        }
                    }
                    
                    
                    TreatmentPlanSection(plan: treatmentPlan)
                    
                    
                    AppointmentsSection(
                        appointments: appointments,
                        onAddAppointment: { showAddAppointment = true },
                        onViewAppointment: { appointment in
                            selectedAppointment = appointment
                        }
                    )
                    
                    
                    MedicalHistorySection(
                        plan: treatmentPlan,
                        onViewAllHistory: { showMedicalHistory = true }
                    )
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
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showNotesScanner = true }) {
                        Image(systemName: "doc.text.viewfinder")
                            .foregroundStyle(.blue)
                    }
                }

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
            EditProfileSheet(profile: Binding(
                get: { userProfile ?? UserProfile(id: "", name: nil, hasBraces: false, dentistInfo: nil) },
                set: { userProfile = $0 }
            ))
        }
        .onAppear {
            loadUserProfile()
            loadTreatmentPlan()
            loadAppointments()
            setupNotificationListeners()
        }
        .onReceive(firebaseService.$currentUser) { newUser in
            userProfile = newUser
        }
        .sheet(isPresented: $showNotesScanner) {
            NotesDocumentScanner { scannedText, scannedImages in
                processScannedNotes(scannedText, images: scannedImages)
            }
        }
        .sheet(isPresented: $showAddAppointment) {
            AddAppointmentView()
        }
        .sheet(isPresented: $showMedicalHistory) {
            MedicalHistoryView(plan: treatmentPlan)
        }
        .sheet(item: $selectedAppointment) { appointment in
            AppointmentDetailView(appointment: appointment)
        }
        .sheet(isPresented: $showScanConfirmationChat) {
            ScanConfirmationChatView(ocrText: scannedOCRText, scannedImages: scannedImages)
        }
        .alert(isProcessingNotes ? "Processing Notes" : "Processing Complete", isPresented: $showProcessingAlert) {
            if !isProcessingNotes {
                Button("OK") { }
            }
        } message: {
            if isProcessingNotes {
                Text("Analyzing dental notes with AI...")
            } else if let error = processingError {
                Text("Error: \(error)")
            } else {
                Text("Successfully extracted treatment plan, appointments, and medications from your dental notes.")
            }
        }
        .alert("Delete Account", isPresented: $showDeleteAccountAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteAccount()
            }
        } message: {
            Text("Are you sure you want to delete your account? This action cannot be undone.")
        }
    }
    
    private func processScannedNotes(_ text: String, images: [UIImage]) {
        print("=== PROCESSING SCANNED NOTES ===")
        print("OCR Text extracted: \(text.count) characters")
        print("Number of images: \(images.count)")
        print("\n=== OCR EXTRACTED TEXT START ===")
        print(text)
        print("=== OCR EXTRACTED TEXT END ===\n")

        
        
        
        scannedOCRText = text
        scannedImages = images
        showScanConfirmationChat = true
    }

    private func convertAndSaveParsedNotes(_ parsed: ParsedDentalNotes) {
        
        if let generalNotes = parsed.generalNotes, !generalNotes.isEmpty {
            let note = DoctorNote(content: generalNotes, source: .scanned)
            treatmentPlan.doctorNotes.append(note)
        }

        
        if let plan = parsed.treatmentPlan {
            var planText = "Treatment Plan: \(plan.description)"
            if let duration = plan.duration {
                planText += "\nDuration: \(duration)"
            }
            if !plan.goals.isEmpty {
                planText += "\nGoals: \(plan.goals.joined(separator: ", "))"
            }
            let note = DoctorNote(content: planText, source: .scanned)
            treatmentPlan.doctorNotes.append(note)
        }

        
        if let postOp = parsed.postOpInstructions {
            var postOpText = "Post-Op Instructions:\n"
            postOpText += postOp.instructions.map { "• \($0)" }.joined(separator: "\n")
            if !postOp.warnings.isEmpty {
                postOpText += "\n\nWarnings:\n"
                postOpText += postOp.warnings.map { "⚠️ \($0)" }.joined(separator: "\n")
            }
            let note = DoctorNote(content: postOpText, source: .scanned)
            treatmentPlan.doctorNotes.append(note)
        }

        
        for parsedMed in parsed.medications {
            let endDate = parseDateString(parsedMed.duration)
            let med = Medication(
                name: parsedMed.name,
                dosage: parsedMed.dosage,
                frequency: parsedMed.frequency,
                endDate: endDate,
                instructions: parsedMed.instructions
            )
            treatmentPlan.medications.append(med)
        }

        
        for parsedRestriction in parsed.dietRestrictions {
            if let type = RestrictionType.from(string: parsedRestriction.type) {
                let endDate = parseDateString(parsedRestriction.duration)
                let restriction = DietRestriction(
                    type: type,
                    endDate: endDate,
                    reason: parsedRestriction.reason
                )
                treatmentPlan.restrictions.append(restriction)
            }
        }

        
        for parsedProc in parsed.procedures {
            if let type = ProcedureType.from(string: parsedProc.type) {
                var procText = "Procedure: \(type.rawValue.capitalized)"
                if let toothNumbers = parsedProc.toothNumbers, !toothNumbers.isEmpty {
                    procText += " (Teeth: \(toothNumbers.map(String.init).joined(separator: ", ")))"
                }
                if let date = parsedProc.date {
                    procText += " - \(date)"
                }
                if let notes = parsedProc.notes {
                    procText += "\n\(notes)"
                }
                let note = DoctorNote(content: procText, source: .scanned)
                treatmentPlan.doctorNotes.append(note)
            }
        }

        
        for parsedAppt in parsed.appointments {
            if let date = parseDateStringToDate(parsedAppt.date) {
                let appt = Appointment(
                    date: date,
                    title: parsedAppt.title,
                    dentistName: parsedAppt.dentistName,
                    notes: parsedAppt.notes,
                    location: parsedAppt.location
                )
                appointments.append(appt)

                
                Task {
                    do {
                        try await CalendarService.shared.addAppointmentToCalendar(appointment: appt)
                        print("Added appointment to calendar: \(appt.title)")
                    } catch {
                        print("Error adding appointment to calendar: \(error)")
                    }
                }
            }
        }
    }

    private func parseDateString(_ dateString: String?) -> Date? {
        guard let dateString = dateString else { return nil }

        
        let components = dateString.lowercased().components(separatedBy: " ")
        if let numberIndex = components.firstIndex(where: { Int($0) != nil }),
           let number = Int(components[numberIndex]),
           numberIndex + 1 < components.count {
            let unit = components[numberIndex + 1]

            if unit.contains("day") {
                return Calendar.current.date(byAdding: .day, value: number, to: Date())
            } else if unit.contains("week") {
                return Calendar.current.date(byAdding: .weekOfYear, value: number, to: Date())
            } else if unit.contains("month") {
                return Calendar.current.date(byAdding: .month, value: number, to: Date())
            }
        }

        return nil
    }

    private func parseDateStringToDate(_ dateString: String) -> Date? {
        let formatter = DateFormatter()

        
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        if let date = formatter.date(from: dateString) {
            return date
        }

        
        formatter.dateFormat = "yyyy-MM-dd"
        if let date = formatter.date(from: dateString) {
            return date
        }

        
        formatter.dateFormat = "MM/dd/yyyy"
        if let date = formatter.date(from: dateString) {
            return date
        }

        return nil
    }

    private func loadUserProfile() {
        
        userProfile = firebaseService.currentUser
    }

    private func loadTreatmentPlan() {
        guard let userId = firebaseService.currentUser?.id else { return }

        Task {
            do {
                treatmentPlan = try await firebaseService.loadTreatmentPlan(for: userId)
                print("✅ Loaded treatment plan: \(treatmentPlan.doctorNotes.count) notes, \(treatmentPlan.medications.count) medications")
            } catch {
                print("⚠️ Failed to load treatment plan: \(error.localizedDescription)")
            }
        }
    }

    private func loadAppointments() {
        guard let userId = firebaseService.currentUser?.id else { return }

        Task {
            do {
                appointments = try await firebaseService.loadAppointments(for: userId)
                print("✅ Loaded \(appointments.count) appointments")
            } catch {
                print("⚠️ Failed to load appointments: \(error.localizedDescription)")
            }
        }
    }

    private func setupNotificationListeners() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("SaveScannedNotes"),
            object: nil,
            queue: .main
        ) { notification in
            guard let userInfo = notification.userInfo,
                  let parsed = userInfo["parsedData"] as? ParsedDentalNotes else {
                return
            }

            print("📥 Received scanned notes data - saving to profile...")
            Task {
                try? await Task.sleep(nanoseconds: 100_000_000)
                convertAndSaveParsedNotes(parsed)
            }
        }


        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("RefreshUserData"),
            object: nil,
            queue: .main
        ) { _ in
            print("📥 Received refresh notification - reloading data...")
            Task {
                try? await Task.sleep(nanoseconds: 100_000_000)
                loadUserProfile()
                loadTreatmentPlan()
                loadAppointments()
            }
        }
    }

    private func deleteAccount() {
        Task {
            do {
                try await firebaseService.deleteAccount()
            } catch {
                print("Error deleting account: \(error)")
            }
        }
    }
}

struct ProfileSection: View {
    @EnvironmentObject private var firebaseService: FirebaseService
    let profile: UserProfile
    let onEdit: () -> Void
    let onDeleteAccount: () -> Void
    @State private var showInsuranceCard = false

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
                    
                    if let image = firebaseService.cachedProfileImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 60, height: 60)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.blue.opacity(0.3), lineWidth: 1))
                    } else {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 60, height: 60)
                            .overlay(
                                Text(String(profile.name?.prefix(1) ?? "U"))
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.blue)
                            )
                    }

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

                
                Button(action: {
                    showInsuranceCard = true
                }) {
                    HStack {
                        Image(systemName: "creditcard.fill")
                            .foregroundStyle(.blue)
                        Text("Insurance Card")
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(Color.blue.opacity(0.05))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)

                
                HStack(spacing: 12) {
                    Button("Sign Out") {
                        Task {
                            do {
                                try await firebaseService.signOut()
                            } catch {
                                print("Error signing out: \(error)")
                            }
                        }
                    }
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.blue.opacity(0.2), in: Capsule())
                    .foregroundStyle(.blue)

                    Button("Export Data") {
                        
                    }
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.thinMaterial, in: Capsule())

                    Button("Delete Account", action: onDeleteAccount)
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.red.opacity(0.2), in: Capsule())
                    .foregroundStyle(.red)

                    Spacer()
                }
            }
        }
        .sheet(isPresented: $showInsuranceCard) {
            InsuranceCardView()
        }
    }
}

struct TreatmentPlanSection: View {
    let plan: TreatmentPlan

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("Treatment Plan")
                    .font(.headline)
                    .fontWeight(.semibold)

                if plan.restrictions.isEmpty && plan.currentTasks.isEmpty && plan.medications.isEmpty && plan.alignerProgress == nil {
                    Text("No treatment plans occurring")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .italic()
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 16)
                } else {
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

                    if !plan.restrictions.isEmpty && (!plan.currentTasks.isEmpty || plan.alignerProgress != nil) {
                        Divider()
                    }

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

                    if let progress = plan.alignerProgress {
                        if !plan.currentTasks.isEmpty {
                            Divider()
                        }

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
    let onAddAppointment: () -> Void
    let onViewAppointment: (Appointment) -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("Appointments")
                    .font(.headline)
                    .fontWeight(.semibold)

                if appointments.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "calendar")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        Text("No appointments scheduled")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                } else {
                    ForEach(appointments) { appointment in
                        Button(action: {
                            onViewAppointment(appointment)
                        }) {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(appointment.title)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.primary)

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

                                Button(action: {
                                    onViewAppointment(appointment)
                                }) {
                                    HStack(spacing: 4) {
                                        Text("View")
                                            .font(.caption)
                                            .fontWeight(.medium)
                                        Image(systemName: "chevron.right")
                                            .font(.caption2)
                                    }
                                    .foregroundStyle(.blue)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(.bottom, 8)
                    }
                }

                Button(action: onAddAppointment) {
                    HStack {
                        Spacer()
                        Image(systemName: "plus.circle.fill")
                            .font(.subheadline)
                        Text("Add Appointment")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                    }
                    .foregroundStyle(.blue)
                    .padding(.vertical, 8)
                    .background(Color.blue.opacity(0.05))
                    .cornerRadius(8)
                }
                .padding(.top, 4)
            }
        }
    }
}

struct MedicalHistorySection: View {
    let plan: TreatmentPlan
    let onViewAllHistory: () -> Void
    @State private var selectedNote: DoctorNote?

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("Medical History")
                    .font(.headline)
                    .fontWeight(.semibold)

                if plan.doctorNotes.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "doc.text")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        Text("No medical history yet")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                } else {
                    
                    ForEach(plan.doctorNotes.prefix(3)) { note in
                        Button(action: {
                            selectedNote = note
                        }) {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(note.createdAt, style: .date)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)

                                    
                                    if let title = note.title, !title.isEmpty {
                                        Text(title)
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .lineLimit(1)
                                            .foregroundStyle(.primary)
                                    } else {
                                        Text(note.content)
                                            .font(.body)
                                            .lineLimit(2)
                                            .foregroundStyle(.primary)
                                    }

                                    StatusPill(text: note.source.rawValue.capitalized, color: .gray)
                                }

                                Spacer()

                                Button(action: {
                                    selectedNote = note
                                }) {
                                    HStack(spacing: 4) {
                                        Text("View")
                                            .font(.caption)
                                            .fontWeight(.medium)
                                        Image(systemName: "chevron.right")
                                            .font(.caption2)
                                    }
                                    .foregroundStyle(.blue)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(.bottom, 8)
                    }

                    
                    Button(action: onViewAllHistory) {
                        HStack {
                            Spacer()
                            Text("View All History")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Image(systemName: "arrow.right")
                                .font(.caption)
                            Spacer()
                        }
                        .foregroundStyle(.blue)
                        .padding(.vertical, 8)
                        .background(Color.blue.opacity(0.05))
                        .cornerRadius(8)
                    }
                    .padding(.top, 4)
                }
            }
        }
        .padding(.bottom, 20)
        .sheet(item: $selectedNote) { note in
            NavigationView {
                DoctorNoteDetailView(note: note, onDelete: {
                    
                })
                .environmentObject(FirebaseService.shared)
            }
        }
    }
}

struct EditProfileSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var firebaseService: FirebaseService
    @Binding var profile: UserProfile?
    @State private var isSaving = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var selectedImage: UIImage?
    @State private var showImagePicker = false

    var body: some View {
        NavigationView {
            if let profile = Binding($profile) {
                Form {
                    Section("Profile Picture") {
                        HStack {
                            Spacer()
                            VStack(spacing: 12) {
                                
                                if let image = selectedImage ?? firebaseService.cachedProfileImage {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 100, height: 100)
                                        .clipShape(Circle())
                                        .overlay(Circle().stroke(Color.blue, lineWidth: 2))
                                } else {
                                    Circle()
                                        .fill(Color.blue.opacity(0.1))
                                        .frame(width: 100, height: 100)
                                        .overlay(
                                            Text(String(profile.wrappedValue.name?.prefix(1) ?? "U"))
                                                .font(.largeTitle)
                                                .fontWeight(.semibold)
                                                .foregroundStyle(.blue)
                                        )
                                }

                                Button(action: {
                                    showImagePicker = true
                                }) {
                                    Text(selectedImage != nil || firebaseService.cachedProfileImage != nil ? "Change Photo" : "Add Photo")
                                        .font(.subheadline)
                                        .foregroundStyle(.blue)
                                }
                            }
                            Spacer()
                        }
                        .padding(.vertical, 8)
                    }

                    Section("Personal Information") {
                        TextField("Name", text: Binding(
                            get: { profile.wrappedValue.name ?? "" },
                            set: { profile.wrappedValue.name = $0.isEmpty ? nil : $0 }
                        ))

                        Toggle("Has Braces", isOn: Binding(
                            get: { profile.wrappedValue.hasBraces },
                            set: { profile.wrappedValue.hasBraces = $0 }
                        ))
                    }

                    Section("Dentist Information") {
                        TextField("Dentist Name", text: Binding(
                            get: { profile.wrappedValue.dentistInfo?.name ?? "" },
                            set: {
                                if profile.wrappedValue.dentistInfo == nil {
                                    profile.wrappedValue.dentistInfo = DentistInfo(name: $0)
                                } else {
                                    profile.wrappedValue.dentistInfo?.name = $0
                                }
                            }
                        ))

                        TextField("Phone", text: Binding(
                            get: { profile.wrappedValue.dentistInfo?.phone ?? "" },
                            set: { profile.wrappedValue.dentistInfo?.phone = $0.isEmpty ? nil : $0 }
                        ))

                        TextField("Email", text: Binding(
                            get: { profile.wrappedValue.dentistInfo?.email ?? "" },
                            set: { profile.wrappedValue.dentistInfo?.email = $0.isEmpty ? nil : $0 }
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
                        Button(isSaving ? "Saving..." : "Save") {
                            saveProfile()
                        }
                        .disabled(isSaving)
                    }
                }
            } else {
                ProgressView()
            }
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(image: $selectedImage, sourceType: .photoLibrary)
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }

    private func saveProfile() {
        guard var currentProfile = profile else { return }
        isSaving = true

        Task {
            do {
                
                if let imageData = selectedImage?.jpegData(compressionQuality: 0.8) {
                    print("📸 Uploading profile image for user: \(currentProfile.id)")

                    
                    try? await firebaseService.ensureUserStorageFolder(for: currentProfile.id)

                    
                    let imageURL = try await firebaseService.uploadProfileImage(imageData, for: currentProfile.id)
                    print("✅ Profile image uploaded successfully: \(imageURL)")

                    currentProfile.profileImageURL = imageURL

                    
                    await MainActor.run {
                        firebaseService.cachedProfileImage = selectedImage
                    }
                }

                
                print("💾 Saving profile to Firestore...")
                try await firebaseService.updateUserProfile(currentProfile)
                print("✅ Profile saved successfully")

                await MainActor.run {
                    profile = currentProfile
                    isSaving = false
                    dismiss()
                }
            } catch {
                print("❌ Error saving profile: \(error)")
                await MainActor.run {
                    isSaving = false
                    errorMessage = "Failed to save profile: \(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }
}

struct NotesDocumentScanner: UIViewControllerRepresentable {
    let onTextScanned: (String, [UIImage]) -> Void
    
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
        let onTextScanned: (String, [UIImage]) -> Void
        
        init(onTextScanned: @escaping (String, [UIImage]) -> Void) {
            self.onTextScanned = onTextScanned
        }
        
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            
            var scannedImages: [UIImage] = []
            for pageIndex in 0..<scan.pageCount {
                let image = scan.imageOfPage(at: pageIndex)
                scannedImages.append(image)
            }

            controller.dismiss(animated: true)

            
            Task {
                var allExtractedText = ""

                for image in scannedImages {
                    if let text = await extractText(from: image) {
                        allExtractedText += text + "\n\n"
                    }
                }

                await MainActor.run {
                    onTextScanned(allExtractedText.trimmingCharacters(in: .whitespacesAndNewlines), scannedImages)
                }
            }
        }

        private func extractText(from image: UIImage) async -> String? {
            guard let cgImage = image.cgImage else { return nil }

            return await withCheckedContinuation { continuation in
                let request = VNRecognizeTextRequest { request, error in
                    if let error = error {
                        print("OCR Error: \(error.localizedDescription)")
                        continuation.resume(returning: nil)
                        return
                    }

                    guard let observations = request.results as? [VNRecognizedTextObservation] else {
                        continuation.resume(returning: nil)
                        return
                    }

                    let text = observations.compactMap { observation in
                        observation.topCandidates(1).first?.string
                    }.joined(separator: "\n")

                    continuation.resume(returning: text.isEmpty ? nil : text)
                }

                request.recognitionLevel = .accurate
                request.recognitionLanguages = ["en-US"]
                request.usesLanguageCorrection = true

                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                do {
                    try handler.perform([request])
                } catch {
                    print("Failed to perform OCR: \(error.localizedDescription)")
                    continuation.resume(returning: nil)
                }
            }
        }
        
        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            controller.dismiss(animated: true)
        }
    }
}

#Preview {
    PlanView()
}
