//
//  OCRPreviewView.swift
//  BrightBite
//
//  Created by Tuan Nguyen on 9/1/25.
//

import SwiftUI

struct OCRPreviewView: View {
    @Environment(\.dismiss) private var dismiss
    let extractedText: String

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "text.viewfinder")
                                .foregroundStyle(.blue)
                            Text("Apple Vision Framework OCR")
                                .font(.headline)
                        }

                        Text("This is what Apple's on-device OCR extracted from your scanned document.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))

                    
                    HStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Characters")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(extractedText.count)")
                                .font(.title3)
                                .fontWeight(.semibold)
                        }

                        Divider()
                            .frame(height: 40)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Words")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(wordCount)")
                                .font(.title3)
                                .fontWeight(.semibold)
                        }

                        Divider()
                            .frame(height: 40)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Lines")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(lineCount)")
                                .font(.title3)
                                .fontWeight(.semibold)
                        }

                        Spacer()
                    }
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))

                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Extracted Text")
                            .font(.headline)

                        if extractedText.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "doc.text.magnifyingglass")
                                    .font(.system(size: 48))
                                    .foregroundStyle(.secondary)

                                Text("No text detected")
                                    .font(.headline)
                                    .foregroundStyle(.secondary)

                                Text("The document may be blank, too blurry, or the text may not be machine-readable.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(40)
                        } else {
                            Text(extractedText)
                                .font(.body)
                                .textSelection(.enabled)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                        }
                    }

                    
                    if !extractedText.isEmpty {
                        Button(action: copyToClipboard) {
                            Label("Copy to Clipboard", systemImage: "doc.on.doc")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(.blue, in: RoundedRectangle(cornerRadius: 12))
                        }
                    }
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
            .navigationTitle("OCR Preview")
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

    private var wordCount: Int {
        extractedText.split(separator: " ").count
    }

    private var lineCount: Int {
        extractedText.split(separator: "\n").count
    }

    private func copyToClipboard() {
        UIPasteboard.general.string = extractedText
    }
}

#Preview {
    OCRPreviewView(
        extractedText: """
        DENTAL TREATMENT PLAN
        Patient: John Doe
        Date: October 14, 2025

        Diagnosis: Orthodontic treatment required
        Treatment: Braces installation
        Duration: 18-24 months

        Medications:
        - Ibuprofen 400mg, every 6 hours as needed

        Diet Restrictions:
        - Avoid hard foods for 2 weeks
        - No sticky candy

        Next Appointment: October 28, 2025 at 2:00 PM
        """
    )
}
