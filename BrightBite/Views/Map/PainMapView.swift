//
//  PainMapView.swift
//  BrightBite
//
//  Created by Tuan Nguyen on 9/1/25.
//

import SwiftUI
import RealityKit
import ARKit

struct PainMapView: View {
    @State private var selectedTooth: Int?
    @State private var showToothDetail = false
    @State private var showSettings = false
    @State private var painEntries: [Int: PainEntry] = [:]
    @State private var timelineDate = Date()
    
    var body: some View {
        NavigationView {
            ZStack {
                // 3D Mouth Model
                MouthModelView(
                    selectedTooth: $selectedTooth,
                    painEntries: painEntries,
                    onToothTapped: { toothNumber in
                        selectedTooth = toothNumber
                        showToothDetail = true
                    }
                )
                
                // Timeline scrubber
                VStack {
                    Spacer()
                    
                    GlassCard {
                        VStack(spacing: 8) {
                            Text("Timeline")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            HStack {
                                Text("7 days ago")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                
                                Slider(value: .constant(0.7), in: 0...1)
                                    .tint(.blue)
                                
                                Text("Today")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .frame(height: 60)
                    .padding(.horizontal)
                }
            }
            .navigationTitle("Pain Map")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showSettings = true }) {
                        Image(systemName: "slider.horizontal.3")
                            .foregroundStyle(.blue)
                    }
                }
            }
            .liquidGlassNavBar()
        }
        .sheet(isPresented: $showToothDetail) {
            if let selectedTooth = selectedTooth {
                ToothDetailSheet(
                    toothNumber: selectedTooth,
                    painEntry: painEntries[selectedTooth]
                ) { updatedEntry in
                    painEntries[selectedTooth] = updatedEntry
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            PainMapSettingsSheet()
        }
    }
}

struct MouthModelView: UIViewRepresentable {
    @Binding var selectedTooth: Int?
    let painEntries: [Int: PainEntry]
    let onToothTapped: (Int) -> Void
    
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        
        // Create a simple 3D mouth representation
        let mouthAnchor = AnchorEntity(world: SIMD3<Float>(0, 0, -0.3))
        
        // Create tooth entities in a mouth-like arrangement
        createTeethEntities(anchor: mouthAnchor)
        
        arView.scene.addAnchor(mouthAnchor)
        
        // Add tap gesture
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        arView.addGestureRecognizer(tapGesture)
        
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {
        // Update tooth colors based on pain levels
        updateToothColors(arView: uiView)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    private func createTeethEntities(anchor: AnchorEntity) {
        // Create a simplified mouth with 32 teeth
        let positions = generateToothPositions()
        
        for (toothNumber, position) in positions.enumerated() {
            let toothEntity = ModelEntity(
                mesh: .generateBox(size: SIMD3<Float>(0.015, 0.02, 0.01)),
                materials: [SimpleMaterial(color: .white, isMetallic: false)]
            )
            
            toothEntity.position = position
            toothEntity.name = "tooth_\(toothNumber + 1)"
            
            anchor.addChild(toothEntity)
        }
    }
    
    private func generateToothPositions() -> [SIMD3<Float>] {
        var positions: [SIMD3<Float>] = []
        
        // Upper jaw (teeth 1-16)
        for i in 0..<16 {
            let angle = Float(i) * 0.2 - 1.5
            let x = sin(angle) * 0.08
            let z = cos(angle) * 0.08
            positions.append(SIMD3<Float>(x, 0.02, z))
        }
        
        // Lower jaw (teeth 17-32)
        for i in 0..<16 {
            let angle = Float(i) * 0.2 - 1.5
            let x = sin(angle) * 0.08
            let z = cos(angle) * 0.08
            positions.append(SIMD3<Float>(x, -0.02, z))
        }
        
        return positions
    }
    
    private func updateToothColors(arView: ARView) {
        // Update tooth colors based on pain levels
        for anchor in arView.scene.anchors {
            for entity in anchor.children {
                if let modelEntity = entity as? ModelEntity,
                   entity.name.hasPrefix("tooth_") == true,
                   let toothNumber = Int(entity.name.replacingOccurrences(of: "tooth_", with: "") ?? ""),
                   let painEntry = painEntries[toothNumber] {
                    
                    let painColor = colorForPainLevel(painEntry.painLevel)
                    modelEntity.model?.materials = [SimpleMaterial(color: painColor, isMetallic: false)]
                }
            }
        }
    }
    
    private func colorForPainLevel(_ level: Double) -> UIColor {
        switch level {
        case 0:
            return .white
        case 1...3:
            return .systemYellow
        case 4...6:
            return .systemOrange
        case 7...10:
            return .systemRed
        default:
            return .white
        }
    }
    
    class Coordinator: NSObject {
        let parent: MouthModelView
        
        init(_ parent: MouthModelView) {
            self.parent = parent
        }
        
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            let arView = gesture.view as! ARView
            let location = gesture.location(in: arView)
            
            if let entity = arView.entity(at: location),
               entity.name.hasPrefix("tooth_") == true,
               let toothNumber = Int(entity.name.replacingOccurrences(of: "tooth_", with: "") ?? "") {
                parent.onToothTapped(toothNumber)
            }
        }
    }
}

struct ToothDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let toothNumber: Int
    @State private var painEntry: PainEntry
    let onSave: (PainEntry) -> Void
    
