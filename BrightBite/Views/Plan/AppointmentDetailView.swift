//
//  AppointmentDetailView.swift
//  BrightBite
//
//  Created by Tuan Nguyen on 9/1/25.
//

import SwiftUI

struct AppointmentDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var firebaseService: FirebaseService
    let appointment: Appointment
    @State private var showDeleteConfirmation = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text(appointment.title)
                            .font(.title2)
                            .fontWeight(.bold)

                        HStack {
                            Image(systemName: "calendar")
                                .foregroundStyle(.blue)
                            Text(appointment.date, style: .date)
                                .font(.subheadline)

                            Image(systemName: "clock")
                                .foregroundStyle(.blue)
                                .padding(.leading, 8)
                            Text(appointment.date, style: .time)
                                .font(.subheadline)
                        }
                        .foregroundStyle(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))

                    
                    if let dentistName = appointment.dentistName {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Dentist", systemImage: "person.fill")
                                .font(.headline)
                                .foregroundStyle(.blue)

                            Text(dentistName)
                                .font(.body)
                                .padding(.leading, 28)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }

                    
                    if let location = appointment.location {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Location", systemImage: "mappin.circle.fill")
                                .font(.headline)
                                .foregroundStyle(.blue)

                            Text(location)
                                .font(.body)
                                .padding(.leading, 28)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }

                    
                    if let notes = appointment.notes, !notes.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Notes", systemImage: "note.text")
                                .font(.headline)
                                .foregroundStyle(.blue)

                            Text(notes)
                                .font(.body)
                                .padding(.leading, 28)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }


                    
                    Button(action: {
                        showDeleteConfirmation = true
                    }) {
                        HStack {
                            Image(systemName: "trash")
                            Text("Delete Appointment")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .foregroundStyle(.red)
                        .cornerRadius(12)
                    }
                    .padding(.top, 20)
                }
                .padding()
            }
            .background(
                LinearGradient(
                    colors: [Color.blue.opacity(0.05), Color.clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .navigationTitle("Appointment Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Delete Appointment?", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    dismiss()
                    Task {
                        try? await Task.sleep(nanoseconds: 100_000_000)
                        await deleteAppointment()
                    }
                }
            } message: {
                Text("Are you sure you want to delete this appointment? This action cannot be undone.")
            }
        }
    }

    private func deleteAppointment() async {
        guard let userId = firebaseService.currentUser?.id else { return }

        do {
            try await firebaseService.deleteAppointment(appointment, for: userId)

            await MainActor.run {
                NotificationCenter.default.post(name: NSNotification.Name("RefreshUserData"), object: nil)
            }

            print("✅ Deleted appointment: \(appointment.title)")
        } catch {
            print("❌ Failed to delete appointment: \(error.localizedDescription)")
        }
    }
}

#Preview {
    AppointmentDetailView(
        appointment: Appointment(
            date: Date(),
            title: "Regular Checkup",
            dentistName: "Dr. Smith",
            notes: "Bring insurance card",
            location: "123 Main St"
        )
    )
}
