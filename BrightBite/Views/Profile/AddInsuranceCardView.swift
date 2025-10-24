//
//  AddInsuranceCardView.swift
//  BrightBite
//
//  Created by Tuan Nguyen on 9/1/25.
//

import SwiftUI
import PhotosUI
import Vision

struct AddInsuranceCardView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var firebaseService: FirebaseService

    let existingCard: InsuranceCard?
    let onSave: () -> Void

    @State private var providerName: String
    @State private var memberId: String
    @State private var groupNumber: String
    @State private var policyHolderName: String
    @State private var planType: String
    @State private var customerServicePhone: String
    @State private var coveragePreventive: String
    @State private var coverageBasic: String
    @State private var coverageMajor: String
    @State private var annualMaximum: String
    @State private var deductible: String

    @State private var selectedImage: UIImage?
    @State private var showImagePicker = false
    @State private var showCamera = false
    @State private var imageSource: ImageSource = .photoLibrary
    @State private var isProcessingImage = false
    @State private var isSaving = false

    enum ImageSource {
        case camera
        case photoLibrary
    }

    init(existingCard: InsuranceCard? = nil, onSave: @escaping () -> Void) {
        self.existingCard = existingCard
        self.onSave = onSave

        
        _providerName = State(initialValue: existingCard?.providerName ?? "")
        _memberId = State(initialValue: existingCard?.memberId ?? "")
        _groupNumber = State(initialValue: existingCard?.groupNumber ?? "")
        _policyHolderName = State(initialValue: existingCard?.policyHolderName ?? "")
        _planType = State(initialValue: existingCard?.planType ?? "")
        _customerServicePhone = State(initialValue: existingCard?.customerServicePhone ?? "")
        _coveragePreventive = State(initialValue: existingCard?.coveragePreventive.map { "\($0)" } ?? "")
        _coverageBasic = State(initialValue: existingCard?.coverageBasic.map { "\($0)" } ?? "")
        _coverageMajor = State(initialValue: existingCard?.coverageMajor.map { "\($0)" } ?? "")
        _annualMaximum = State(initialValue: existingCard?.annualMaximum.map { "\(Int($0))" } ?? "")
        _deductible = State(initialValue: existingCard?.deductible.map { "\(Int($0))" } ?? "")
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    
                    VStack(spacing: 16) {
                        Text("Scan or Upload Card")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        if let image = selectedImage {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .cornerRadius(12)
                                .shadow(color: .black.opacity(0.1), radius: 10)

                            HStack(spacing: 12) {
                                Button(action: {
                                    imageSource = .camera
                                    showCamera = true
                                }) {
                                    Label("Retake", systemImage: "camera")
                                        .frame(maxWidth: .infinity)
                                }
                                .liquidGlassButton(style: .secondary)

                                Button(action: {
                                    imageSource = .photoLibrary
                                    showImagePicker = true
                                }) {
                                    Label("Choose Different", systemImage: "photo")
                                        .frame(maxWidth: .infinity)
                                }
                                .liquidGlassButton(style: .secondary)
                            }

                            if isProcessingImage {
                                HStack(spacing: 8) {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("Extracting card information...")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.top, 8)
                            }
                        } else {
                            HStack(spacing: 12) {
                                Button(action: {
                                    imageSource = .camera
                                    showCamera = true
                                }) {
                                    VStack(spacing: 8) {
                                        Image(systemName: "camera.fill")
                                            .font(.title2)
                                        Text("Take Photo")
                                            .font(.subheadline)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 20)
                                }
                                .liquidGlassButton(style: .accent)

                                Button(action: {
                                    imageSource = .photoLibrary
                                    showImagePicker = true
                                }) {
                                    VStack(spacing: 8) {
                                        Image(systemName: "photo.fill")
                                            .font(.title2)
                                        Text("Choose Photo")
                                            .font(.subheadline)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 20)
                                }
                                .liquidGlassButton(style: .accent)
                            }

                            Text("Scan your insurance card to auto-fill information")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.horizontal)

                    Divider()
                        .padding(.horizontal)

                    
                    VStack(spacing: 16) {
                        Text("Card Information")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        
                        VStack(spacing: 12) {
                            TextField("Provider Name *", text: $providerName)
                                .textFieldStyle(.roundedBorder)

                            TextField("Member ID *", text: $memberId)
                                .textFieldStyle(.roundedBorder)

                            TextField("Policy Holder Name *", text: $policyHolderName)
                                .textFieldStyle(.roundedBorder)
                        }

                        
                        VStack(spacing: 12) {
                            TextField("Group Number", text: $groupNumber)
                                .textFieldStyle(.roundedBorder)

                            TextField("Plan Type", text: $planType)
                                .textFieldStyle(.roundedBorder)

                            TextField("Customer Service Phone", text: $customerServicePhone)
                                .textFieldStyle(.roundedBorder)
                                .keyboardType(.phonePad)
                        }

                        Text("Coverage Percentages")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 8)

                        VStack(spacing: 12) {
                            HStack {
                                Text("Preventive:")
                                    .frame(width: 100, alignment: .leading)
                                TextField("100", text: $coveragePreventive)
                                    .textFieldStyle(.roundedBorder)
                                    .keyboardType(.numberPad)
                                Text("%")
                            }

                            HStack {
                                Text("Basic:")
                                    .frame(width: 100, alignment: .leading)
                                TextField("80", text: $coverageBasic)
                                    .textFieldStyle(.roundedBorder)
                                    .keyboardType(.numberPad)
                                Text("%")
                            }

                            HStack {
                                Text("Major:")
                                    .frame(width: 100, alignment: .leading)
                                TextField("50", text: $coverageMajor)
                                    .textFieldStyle(.roundedBorder)
                                    .keyboardType(.numberPad)
                                Text("%")
                            }
                        }

                        Text("Financial Details")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 8)

                        VStack(spacing: 12) {
                            HStack {
                                Text("Annual Maximum:")
                                    .frame(width: 150, alignment: .leading)
                                Text("$")
                                TextField("1500", text: $annualMaximum)
                                    .textFieldStyle(.roundedBorder)
                                    .keyboardType(.numberPad)
                            }

                            HStack {
                                Text("Deductible:")
                                    .frame(width: 150, alignment: .leading)
                                Text("$")
                                TextField("50", text: $deductible)
                                    .textFieldStyle(.roundedBorder)
                                    .keyboardType(.numberPad)
                            }
                        }

                        Text("* Required fields")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal)
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
            .navigationTitle(existingCard == nil ? "Add Insurance Card" : "Edit Insurance Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: saveCard) {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Save")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(!isFormValid || isSaving)
                }
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(image: $selectedImage, sourceType: .photoLibrary)
                    .onDisappear {
                        if selectedImage != nil {
                            performOCR()
                        }
                    }
            }
            .sheet(isPresented: $showCamera) {
                ImagePicker(image: $selectedImage, sourceType: .camera)
                    .onDisappear {
                        if selectedImage != nil {
                            performOCR()
                        }
                    }
            }
        }
    }

    private var isFormValid: Bool {
        !providerName.isEmpty && !memberId.isEmpty && !policyHolderName.isEmpty
    }

    private func performOCR() {
        guard let image = selectedImage?.cgImage else { return }

        isProcessingImage = true

        let request = VNRecognizeTextRequest { request, error in
            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                isProcessingImage = false
                return
            }

            let recognizedText = observations.compactMap { observation in
                observation.topCandidates(1).first?.string
            }

            DispatchQueue.main.async {
                extractCardInformation(from: recognizedText)
                isProcessingImage = false
            }
        }

        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            try? handler.perform([request])
        }
    }

    private func extractCardInformation(from text: [String]) {
        print("📄 Extracted text from card:")
        text.forEach { print("  - \($0)") }

        
        for (index, line) in text.enumerated() {
            let lowercased = line.lowercased()

            
            if providerName.isEmpty {
                if line.count > 5 && !line.contains(":") {
                    providerName = line
                }
            }

            
            if lowercased.contains("member") || lowercased.contains("id") {
                if index + 1 < text.count {
                    let nextLine = text[index + 1]
                    if nextLine.rangeOfCharacter(from: CharacterSet.letters.inverted) != nil {
                        memberId = nextLine
                    }
                }
            }

            
            if lowercased.contains("group") {
                if index + 1 < text.count {
                    groupNumber = text[index + 1]
                }
            }

            
            if line.contains("-") && line.filter({ $0.isNumber }).count >= 10 {
                customerServicePhone = line
            }

            
            if lowercased.contains("preventive") || lowercased.contains("prevent") {
                if let percentage = line.components(separatedBy: CharacterSet.decimalDigits.inverted)
                    .compactMap({ Int($0) }).first {
                    coveragePreventive = "\(percentage)"
                }
            }

            if lowercased.contains("basic") {
                if let percentage = line.components(separatedBy: CharacterSet.decimalDigits.inverted)
                    .compactMap({ Int($0) }).first {
                    coverageBasic = "\(percentage)"
                }
            }

            if lowercased.contains("major") {
                if let percentage = line.components(separatedBy: CharacterSet.decimalDigits.inverted)
                    .compactMap({ Int($0) }).first {
                    coverageMajor = "\(percentage)"
                }
            }

            
            if lowercased.contains("annual") || lowercased.contains("maximum") {
                if let amount = line.components(separatedBy: CharacterSet.decimalDigits.inverted)
                    .compactMap({ Int($0) }).first, amount > 100 {
                    annualMaximum = "\(amount)"
                }
            }

            
            if lowercased.contains("deductible") {
                if let amount = line.components(separatedBy: CharacterSet.decimalDigits.inverted)
                    .compactMap({ Int($0) }).first {
                    deductible = "\(amount)"
                }
            }
        }

        print("✅ Extracted card information:")
        print("  Provider: \(providerName)")
        print("  Member ID: \(memberId)")
        print("  Group: \(groupNumber)")
    }

    private func saveCard() {
        guard let userId = firebaseService.currentUser?.id else { return }

        isSaving = true

        let imageData = selectedImage?.jpegData(compressionQuality: 0.8)

        let card = InsuranceCard(
            id: existingCard?.id ?? UUID(),
            providerName: providerName,
            memberId: memberId,
            groupNumber: groupNumber.isEmpty ? nil : groupNumber,
            policyHolderName: policyHolderName,
            planType: planType.isEmpty ? nil : planType,
            customerServicePhone: customerServicePhone.isEmpty ? nil : customerServicePhone,
            coveragePreventive: Int(coveragePreventive),
            coverageBasic: Int(coverageBasic),
            coverageMajor: Int(coverageMajor),
            annualMaximum: Double(annualMaximum),
            deductible: Double(deductible),
            cardImageURL: existingCard?.cardImageURL,
            cardImageData: imageData,
            createdAt: existingCard?.createdAt ?? Date(),
            lastUpdated: Date()
        )

        Task {
            do {
                try await firebaseService.saveInsuranceCard(card, for: userId)
                await MainActor.run {
                    isSaving = false
                    onSave()
                    dismiss()
                }
                print("✅ Saved insurance card")
            } catch {
                print("❌ Failed to save insurance card: \(error)")
                await MainActor.run {
                    isSaving = false
                }
            }
        }
    }
}


struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    let sourceType: UIImagePickerController.SourceType

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
            }
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

#Preview {
    AddInsuranceCardView(onSave: {})
}
