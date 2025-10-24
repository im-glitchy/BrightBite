//
//  MedicalHistoryView.swift
//  BrightBite
//
//  Created by Tuan Nguyen on 9/1/25.
//

import SwiftUI

struct MedicalHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var firebaseService: FirebaseService
    @State private var plan: TreatmentPlan
    @State private var selectedNote: DoctorNote?

    init(plan: TreatmentPlan) {
        _plan = State(initialValue: plan)
    }

    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 16) {
                    
                    if !plan.doctorNotes.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Doctor Notes")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .padding(.horizontal)

                            ForEach(plan.doctorNotes) { note in
                                Button(action: {
                                    selectedNote = note
                                }) {
                                    GlassCard {
                                        VStack(alignment: .leading, spacing: 8) {
                                            HStack {
                                                Text(note.createdAt, style: .date)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)

                                                Spacer()

                                                StatusPill(text: note.source.rawValue.capitalized, color: .blue)
                                            }

                                            
                                            if let title = note.title, !title.isEmpty {
                                                Text(title)
                                                    .font(.headline)
                                                    .foregroundStyle(.primary)
                                                    .lineLimit(2)
                                            } else {
                                                Text(note.content)
                                                    .font(.body)
                                                    .foregroundStyle(.primary)
                                                    .lineLimit(2)
                                            }

                                            
                                            HStack {
                                                Text("Tap to view details")
                                                    .font(.caption2)
                                                    .foregroundStyle(.secondary)
                                                Spacer()
                                                Image(systemName: "chevron.right")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal)
                            }
                        }
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "doc.text")
                                .font(.system(size: 48))
                                .foregroundStyle(.secondary)

                            Text("No Medical History")
                                .font(.headline)
                                .foregroundStyle(.secondary)

                            Text("Scan dentist notes to build your medical history")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 80)
                    }

                    
                    if !plan.medications.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Medications")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .padding(.horizontal)
                                .padding(.top, 8)

                            ForEach(plan.medications) { medication in
                                GlassCard {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(medication.name)
                                            .font(.body)
                                            .fontWeight(.semibold)

                                        HStack {
                                            Text("Dosage:")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                            Text(medication.dosage)
                                                .font(.caption)
                                        }

                                        HStack {
                                            Text("Frequency:")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                            Text(medication.frequency)
                                                .font(.caption)
                                        }

                                        if let endDate = medication.endDate {
                                            HStack {
                                                Text("Until:")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                                Text(endDate, style: .date)
                                                    .font(.caption)
                                            }
                                        }

                                        if let instructions = medication.instructions {
                                            Text(instructions)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .italic()
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }

                    
                    if !plan.restrictions.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Diet Restrictions")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .padding(.horizontal)
                                .padding(.top, 8)

                            ForEach(plan.restrictions) { restriction in
                                GlassCard {
                                    HStack {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundStyle(.orange)

                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(restriction.type.rawValue.capitalized)
                                                .font(.body)
                                                .fontWeight(.medium)

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
                                .padding(.horizontal)
                            }
                        }
                    }
                }
                .padding(.vertical)
            }
            .background(
                LinearGradient(
                    colors: [Color.blue.opacity(0.05), Color.clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .navigationTitle("Medical History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadLatestData()
            }
        }
        .sheet(item: $selectedNote) { note in
            NavigationView {
                DoctorNoteDetailView(note: note, onDelete: {
                    deleteNote(note)
                })
            }
        }
    }

    private func loadLatestData() {
        guard let userId = firebaseService.currentUser?.id else { return }

        Task {
            do {
                let latestPlan = try await firebaseService.loadTreatmentPlan(for: userId)
                await MainActor.run {
                    plan = latestPlan
                }
                print("🔄 Refreshed medical history: \(latestPlan.doctorNotes.count) notes")
            } catch {
                print("⚠️ Failed to refresh medical history: \(error.localizedDescription)")
            }
        }
    }

    private func deleteNote(_ note: DoctorNote) {
        guard let userId = firebaseService.currentUser?.id else { return }

        Task {
            do {
                try await firebaseService.deleteDoctorNote(note, for: userId)

                await MainActor.run {
                    plan.doctorNotes.removeAll { $0.id == note.id }

                    NotificationCenter.default.post(name: NSNotification.Name("RefreshUserData"), object: nil)
                }

                print("✅ Deleted medical record: \(note.title ?? "Untitled")")
                print("   Remaining notes: \(plan.doctorNotes.count)")
            } catch {
                print("❌ Failed to delete medical record: \(error.localizedDescription)")
            }
        }
    }
}


struct DoctorNoteDetailView: View {
    let note: DoctorNote
    let onDelete: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirmation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(note.createdAt, style: .date)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(note.createdAt, style: .time)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    StatusPill(text: note.source.rawValue.capitalized, color: .blue)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)

                
                if let title = note.title, !title.isEmpty {
                    Text(title)
                        .font(.title2)
                        .fontWeight(.bold)
                }

                
                Text(note.content)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer()

                
                Button(action: {
                    showDeleteConfirmation = true
                }) {
                    HStack {
                        Image(systemName: "trash")
                        Text("Delete Medical Record")
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
        .navigationTitle("Note Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
        .alert("Delete Medical Record?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                dismiss()
                Task {
                    try? await Task.sleep(nanoseconds: 100_000_000)
                    onDelete()
                }
            }
        } message: {
            if let title = note.title, !title.isEmpty {
                Text("Are you sure you want to delete '\(title)'? This action cannot be undone.")
            } else {
                Text("Are you sure you want to delete this medical record? This action cannot be undone.")
            }
        }
    }
}

#Preview {
    MedicalHistoryView(
        plan: TreatmentPlan(
            restrictions: [
                DietRestriction(type: .softOnly, endDate: Calendar.current.date(byAdding: .day, value: 5, to: Date()), reason: "Recent extraction")
            ],
            currentTasks: [],
            doctorNotes: [
                DoctorNote(content: "Patient responding well to treatment.", source: .appointment)
            ],
            medications: [
                Medication(name: "Ibuprofen", dosage: "400mg", frequency: "Every 6 hours", endDate: nil, instructions: "Take with food")
            ],
            alignerProgress: nil
        )
    )
}