    init(toothNumber: Int, painEntry: PainEntry?, onSave: @escaping (PainEntry) -> Void) {
        self.toothNumber = toothNumber
        self._painEntry = State(initialValue: painEntry ?? PainEntry(toothNumber: toothNumber, painLevel: 0))
        self.onSave = onSave
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Tooth number
                Text("Tooth #\(toothNumber)")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                // Status pills
                ScrollView(.horizontal) {
                    HStack {
                        StatusPill(text: "Filling", color: .blue)
                        StatusPill(text: "Crown", color: .purple)
                        StatusPill(text: "Sensitive", color: .orange)
                    }
                    .padding(.horizontal)
                }
                
                // Pain level slider
                GlassCard {
                    VStack(spacing: 16) {
                        Text("Pain Level")
                            .font(.headline)
                        
                        HStack {
                            Text("0")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            Slider(value: $painEntry.painLevel, in: 0...10, step: 0.5)
                                .tint(colorForPainLevel(painEntry.painLevel))
                            
                            Text("10")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Text("\(painEntry.painLevel, specifier: "%.1f")/10")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundStyle(colorForPainLevel(painEntry.painLevel))
                    }
                }
                
                // Notes
                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Notes")
                            .font(.headline)
                        
                        TextField("Add notes about this tooth...", text: Binding(
                            get: { painEntry.notes ?? "" },
                            set: { painEntry.notes = $0.isEmpty ? nil : $0 }
                        ), axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(3...6)
                    }
                }
                
                Spacer()
                
                Button("Update") {
                    painEntry.timestamp = Date()
                    onSave(painEntry)
                    dismiss()
                }
                .liquidGlassButton(style: .accent)
                .padding(.horizontal)
            }
            .padding()
            .navigationTitle("Tooth Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func colorForPainLevel(_ level: Double) -> Color {
        switch level {
        case 0:
            return .gray
        case 0.1...3:
            return .yellow
        case 3.1...6:
            return .orange
        case 6.1...10:
            return .red
        default:
            return .gray
        }
    }
}

struct StatusPill: View {
    let text: String
    let color: Color
    
    var body: some View {
        Text(text)
            .font(.caption)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(color.opacity(0.2), in: Capsule())
            .foregroundStyle(color)
    }
}

struct PainMapSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showAdultTeeth = true
    @State private var showImplants = true
    @State private var showCrowns = true
    @State private var highlightRecentChanges = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                GlassCard {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Display Options")
                            .font(.headline)
                        
                        Toggle("Adult Teeth", isOn: $showAdultTeeth)
                        Toggle("Show Implants", isOn: $showImplants)
                        Toggle("Show Crowns", isOn: $showCrowns)
                        Toggle("Highlight Recent Changes", isOn: $highlightRecentChanges)
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Map Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// Placeholder for missing views
struct PainLogView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Text("Pain Log View")
                .navigationTitle("Log Pain")
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") { dismiss() }
                    }
                }
        }
    }
}

#Preview {
    PainMapView()
}
