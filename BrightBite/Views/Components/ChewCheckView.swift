//
//  ChewCheckView.swift
//  BrightBite
//
//  Created by Tuan Nguyen on 9/1/25.
//

import SwiftUI
import PhotosUI

struct ChewCheckView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var isAnalyzing = false
    @State private var result: ChewCheckResult?
    @State private var showAlternatives = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if let result = result {
                    ChewCheckResultView(result: result) {
                        showAlternatives = true
                    }
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
                        // Camera icon
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
            AlternativeFoodsSheet(alternatives: ["Apple", "Banana", "Carrot"]) { selectedFood in
                // Re-analyze with corrected food
                analyzeFood(selectedImage, correctedFood: selectedFood)
            }
        }
    }
    
    private func analyzeFood(_ image: UIImage?, correctedFood: String? = nil) {
        guard let image = image else { return }
        
        isAnalyzing = true
        
        // Simulate CoreML analysis
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isAnalyzing = false
            
            // Mock result
            let foodName = correctedFood ?? "Yogurt"
            let tags: [FoodTag] = [.soft, .cold]
            let verdict = determineFoodVerdict(for: tags)
            
            result = ChewCheckResult(
                foodName: foodName,
                confidence: 0.89,
                verdict: verdict,
                tags: tags,
                reasons: generateReasons(for: verdict, tags: tags),
                source: correctedFood != nil ? .userCorrected : .mlModel,
                alternatives: ["Greek Yogurt", "Pudding", "Ice Cream"]
            )
        }
    }
    
    private func determineFoodVerdict(for tags: [FoodTag]) -> FoodVerdict {
        // Mock logic based on treatment restrictions
        if tags.contains(.hard) || tags.contains(.sticky) || tags.contains(.chewy) {
            return .avoid
        } else if tags.contains(.sugary) || tags.contains(.acidic) {
            return .caution
        } else if tags.contains(.hot) {
            return .later
        } else {
            return .safe
        }
    }
    
    private func generateReasons(for verdict: FoodVerdict, tags: [FoodTag]) -> [String] {
        switch verdict {
        case .safe:
            return ["Soft texture is gentle on your braces", "Cool temperature won't cause sensitivity"]
        case .caution:
            return ["Contains sugar - rinse after eating", "Acidic foods can affect enamel"]
        case .avoid:
            return ["Hard texture can damage braces", "May cause bracket damage"]
        case .later:
            return ["Wait until temperature cools down", "Hot foods can increase sensitivity"]
        }
    }
}

struct ChewCheckResultView: View {
    let result: ChewCheckResult
    let onWrongFood: () -> Void
    
    var body: some View {
        GlassCard {
            VStack(spacing: 20) {
                // Verdict header
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
                
                // Reasons
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
                
                // Action buttons
                HStack(spacing: 12) {
                    Button("Wrong food?", action: onWrongFood)
                        .font(.caption)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.thinMaterial, in: Capsule())
                    
                    Button("Explain") {
                        // TODO: Get explanation from DentalBot
                    }
                    .font(.caption)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.blue, in: Capsule())
                    .foregroundStyle(.white)
                    
                    Spacer()
                }
                
                // Source info
                HStack {
                    Text("Source: \(result.source == .mlModel ? "ML Model" : "User Corrected")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
        }
    }
}

struct AlternativeFoodsSheet: View {
    @Environment(\.dismiss) private var dismiss
    let alternatives: [String]
    let onSelect: (String) -> Void
    
    var body: some View {
        NavigationView {
            List(alternatives, id: \.self) { food in
                Button(food) {
                    onSelect(food)
                    dismiss()
                }
            }
            .navigationTitle("Choose Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    ChewCheckView()
}