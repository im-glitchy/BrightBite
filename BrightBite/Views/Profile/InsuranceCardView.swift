//
//  InsuranceCardView.swift
//  BrightBite
//
//  Created by Tuan Nguyen on 9/1/25.
//

import SwiftUI

struct InsuranceCardView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var firebaseService: FirebaseService
    @State private var insuranceCard: InsuranceCard?
    @State private var isLoading = true
    @State private var showAddCard = false
    @State private var showDeleteConfirmation = false
    @State private var cardImage: UIImage?

    var body: some View {
        NavigationView {
            ZStack {
                if isLoading {
                    ProgressView("Loading insurance card...")
                } else if let card = insuranceCard {
                    ScrollView {
                        VStack(spacing: 24) {
                            
                            WalletCardView(card: card, cardImage: cardImage)
                                .padding(.horizontal)
                                .padding(.top)

                            
                            VStack(spacing: 16) {
                                
                                if card.coveragePreventive != nil || card.coverageBasic != nil || card.coverageMajor != nil {
                                    GlassCard {
                                        VStack(alignment: .leading, spacing: 12) {
                                            Text("Coverage")
                                                .font(.headline)
                                                .fontWeight(.semibold)

                                            if let preventive = card.coveragePreventive {
                                                HStack {
                                                    Text("Preventive:")
                                                        .foregroundStyle(.secondary)
                                                    Spacer()
                                                    Text("\(preventive)%")
                                                        .fontWeight(.semibold)
                                                }
                                            }

                                            if let basic = card.coverageBasic {
                                                HStack {
                                                    Text("Basic:")
                                                        .foregroundStyle(.secondary)
                                                    Spacer()
                                                    Text("\(basic)%")
                                                        .fontWeight(.semibold)
                                                }
                                            }

                                            if let major = card.coverageMajor {
                                                HStack {
                                                    Text("Major:")
                                                        .foregroundStyle(.secondary)
                                                    Spacer()
                                                    Text("\(major)%")
                                                        .fontWeight(.semibold)
                                                }
                                            }
                                        }
                                    }
                                    .padding(.horizontal)
                                }

                                
                                if card.annualMaximum != nil || card.deductible != nil {
                                    GlassCard {
                                        VStack(alignment: .leading, spacing: 12) {
                                            Text("Financial Details")
                                                .font(.headline)
                                                .fontWeight(.semibold)

                                            if let maximum = card.annualMaximum {
                                                HStack {
                                                    Text("Annual Maximum:")
                                                        .foregroundStyle(.secondary)
                                                    Spacer()
                                                    Text("$\(Int(maximum))")
                                                        .fontWeight(.semibold)
                                                }
                                            }

                                            if let deductible = card.deductible {
                                                HStack {
                                                    Text("Deductible:")
                                                        .foregroundStyle(.secondary)
                                                    Spacer()
                                                    Text("$\(Int(deductible))")
                                                        .fontWeight(.semibold)
                                                }
                                            }
                                        }
                                    }
                                    .padding(.horizontal)
                                }

                                
                                if let phone = card.customerServicePhone {
                                    GlassCard {
                                        VStack(alignment: .leading, spacing: 12) {
                                            Text("Customer Service")
                                                .font(.headline)
                                                .fontWeight(.semibold)

                                            Button(action: {
                                                if let url = URL(string: "tel://\(phone.filter { $0.isNumber })") {
                                                    UIApplication.shared.open(url)
                                                }
                                            }) {
                                                HStack {
                                                    Image(systemName: "phone.fill")
                                                        .foregroundStyle(.blue)
                                                    Text(phone)
                                                        .foregroundStyle(.primary)
                                                    Spacer()
                                                    Image(systemName: "chevron.right")
                                                        .font(.caption)
                                                        .foregroundStyle(.secondary)
                                                }
                                            }
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            }

                            
                            Button(action: {
                                showDeleteConfirmation = true
                            }) {
                                HStack {
                                    Image(systemName: "trash")
                                    Text("Delete Insurance Card")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.red.opacity(0.1))
                                .foregroundStyle(.red)
                                .cornerRadius(12)
                            }
                            .padding(.horizontal)
                            .padding(.top, 20)
                        }
                        .padding(.bottom, 30)
                    }
                } else {
                    
                    VStack(spacing: 20) {
                        Image(systemName: "creditcard")
                            .font(.system(size: 60))
                            .foregroundStyle(.secondary)

                        Text("No Insurance Card")
                            .font(.title2)
                            .fontWeight(.semibold)

                        Text("Add your dental insurance card to keep all your information in one place")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)

                        Button(action: {
                            showAddCard = true
                        }) {
                            Text("Add Insurance Card")
                        }
                        .liquidGlassButton(style: .accent)
                        .padding(.horizontal, 40)
                        .padding(.top, 10)
                    }
                }
            }
            .background(
                LinearGradient(
                    colors: [Color.blue.opacity(0.05), Color.clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .navigationTitle("Insurance Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }

                if insuranceCard != nil {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            showAddCard = true
                        }) {
                            Text("Edit")
                        }
                    }
                }
            }
            .sheet(isPresented: $showAddCard) {
                AddInsuranceCardView(existingCard: insuranceCard, onSave: {
                    loadInsuranceCard()
                })
            }
            .alert("Delete Insurance Card?", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteInsuranceCard()
                }
            } message: {
                Text("Are you sure you want to delete this insurance card? This action cannot be undone.")
            }
            .onAppear {
                loadInsuranceCard()
            }
        }
    }

    private func loadInsuranceCard() {
        guard let userId = firebaseService.currentUser?.id else { return }

        isLoading = true

        Task {
            do {
                let card = try await firebaseService.loadInsuranceCard(for: userId)

                
                if let imageURLString = card?.cardImageURL,
                   let imageURL = URL(string: imageURLString) {
                    let (data, _) = try await URLSession.shared.data(from: imageURL)
                    await MainActor.run {
                        self.cardImage = UIImage(data: data)
                    }
                }

                await MainActor.run {
                    self.insuranceCard = card
                    self.isLoading = false
                }
            } catch {
                print("❌ Failed to load insurance card: \(error)")
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }

    private func deleteInsuranceCard() {
        guard let userId = firebaseService.currentUser?.id,
              let card = insuranceCard else { return }

        Task {
            do {
                try await firebaseService.deleteInsuranceCard(card, for: userId)
                await MainActor.run {
                    self.insuranceCard = nil
                    self.cardImage = nil
                }
                print("✅ Deleted insurance card")
            } catch {
                print("❌ Failed to delete insurance card: \(error)")
            }
        }
    }
}


struct WalletCardView: View {
    let card: InsuranceCard
    let cardImage: UIImage?

    var body: some View {
        VStack(spacing: 0) {
            
            ZStack {
                
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [Color.blue, Color.cyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: .blue.opacity(0.3), radius: 20, x: 0, y: 10)

                VStack(alignment: .leading, spacing: 16) {
                    
                    HStack {
                        Text(card.providerName)
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)

                        Spacer()

                        Image(systemName: "cross.case.fill")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.8))
                    }

                    Spacer()

                    
                    VStack(alignment: .leading, spacing: 8) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Member ID")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.8))
                            Text(card.memberId)
                                .font(.body)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                        }

                        HStack(spacing: 20) {
                            if let groupNumber = card.groupNumber {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Group")
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.8))
                                    Text(groupNumber)
                                        .font(.body)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.white)
                                }
                            }

                            if let planType = card.planType {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Plan")
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.8))
                                    Text(planType)
                                        .font(.body)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.white)
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Policy Holder")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.8))
                            Text(card.policyHolderName)
                                .font(.body)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                        }
                        .padding(.top, 4)
                    }
                }
                .padding(20)
            }
            .frame(height: 200)
            .aspectRatio(1.586, contentMode: .fit) 

            
            if let image = cardImage {
                VStack(spacing: 12) {
                    Text("Original Card Image")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 20)

                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.1), radius: 10)
                }
                .padding(.top, 10)
            }
        }
    }
}

#Preview {
    InsuranceCardView()
}
