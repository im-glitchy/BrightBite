//
//  AddAppointmentView.swift
//  BrightBite
//
//  Created by Tuan Nguyen on 9/15/25.
//

import SwiftUI

struct AddAppointmentView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var firebaseService: FirebaseService

    @State private var appointmentTitle = ""
    @State private var appointmentDate = Date()
    @State private var appointmentTime = Date()
    @State private var doctorName = ""
    @State private var location = ""
    @State private var notes = ""
    @State private var appointmentType: AppointmentType = .checkup
    @State private var showSuccessAlert = false

    enum AppointmentType: String, CaseIterable {
        case checkup = "Regular Checkup"
        case adjustment = "Braces Adjustment"
        case cleaning = "Cleaning"
        case consultation = "Consultation"
        case procedure = "Procedure"
        case followUp = "Follow-up"
        case other = "Other"
    }

    var body: some View {
        NavigationView {
            Form {
                Section("Appointment Details") {
                    TextField("Title", text: $appointmentTitle)
                        .textInputAutocapitalization(.words)

                    Picker("Type", selection: $appointmentType) {
                        ForEach(AppointmentType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }

                    DatePicker("Date", selection: $appointmentDate, displayedComponents: .date)

                    DatePicker("Time", selection: $appointmentTime, displayedComponents: .hourAndMinute)
                }

                Section("Provider Information") {
                    TextField("Doctor/Orthodontist Name", text: $doctorName)
                        .textInputAutocapitalization(.words)

                    TextField("Office Location", text: $location)
                        .textInputAutocapitalization(.words)
                }

                Section("Additional Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                }
            }
            .navigationTitle("New Appointment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveAppointment()
                    }
                    .disabled(appointmentTitle.isEmpty)
                }
            }
            .alert("Appointment Saved", isPresented: $showSuccessAlert) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Your appointment has been saved successfully.")
            }
        }
    }

    private func saveAppointment() {
        guard let userId = firebaseService.currentUser?.id else { return }

        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: appointmentDate)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: appointmentTime)

        var combined = DateComponents()
        combined.year = dateComponents.year
        combined.month = dateComponents.month
        combined.day = dateComponents.day
        combined.hour = timeComponents.hour
        combined.minute = timeComponents.minute

        guard let finalDateTime = calendar.date(from: combined) else {
            return
        }

        Task {
            do {
                let appointment = Appointment(
                    date: finalDateTime,
                    title: appointmentTitle.isEmpty ? appointmentType.rawValue : appointmentTitle,
                    dentistName: doctorName.isEmpty ? nil : doctorName,
                    notes: notes.isEmpty ? nil : notes,
                    location: location.isEmpty ? nil : location
                )

                try await firebaseService.saveAppointment(appointment, for: userId)
                print("✅ Appointment saved")

                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "MMM d, h:mm a"

                let appointmentDateFormatter = DateFormatter()
                appointmentDateFormatter.dateFormat = "MMM d"

                let activity = RecentActivity(
                    date: dateFormatter.string(from: Date()),
                    description: "Added appointment: \(appointment.title) on \(appointmentDateFormatter.string(from: finalDateTime))",
                    type: .appointment,
                    timestamp: Date()
                )

                try await firebaseService.saveActivity(activity, for: userId)
                print("✅ Appointment activity saved")

                try? await firebaseService.generateDentalSummary(for: userId)
                print("✅ Dental summary regenerated")

                NotificationCenter.default.post(name: NSNotification.Name("RefreshHomeData"), object: nil)

                await MainActor.run {
                    showSuccessAlert = true
                }
            } catch {
                print("❌ Error saving appointment: \(error)")
                await MainActor.run {
                    showSuccessAlert = true
                }
            }
        }
    }
}

#Preview {
    AddAppointmentView()
}
