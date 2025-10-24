//
//  AlternativeFoodsSheet.swift
//  BrightBite
//
//  Created by Tuan Nguyen on 9/15/25.
//

import SwiftUI

struct AlternativeFoodsSheet: View {
    let alternatives: [String]
    let onSelectFood: (String) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var customFood: String = ""
    @State private var showCustomInput: Bool = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("What food did you actually scan?")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                    .padding()
                
                Text("Select from suggestions or type your own:")
                    .font(.body)
                    .foregroundStyle(.secondary)
                
                
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    ForEach(alternatives, id: \.self) { food in
                        Button(action: {
                            onSelectFood(food)
                            dismiss()
                        }) {
                            Text(food)
                                .font(.body)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
                        }
                        .foregroundStyle(.primary)
                    }
                }
                .padding(.horizontal)
                
                
                VStack(spacing: 12) {
                    Button(action: {
                        showCustomInput.toggle()
                    }) {
                        HStack {
                            Image(systemName: "plus.circle")
                            Text("Enter custom food")
                        }
                        .font(.body)
                        .foregroundStyle(.blue)
                    }
                    
                    if showCustomInput {
                        HStack {
                            TextField("Enter food name...", text: $customFood)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            
                            Button("Analyze") {
                                guard !customFood.isEmpty else { return }
                                onSelectFood(customFood)
                                dismiss()
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(customFood.isEmpty)
                        }
                        .padding(.horizontal)
                    }
                }
                
                Spacer()
            }
            .navigationTitle("Correct Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}
