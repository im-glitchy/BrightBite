//
//  ChewCheckView.swift
//  BrightBite
//
//  Created by Tuan Nguyen on 9/15/25.
//

import SwiftUI
import PhotosUI

struct ChewCheckView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var firebaseService: FirebaseService
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var isAnalyzing = false
    @State private var result: ChewCheckResult?
    @State private var showAlternatives = false
    @State private var showExplanation = false
    @State private var detailedExplanation: String?
    @State private var isLoadingExplanation = false
    
    
    private var mockTreatmentPlan: TreatmentPlan {
        TreatmentPlan(
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
    }
    
    private var mockPainEntries: [PainEntry] {
        [
            PainEntry(toothNumber: 14, painLevel: 3.0, notes: "Mild sensitivity after extraction"),
            PainEntry(toothNumber: 18, painLevel: 2.0, notes: "Braces adjustment soreness")
        ]
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if let result = result {
                    ChewCheckResultView(
                        result: result,
                        onWrongFood: { showAlternatives = true },
                        onExplain: { generateDetailedExplanation() }
                    )
                } else if let selectedImage = selectedImage {
                    VStack(spacing: 20) {
                        Text("Analyzing your food...")
                            .font(.headline)
                        
                        Image(uiImage: selectedImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        
                        if isAnalyzing {
                            ProgressView()
                                .scaleEffect(1.2)
                        }
                    }
                    .onAppear {
                        analyzeFood(selectedImage)
                    }
                } else {
                    VStack(spacing: 30) {
                        
                        ZStack {
                            Circle()
                                .fill(.ultraThinMaterial)
                                .frame(width: 120, height: 120)
                            
                            Image(systemName: "camera.viewfinder")
                                .font(.system(size: 50))
                                .foregroundStyle(.blue)
                        }
                        
                        VStack(spacing: 12) {
                            Text("ChewCheck")
                                .font(.title)
                                .fontWeight(.bold)
                            
                            Text("Take a photo of your food and I'll tell you if it's safe to eat based on your treatment plan")
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        
                        PhotosPicker(
                            selection: $selectedItem,
                            matching: .images,
                            photoLibrary: .shared()
                        ) {
                            Text("Choose Photo")
                                .liquidGlassButton(style: .accent)
                        }
                        .padding(.horizontal, 40)
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("ChewCheck")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                if result != nil {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
            }
        }
        .onChange(of: selectedItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    selectedImage = image
                }
            }
        }
        .sheet(isPresented: $showAlternatives) {
            AlternativeFoodsSheet(alternatives: result?.alternatives ?? ["Apple", "Banana", "Carrot"]) { selectedFood in
                
                analyzeFood(selectedImage, correctedFood: selectedFood)
                showAlternatives = false
            }
        }
        .sheet(isPresented: $showExplanation) {
            DetailedExplanationView(
                result: result,
                explanation: detailedExplanation,
                isLoading: isLoadingExplanation
            )
        }
    }
    
    private func analyzeFood(_ image: UIImage?, correctedFood: String? = nil) {
        guard let image = image else { return }

        isAnalyzing = true

        Task {
            do {
                let userProfile = firebaseService.currentUser ?? UserProfile(
                    id: "mock_user",
                    name: "Test User",
                    hasBraces: true
                )

                let classification: FoodClassification

                if let correctedFoodName = correctedFood {
                    classification = try await ChewCheckMLService.shared.analyzeCorrectedFood(
                        foodName: correctedFoodName,
                        userProfile: userProfile,
                        treatmentPlan: mockTreatmentPlan,
                        painEntries: mockPainEntries
                    )
                } else {
                    classification = try await ChewCheckMLService.shared.classifyFood(
                        image: image,
                        userProfile: userProfile,
                        treatmentPlan: mockTreatmentPlan,
                        painEntries: mockPainEntries
                    )
                }

                await MainActor.run {
                    isAnalyzing = false

                    let foodName = classification.primaryResult.name
                    let tags = classification.primaryResult.tags

                    let cannotIdentifyKeywords = [
                        "can't identify",
                        "cannot identify",
                        "unable to identify",
                        "not a food",
                        "unknown food",
                        "unrecognized",
                        "not sure",
                        "unclear"
                    ]

                    let isUnidentified = cannotIdentifyKeywords.contains { keyword in
                        foodName.lowercased().contains(keyword) ||
                        classification.reasons.joined(separator: " ").lowercased().contains(keyword)
                    }

                    let verdict: FoodVerdict = {
                        if isUnidentified {
                            return .cannotIdentify
                        } else if let backendVerdict = classification.verdict {
                            switch backendVerdict.lowercased() {
                            case "safe": return .safe
                            case "caution": return .caution
                            case "avoid": return .avoid
                            case "later": return .later
                            case "cannotidentify": return .cannotIdentify
                            default: return .avoid
                            }
                        } else {
                            return determineFoodVerdict(for: tags)
                        }
                    }()

                    let reasons: [String] = {
                        if verdict == .cannotIdentify {
                            return ["Unable to identify this item as food", "For safety, avoid eating unidentified items", "Try taking a clearer photo or choosing a different item"]
                        } else {
                            return classification.reasons.isEmpty ?
                                generateReasons(for: verdict, tags: tags) : classification.reasons
                        }
                    }()

                    result = ChewCheckResult(
                        foodName: foodName,
                        confidence: classification.primaryResult.confidence,
                        verdict: verdict,
                        tags: tags,
                        reasons: reasons,
                        source: correctedFood != nil ? .chatgptVision : .tensorflowFood101,
                        alternatives: classification.alternatives.map { $0.name }
                    )

                    saveChewCheckActivity(foodName: foodName)
                }
            } catch {
                await MainActor.run {
                    isAnalyzing = false
                    print("Food analysis failed: \(error)")

                    result = ChewCheckResult(
                        foodName: correctedFood ?? "Unknown Item",
                        confidence: 0.0,
                        verdict: .cannotIdentify,
                        tags: [],
                        reasons: ["Analysis failed - please try again", "Unable to identify this item", "For safety, avoid eating unidentified items"],
                        source: .mock,
                        alternatives: []
                    )
                }
            }
        }
    }
    
    private func determineFoodVerdict(for tags: [FoodTag]) -> FoodVerdict {
        if tags.isEmpty {
            return .avoid
        }

        if tags.contains(.hard) || tags.contains(.sticky) || tags.contains(.chewy) {
            return .avoid
        } else if tags.contains(.sugary) || tags.contains(.acidic) {
            return .caution
        } else if tags.contains(.hot) {
            return .later
        } else if tags.contains(.soft) {
            return .safe
        } else {
            return .avoid
        }
    }
    
    private func generateReasons(for verdict: FoodVerdict, tags: [FoodTag]) -> [String] {
        switch verdict {
        case .safe:
            return ["Soft texture is gentle on your braces", "Cool temperature won't cause sensitivity"]
        case .caution:
            return ["Contains sugar - rinse after eating", "Acidic foods can affect enamel"]
        case .avoid:
            if tags.isEmpty {
                return ["Could not determine food properties", "Exercise caution with unidentified items"]
            } else {
                return ["Hard texture can damage braces", "May cause bracket damage"]
            }
        case .later:
            return ["Wait until temperature cools down", "Hot foods can increase sensitivity"]
        case .cannotIdentify:
            return ["Unable to identify this item as food", "For safety, avoid eating unidentified items", "Try taking a clearer photo or choosing a different item"]
        }
    }

    private func generateDetailedExplanation() {
        guard let result = result else { return }

        isLoadingExplanation = true
        showExplanation = true
        detailedExplanation = nil

        Task {
            do {
                
                let userProfile = firebaseService.currentUser ?? UserProfile(
                    id: "mock_user",
                    name: "Test User",
                    hasBraces: true
                )

                
                var contextParts: [String] = []

                
                contextParts.append("Food identified: \(result.foodName)")
                contextParts.append("Confidence: \(Int(result.confidence * 100))%")
                contextParts.append("Food characteristics: \(result.tags.map { $0.rawValue }.joined(separator: ", "))")
                contextParts.append("Current verdict: \(result.verdict.rawValue)")

                
                if userProfile.hasBraces {
                    contextParts.append("\nUser has braces")
                }

                
                for restriction in mockTreatmentPlan.restrictions {
                    var restrictionText = "Dietary restriction: \(restriction.type.rawValue)"
                    if let endDate = restriction.endDate {
                        restrictionText += " (until \(endDate.formatted(.dateTime.month().day())))"
                    }
                    if let reason = restriction.reason {
                        restrictionText += " - \(reason)"
                    }
                    contextParts.append(restrictionText)
                }

                
                if !mockTreatmentPlan.medications.isEmpty {
                    contextParts.append("\nCurrent medications:")
                    for med in mockTreatmentPlan.medications {
                        contextParts.append("- \(med.name) (\(med.dosage)): \(med.instructions ?? "")")
                    }
                }

                
                if !mockPainEntries.isEmpty {
                    contextParts.append("\nCurrent pain areas:")
                    for entry in mockPainEntries {
                        contextParts.append("- Tooth #\(entry.toothNumber): Pain level \(Int(entry.painLevel))/10 - \(entry.notes ?? "")")
                    }
                }

                
                if let alignerProgress = mockTreatmentPlan.alignerProgress {
                    contextParts.append("\nTreatment progress: Tray \(alignerProgress.currentTray) of \(alignerProgress.totalTrays)")
                }

                
                if !mockTreatmentPlan.doctorNotes.isEmpty {
                    contextParts.append("\nRecent doctor notes:")
                    for note in mockTreatmentPlan.doctorNotes.prefix(2) {
                        contextParts.append("- \(note.content)")
                    }
                }

                let userContext = contextParts.joined(separator: "\n")

                
                let prompt = """
                You are a dental health advisor. Provide a detailed, personalized explanation for why this food received the verdict "\(result.verdict.rawValue)".

                \(userContext)

                Please provide:
                1. A clear explanation of why this food is "\(result.verdict.rawValue)" for this specific user
                2. How the food's properties (\(result.tags.map { $0.rawValue }.joined(separator: ", "))) interact with their dental situation
                3. Specific concerns related to their current treatment stage and pain points
                4. Actionable advice based on their restrictions and medications
                5. If the verdict is "avoid" or "caution", suggest when and how they might be able to eat this food in the future

                Keep the explanation clear, empathetic, and practical. Use 2-3 paragraphs.
                """

                
                let context = DentalContext(
                    userProfile: userProfile,
                    treatmentPlan: mockTreatmentPlan,
                    recentPainEntries: mockPainEntries,
                    recentChewCheckResults: nil
                )

                let explanation = try await DentalBotService.shared.sendMessage(prompt, context: context)

                await MainActor.run {
                    detailedExplanation = explanation
                    isLoadingExplanation = false
                }
            } catch {
                await MainActor.run {
                    detailedExplanation = "Unable to generate detailed explanation. Please check your internet connection and try again."
                    isLoadingExplanation = false
                }
                print("Error generating explanation: \(error)")
            }
        }
    }

    private func saveChewCheckActivity(foodName: String) {
        guard let userId = firebaseService.currentUser?.id else {
            print("⚠️ No user ID available for activity tracking")
            return
        }

        Task {
            do {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "MMM d, h:mm a"

                let activity = RecentActivity(
                    date: dateFormatter.string(from: Date()),
                    description: "Scanned food item: \(foodName)",
                    type: .chewCheck,
                    timestamp: Date(),
                    foodName: foodName
                )

                try await firebaseService.saveActivity(activity, for: userId)
                print("✅ ChewCheck activity saved")

                try? await firebaseService.generateDentalSummary(for: userId)
                print("✅ Dental summary regenerated")

                NotificationCenter.default.post(name: NSNotification.Name("RefreshHomeData"), object: nil)
            } catch {
                print("❌ Error saving ChewCheck activity: \(error)")
            }
        }
    }
}

struct ChewCheckResultView: View {
    let result: ChewCheckResult
    let onWrongFood: () -> Void
    let onExplain: () -> Void

    var body: some View {
        GlassCard {
            VStack(spacing: 20) {
                
                HStack {
                    Image(systemName: result.verdict.icon)
                        .font(.title)
                        .foregroundStyle(result.verdict.color)
                    
                    VStack(alignment: .leading) {
                        Text(result.verdict.rawValue.capitalized)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(result.verdict.color)
                        
                        Text("\(result.foodName) • \(Int(result.confidence * 100))% confidence")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                }
                
                
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(result.reasons, id: \.self) { reason in
                        HStack {
                            Circle()
                                .fill(result.verdict.color)
                                .frame(width: 4, height: 4)
                            
                            Text(reason)
                                .font(.body)
                        }
                    }
                }
                
                
                HStack(spacing: 12) {
                    Button("Wrong food?", action: onWrongFood)
                        .font(.caption)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.thinMaterial, in: Capsule())
                    
                    Button("Explain", action: onExplain)
                    .font(.caption)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.blue, in: Capsule())
                    .foregroundStyle(.white)
                    
                    Spacer()
                }
                
                
                HStack {
                    Text("Source: \(result.source.displayName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
        }
    }
}

struct DetailedExplanationView: View {
    @Environment(\.dismiss) private var dismiss
    let result: ChewCheckResult?
    let explanation: String?
    let isLoading: Bool

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    if let result = result {
                        
                        VStack(spacing: 12) {
                            Image(systemName: result.verdict.icon)
                                .font(.system(size: 60))
                                .foregroundStyle(result.verdict.color)

                            Text(result.verdict.displayName)
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundStyle(result.verdict.color)

                            Text(result.foodName)
                                .font(.title2)
                                .foregroundStyle(.primary)

                            Text("\(Int(result.confidence * 100))% confidence")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 20)

                        Divider()
                            .padding(.horizontal)

                        
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Detailed Analysis")
                                .font(.headline)
                                .foregroundStyle(.primary)

                            if isLoading {
                                VStack(spacing: 16) {
                                    ProgressView()
                                        .scaleEffect(1.2)
                                    Text("Generating personalized explanation...")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 40)
                            } else if let explanation = explanation {
                                Text(explanation)
                                    .font(.body)
                                    .foregroundStyle(.primary)
                                    .lineSpacing(6)
                            } else {
                                Text("No explanation available")
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                                    .italic()
                            }
                        }
                        .padding(.horizontal, 20)

                        
                        if !result.tags.isEmpty {
                            Divider()
                                .padding(.horizontal)

                            VStack(alignment: .leading, spacing: 12) {
                                Text("Food Characteristics")
                                    .font(.headline)
                                    .foregroundStyle(.primary)

                                FlowLayout(spacing: 8) {
                                    ForEach(result.tags, id: \.self) { tag in
                                        Text(tag.rawValue.capitalized)
                                            .font(.caption)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(tag.color.opacity(0.2), in: Capsule())
                                            .foregroundStyle(tag.color)
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        }

                        
                        Text("Analysis by \(result.source.displayName)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.bottom, 20)
                    }
                }
            }
            .navigationTitle("Explanation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}


struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        var totalHeight: CGFloat = 0
        var totalWidth: CGFloat = 0
        var lineWidth: CGFloat = 0
        var lineHeight: CGFloat = 0

        for size in sizes {
            if lineWidth + size.width > proposal.width ?? 0 {
                totalHeight += lineHeight + spacing
                lineWidth = size.width
                lineHeight = size.height
            } else {
                lineWidth += size.width + spacing
                lineHeight = max(lineHeight, size.height)
            }
            totalWidth = max(totalWidth, lineWidth)
        }
        totalHeight += lineHeight
        return CGSize(width: totalWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var lineX = bounds.minX
        var lineY = bounds.minY
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if lineX + size.width > bounds.maxX {
                lineY += lineHeight + spacing
                lineHeight = 0
                lineX = bounds.minX
            }
            subview.place(at: CGPoint(x: lineX, y: lineY), proposal: .unspecified)
            lineHeight = max(lineHeight, size.height)
            lineX += size.width + spacing
        }
    }
}

#Preview {
    ChewCheckView()
}
