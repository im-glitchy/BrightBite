//
//  ScanDentistNotesView.swift
//  BrightBite
//
//  Created by Tuan Nguyen on 9/15/25.
//

import SwiftUI
import VisionKit
import Vision

struct ScanDentistNotesView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var firebaseService: FirebaseService
    @State private var showScanner = false
    @State private var scannedImages: [UIImage] = []
    @State private var extractedText: String = ""
    @State private var isProcessing = false
    @State private var showSuccessAlert = false

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if scannedImages.isEmpty {
                    
                    VStack(spacing: 30) {
                        Image(systemName: "doc.text.viewfinder")
                            .font(.system(size: 80))
                            .foregroundStyle(.blue)

                        Text("Scan Dentist Notes")
                            .font(.title2)
                            .fontWeight(.semibold)

                        Text("Use your camera to scan appointment notes, treatment plans, or prescriptions from your dentist.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)

                        Button(action: { showScanner = true }) {
                            Label("Start Scanning", systemImage: "camera")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(.blue, in: RoundedRectangle(cornerRadius: 12))
                        }
                        .padding(.horizontal, 40)
                    }
                } else {
                    
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            
                            Text("Scanned Documents")
                                .font(.headline)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(Array(scannedImages.enumerated()), id: \.offset) { index, image in
                                        Image(uiImage: image)
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(height: 200)
                                            .cornerRadius(12)
                                            .shadow(radius: 4)
                                    }
                                }
                            }

                            Divider()

                            
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Extracted Text")
                                    .font(.headline)

                                if isProcessing {
                                    HStack {
                                        ProgressView()
                                        Text("Processing document...")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                } else if !extractedText.isEmpty {
                                    Text(extractedText)
                                        .font(.body)
                                        .padding()
                                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                                } else {
                                    Text("No text detected")
                                        .font(.body)
                                        .foregroundStyle(.secondary)
                                        .italic()
                                        .padding()
                                }
                            }

                            Spacer()

                            
                            VStack(spacing: 12) {
                                Button(action: saveNote) {
                                    Text("Save Note")
                                        .font(.headline)
                                        .foregroundStyle(.white)
                                        .padding()
                                        .frame(maxWidth: .infinity)
                                        .background(.blue, in: RoundedRectangle(cornerRadius: 12))
                                }
                                .disabled(extractedText.isEmpty || isProcessing)

                                Button(action: { showScanner = true }) {
                                    Text("Scan Another Document")
                                        .font(.headline)
                                        .foregroundStyle(.blue)
                                        .padding()
                                        .frame(maxWidth: .infinity)
                                        .background(.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Scan Notes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showScanner) {
                DocumentScannerView { images in
                    handleScannedImages(images)
                }
            }
            .alert("Note Saved", isPresented: $showSuccessAlert) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Your dentist note has been saved successfully.")
            }
        }
    }

    private func handleScannedImages(_ images: [UIImage]) {
        scannedImages.append(contentsOf: images)
        extractTextFromImages(images)
    }

    private func extractTextFromImages(_ images: [UIImage]) {
        isProcessing = true
        extractedText = ""

        Task {
            var allText = ""

            for image in images {
                if let text = await OCRService.shared.extractText(from: image) {
                    allText += text + "\n\n"
                }
            }

            await MainActor.run {
                extractedText = allText.trimmingCharacters(in: .whitespacesAndNewlines)
                isProcessing = false
            }
        }
    }

    private func saveNote() {
        guard !extractedText.isEmpty,
              let userId = firebaseService.currentUser?.id else { return }

        Task {
            do {
                let note = DoctorNote(
                    title: "Scanned Document",
                    content: extractedText,
                    createdAt: Date(),
                    source: .scanned
                )

                var treatmentPlan = try await firebaseService.loadTreatmentPlan(for: userId)
                treatmentPlan.doctorNotes.append(note)

                try await firebaseService.saveTreatmentPlan(treatmentPlan, for: userId)
                print("✅ Doctor note saved to treatment plan")

                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "MMM d, h:mm a"

                let activity = RecentActivity(
                    date: dateFormatter.string(from: Date()),
                    description: "Scanned dentist notes",
                    type: .notesScan,
                    timestamp: Date(),
                    documentId: note.id.uuidString
                )

                try await firebaseService.saveActivity(activity, for: userId)
                print("✅ Notes scan activity saved")

                try? await firebaseService.generateDentalSummary(for: userId)
                print("✅ Dental summary regenerated")

                NotificationCenter.default.post(name: NSNotification.Name("RefreshHomeData"), object: nil)

                await MainActor.run {
                    showSuccessAlert = true
                }
            } catch {
                print("❌ Error saving note: \(error)")
                await MainActor.run {
                    showSuccessAlert = true
                }
            }
        }
    }
}


struct DocumentScannerView: UIViewControllerRepresentable {
    var onScan: ([UIImage]) -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let scanner = VNDocumentCameraViewController()
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {
        
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onScan: onScan)
    }

    class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        var onScan: ([UIImage]) -> Void

        init(onScan: @escaping ([UIImage]) -> Void) {
            self.onScan = onScan
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            var images: [UIImage] = []
            for i in 0..<scan.pageCount {
                images.append(scan.imageOfPage(at: i))
            }
            onScan(images)
            controller.dismiss(animated: true)
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            controller.dismiss(animated: true)
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            print("Document scanning failed: \(error.localizedDescription)")
            controller.dismiss(animated: true)
        }
    }
}


class OCRService {
    static let shared = OCRService()

    func extractText(from image: UIImage) async -> String? {
        guard let cgImage = image.cgImage else {
            print("Failed to get CGImage from UIImage")
            return nil
        }

        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    print("OCR Error: \(error.localizedDescription)")
                    continuation.resume(returning: nil)
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    print("No text observations found")
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
}

#Preview {
    ScanDentistNotesView()
}
