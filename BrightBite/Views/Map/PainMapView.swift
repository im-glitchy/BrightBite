//
//  PainMapView.swift
//  BrightBite
//
//  Created by Tuan Nguyen on 8/25/25.
//

import SwiftUI
import RealityKit
import Foundation
import Combine

enum TimeScale: String, CaseIterable {
    case day = "Day"
    case week = "Week"
    case month = "Month"
    case year = "Year"
    case years = "All Time"

    var dateComponent: Calendar.Component {
        switch self {
        case .day: return .day
        case .week: return .weekOfYear
        case .month: return .month
        case .year: return .year
        case .years: return .year
        }
    }

    var value: Int {
        switch self {
        case .day: return 1
        case .week: return 7
        case .month: return 30
        case .year: return 365
        case .years: return 0 
        }
    }
}

struct PainMapView: View {
    @EnvironmentObject private var firebaseService: FirebaseService
    @EnvironmentObject private var tabNavigation: TabNavigationManager
    @State private var selectedTooth: Int?
    @State private var showToothDetail = false
    @State private var showSettings = false
    @State private var painEntries: [Int: PainEntry] = [:]
    @State private var toothStatuses: [Int: ToothStatus] = [:]
    @State private var timelineDate = Date()
    @State private var showMissingTeeth = false
    @State private var oldestDate: Date?
    @State private var isDataLoaded = false
    @State private var newestDate: Date = Date()
    @State private var isLoadingTimeline = false
    @State private var selectedTimeScale: TimeScale = .week
    @State private var debounceTask: Task<Void, Never>?

    var body: some View {
        NavigationView {
            ZStack {
                
                MouthModelView(
                    selectedTooth: $selectedTooth,
                    painEntries: painEntries,
                    toothStatuses: toothStatuses,
                    showMissingTeeth: showMissingTeeth,
                    onToothTapped: { toothNumber in
                        guard isDataLoaded else {
                            print("⚠️ Data not loaded yet, ignoring tap")
                            return
                        }
                        selectedTooth = toothNumber
                        showToothDetail = true
                    }
                )
                
                VStack {

                    GlassCard {
                        VStack(spacing: 4) {
                            HStack(spacing: 8) {
                                Image(systemName: "hand.draw")
                                    .foregroundStyle(.blue)
                                Text("Drag to rotate • Pinch to zoom • Tap teeth to log pain")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            if showMissingTeeth {
                                HStack(spacing: 8) {
                                    Image(systemName: "eye.fill")
                                        .foregroundStyle(.gray)
                                        .font(.caption2)
                                    Text("Missing teeth shown in gray")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)
                    
                    Spacer()
                    

                    if let oldestDate = oldestDate {
                        GlassCard {
                            VStack(spacing: 8) {
                                HStack {
                                    Text(formatDate(timelineDate))
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.blue)

                                    Spacer()

                                    Picker("", selection: $selectedTimeScale) {
                                        ForEach(TimeScale.allCases, id: \.self) { scale in
                                            Text(scale.rawValue).tag(scale)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .font(.caption2)

                                    if isLoadingTimeline {
                                        ProgressView()
                                            .scaleEffect(0.7)
                                    }

                                    if !Calendar.current.isDate(timelineDate, inSameDayAs: Date()) {
                                        Button("Today") {
                                            timelineDate = Date()
                                            loadPainEntries(for: timelineDate)
                                        }
                                        .font(.caption2)
                                        .foregroundStyle(.blue)
                                    }
                                }

                                HStack {
                                    Text(formatDateShort(getStartDate(for: selectedTimeScale)))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)

                                    Slider(value: Binding(
                                        get: {
                                            let startDate = getStartDate(for: selectedTimeScale)
                                            let endDate = newestDate
                                            let range = endDate.timeIntervalSince(startDate)
                                            let current = timelineDate.timeIntervalSince(startDate)
                                            return range > 0 ? current / range : 0
                                        },
                                        set: { newValue in
                                            let startDate = getStartDate(for: selectedTimeScale)
                                            let endDate = newestDate
                                            let range = endDate.timeIntervalSince(startDate)
                                            timelineDate = startDate.addingTimeInterval(range * newValue)
                                        }
                                    ), in: 0...1)
                                    .tint(.blue)
                                    .onChange(of: timelineDate) { _, newDate in
                                        debounceTask?.cancel()
                                        debounceTask = Task {
                                            try? await Task.sleep(nanoseconds: 300_000_000)
                                            if !Task.isCancelled {
                                                loadPainEntries(for: newDate)
                                            }
                                        }
                                    }

                                    Text(formatDateShort(newestDate))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .frame(height: 70)
                        .padding(.horizontal)
                        .padding(.bottom, 30)
                    }
                }

                if !isDataLoaded {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()

                        VStack(spacing: 12) {
                            ProgressView()
                                .scaleEffect(1.5)
                                .tint(.white)

                            Text("Loading tooth data...")
                                .font(.caption)
                                .foregroundStyle(.white)
                        }
                        .padding(24)
                        .background(.ultraThinMaterial)
                        .cornerRadius(16)
                    }
                }
            }
            .navigationTitle("Pain Map")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showMissingTeeth.toggle() }) {
                        Image(systemName: showMissingTeeth ? "eye.fill" : "eye.slash.fill")
                            .foregroundStyle(.blue)
                    }
                }

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
                    painEntry: painEntries[selectedTooth],
                    toothStatus: toothStatuses[selectedTooth]
                ) { updatedEntry in
                    painEntries[selectedTooth] = updatedEntry
                    savePainEntry(updatedEntry)
                } onStatusUpdate: { updatedStatus in
                    toothStatuses[selectedTooth] = updatedStatus
                    saveToothStatus(updatedStatus)
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            PainMapSettingsSheet()
        }
        .onAppear {
            Task {
                await loadInitialData()
            }
        }
        .onChange(of: tabNavigation.selectedToothNumber) { oldValue, newValue in
            if let toothNumber = newValue, isDataLoaded {
                selectedTooth = toothNumber
                showToothDetail = true
                // Clear the selection after opening
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    tabNavigation.selectedToothNumber = nil
                }
            }
        }
    }

    private func loadToothStatuses(for date: Date? = nil) {
        guard let userId = firebaseService.currentUser?.id else { return }

        Task {
            do {
                
                let statuses = try await firebaseService.getToothStatuses(for: userId, on: nil)
                await MainActor.run {
                    self.toothStatuses = statuses
                }
                print("🦷 Loaded \(statuses.count) current tooth statuses")
            } catch {
                print("Error loading tooth statuses: \(error)")
            }
        }
    }

    private func loadDateRange() {
        guard let userId = firebaseService.currentUser?.id else { return }

        Task {
            do {
                if let range = try await firebaseService.getDateRange(for: userId) {
                    await MainActor.run {
                        self.oldestDate = range.oldest
                        self.newestDate = range.newest
                    }
                }
            } catch {
                print("Error loading date range: \(error)")
            }
        }
    }

    private func loadPainEntries(for date: Date? = nil) {
        guard let userId = firebaseService.currentUser?.id else { return }

        isLoadingTimeline = true

        Task {
            do {

                async let entries = firebaseService.getPainEntries(for: userId, on: date)
                async let statuses = firebaseService.getToothStatuses(for: userId, on: date)

                let (loadedEntries, loadedStatuses) = try await (entries, statuses)

                await MainActor.run {
                    self.painEntries = loadedEntries
                    self.toothStatuses = loadedStatuses
                    self.isLoadingTimeline = false
                }

                print("📅 Timeline: Loaded \(loadedEntries.count) pain entries and \(loadedStatuses.count) tooth statuses for \(date?.description ?? "current")")
            } catch {
                print("Error loading pain entries: \(error)")
                await MainActor.run {
                    self.isLoadingTimeline = false
                }
            }
        }
    }

    private func loadInitialData() async {
        guard let userId = firebaseService.currentUser?.id else { return }

        do {
            async let entries = firebaseService.getPainEntries(for: userId, on: timelineDate)
            async let statuses = firebaseService.getToothStatuses(for: userId, on: nil)

            let (loadedEntries, loadedStatuses) = try await (entries, statuses)

            await MainActor.run {
                self.painEntries = loadedEntries
                self.toothStatuses = loadedStatuses
                self.isDataLoaded = true
            }

            print("✅ Initial data loaded: \(loadedEntries.count) pain entries, \(loadedStatuses.count) tooth statuses")

            loadDateRange()
        } catch {
            print("❌ Error loading initial data: \(error)")
            await MainActor.run {
                self.isDataLoaded = true
            }
        }
    }

    private func saveToothStatus(_ status: ToothStatus) {
        guard let userId = firebaseService.currentUser?.id else { return }

        print("DEBUG PainMapView: Saving tooth status for tooth #\(status.toothNumber), condition: \(status.condition.rawValue)")

        Task {
            do {
                try await firebaseService.saveToothStatus(status, for: userId)

                let dateFormatter = DateFormatter()
                dateFormatter.dateStyle = .medium
                dateFormatter.timeStyle = .short

                let activity = RecentActivity(
                    date: dateFormatter.string(from: Date()),
                    description: "Updated tooth #\(status.toothNumber)",
                    type: .toothUpdate,
                    timestamp: Date(),
                    toothNumber: status.toothNumber
                )

                try? await firebaseService.saveActivity(activity, for: userId)
                try? await firebaseService.generateDentalSummary(for: userId)

                NotificationCenter.default.post(name: NSNotification.Name("RefreshHomeData"), object: nil)
            } catch {
                print("Error saving tooth status: \(error)")
            }
        }
    }

    private func savePainEntry(_ entry: PainEntry) {
        guard let userId = firebaseService.currentUser?.id else { return }

        print("DEBUG PainMapView: Saving pain entry for tooth #\(entry.toothNumber), pain level: \(entry.painLevel)")

        Task {
            do {
                try await firebaseService.savePainEntry(entry, for: userId)

                let dateFormatter = DateFormatter()
                dateFormatter.dateStyle = .medium
                dateFormatter.timeStyle = .short

                let activity = RecentActivity(
                    date: dateFormatter.string(from: Date()),
                    description: "Updated tooth #\(entry.toothNumber)",
                    type: .toothUpdate,
                    timestamp: Date(),
                    toothNumber: entry.toothNumber
                )

                try? await firebaseService.saveActivity(activity, for: userId)
                try? await firebaseService.generateDentalSummary(for: userId)

                loadDateRange()

                NotificationCenter.default.post(name: NSNotification.Name("RefreshHomeData"), object: nil)
            } catch {
                print("Error saving pain entry: \(error)")
            }
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        if Calendar.current.isDateInToday(date) {
            return "Today"
        } else if Calendar.current.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            return formatter.string(from: date)
        }
    }

    private func formatDateShort(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }

    private func getStartDate(for timeScale: TimeScale) -> Date {
        guard let oldestDate = oldestDate else { return Date() }

        
        if timeScale == .years {
            return oldestDate
        }

        
        let calendar = Calendar.current
        let startDate: Date

        switch timeScale {
        case .day:
            startDate = calendar.date(byAdding: .day, value: -1, to: newestDate) ?? newestDate
        case .week:
            startDate = calendar.date(byAdding: .day, value: -7, to: newestDate) ?? newestDate
        case .month:
            startDate = calendar.date(byAdding: .month, value: -1, to: newestDate) ?? newestDate
        case .year:
            startDate = calendar.date(byAdding: .year, value: -1, to: newestDate) ?? newestDate
        case .years:
            startDate = oldestDate
        }

        
        return max(startDate, oldestDate)
    }
}

struct MouthModelView: View {
    @Binding var selectedTooth: Int?
    let painEntries: [Int: PainEntry]
    let toothStatuses: [Int: ToothStatus]
    let showMissingTeeth: Bool
    let onToothTapped: (Int) -> Void
    @ObservedObject private var meshCache = MeshCache.shared
    @State private var currentRotationY: Float = 0
    @State private var currentRotationX: Float = 0  
    @State private var currentScale: Float = 10.0  
    @State private var baseScale: Float = 10.0     
    @State private var lastRotationY: Float = 0
    @State private var lastRotationX: Float = 0
    @State private var mouthAnchor: AnchorEntity?
    @State private var lastPainEntries: [Int: PainEntry] = [:]
    @State private var lastToothStatuses: [Int: ToothStatus] = [:]
    
    var body: some View {
        RealityView { content in
            let anchor = AnchorEntity()
            anchor.name = "mouth_anchor"
            anchor.position = SIMD3<Float>(0, 0, -0.3)

            self.createRealisticTeethEntities(anchor: anchor)

            let xRotation = simd_quatf(angle: self.currentRotationX, axis: SIMD3<Float>(1, 0, 0))
            let yRotation = simd_quatf(angle: self.currentRotationY, axis: SIMD3<Float>(0, 1, 0))

            anchor.orientation = xRotation * yRotation
            anchor.scale = SIMD3<Float>(repeating: self.currentScale)

            content.add(anchor)
            self.mouthAnchor = anchor

            let lightAnchor = AnchorEntity()
            let lightEntity = Entity()
            lightEntity.components[DirectionalLightComponent.self] = DirectionalLightComponent(
                color: .white,
                intensity: 2000,
                isRealWorldProxy: false
            )
            lightEntity.orientation = simd_quatf(angle: -.pi/4, axis: SIMD3<Float>(1, 1, 0))
            lightAnchor.addChild(lightEntity)
            content.add(lightAnchor)
        } update: { content in
            guard let anchor = content.entities.first(where: { $0.name == "mouth_anchor" }) else { return }

            let painEntriesChanged = painEntries != lastPainEntries
            let toothStatusesChanged = toothStatuses != lastToothStatuses

            guard painEntriesChanged || toothStatusesChanged else { return }

            for child in anchor.children {
                if let toothEntity = child as? ModelEntity {
                    let toothName = toothEntity.name
                    if toothName.hasPrefix("tooth_") {
                        let numberString = toothName.replacingOccurrences(of: "tooth_", with: "")
                        if let toothNumber = Int(numberString) {
                            let isMissing = toothStatuses[toothNumber]?.condition.shouldHide ?? false

                            if isMissing && !showMissingTeeth {
                                toothEntity.isEnabled = false
                            } else {
                                toothEntity.isEnabled = true

                                if isMissing {
                                    var missingMaterial = SimpleMaterial(color: UIColor.gray.withAlphaComponent(0.3), isMetallic: false)
                                    missingMaterial.roughness = .float(0.5)
                                    toothEntity.model?.materials = [missingMaterial]
                                } else {
                                    if let painEntry = painEntries[toothNumber] {
                                        let painColor = colorForPainLevel(painEntry.painLevel)
                                        var painMaterial = SimpleMaterial(color: painColor, isMetallic: false)
                                        painMaterial.roughness = .float(0.3)
                                        painMaterial.metallic = .float(0.1)
                                        toothEntity.model?.materials = [painMaterial]
                                    } else {
                                        toothEntity.model?.materials = [createToothMaterial(isHealthy: true)]
                                    }
                                }
                            }
                        }
                    }
                }
            }

            lastPainEntries = painEntries
            lastToothStatuses = toothStatuses
        }
        .simultaneousGesture(
            SpatialTapGesture()
                .targetedToAnyEntity()
                .onEnded { value in
                    handleEntityTap(value.entity)
                }
        )
        .gesture(
            SimultaneousGesture(
                DragGesture()
                    .onChanged { value in
                        
                        let rotationDeltaY = Float(value.translation.width * 0.005)
                        currentRotationY = lastRotationY + rotationDeltaY

                        
                        let rotationDeltaX = Float(value.translation.height * 0.005)
                        currentRotationX = lastRotationX + rotationDeltaX

                        
                        currentRotationX = max(-Float.pi * 0.4, min(Float.pi * 0.4, currentRotationX))

                        
                        
                        let xRotation = simd_quatf(angle: currentRotationX, axis: SIMD3<Float>(1, 0, 0))
                        let yRotation = simd_quatf(angle: currentRotationY, axis: SIMD3<Float>(0, 1, 0))
                        mouthAnchor?.orientation = xRotation * yRotation
                    }
                    .onEnded { _ in
                        lastRotationY = currentRotationY
                        lastRotationX = currentRotationX
                    },
                MagnificationGesture()
                    .onChanged { value in
                        let newScale = max(0.5, min(15.0, baseScale * Float(value)))
                        currentScale = newScale
                        mouthAnchor?.scale = SIMD3<Float>(repeating: currentScale)
                    }
                    .onEnded { value in
                        baseScale = max(0.5, min(15.0, baseScale * Float(value)))
                        currentScale = baseScale
                    }
            )
        )
    }

    private func handleEntityTap(_ entity: Entity) {
        var currentEntity: Entity? = entity

        while let checkEntity = currentEntity {
            let toothName = checkEntity.name
            if toothName.hasPrefix("tooth_") {
                let numberString = toothName.replacingOccurrences(of: "tooth_", with: "")
                if let toothNumber = Int(numberString) {
                    selectedTooth = toothNumber
                    onToothTapped(toothNumber)
                    return
                }
            }
            currentEntity = checkEntity.parent
        }

        print("⚠️ Tapped entity '\(entity.name)' but couldn't find tooth number")
    }

    private func createRealisticTeethEntities(anchor: AnchorEntity) {
        let positions = generateToothPositions()

        for (toothNumber, position) in positions.enumerated() {
            let actualToothNumber = toothNumber + 1

            let toothEntity = createRealisticTooth(toothNumber: actualToothNumber, position: position)
            anchor.addChild(toothEntity)
        }
    }
    
    private func createRealisticTooth(toothNumber: Int, position: SIMD3<Float>) -> ModelEntity {

        if let cachedEntity = meshCache.getToothEntity(toothNumber: toothNumber) {
            let toothEntity = cachedEntity

            print("🦷 Creating tooth #\(toothNumber) at position: \(position)")


            let material: SimpleMaterial
            if let painEntry = painEntries[toothNumber] {
                let painColor = colorForPainLevel(painEntry.painLevel)
                var painMaterial = SimpleMaterial(color: painColor, isMetallic: false)
                painMaterial.roughness = .float(0.3)
                painMaterial.metallic = .float(0.1)
                material = painMaterial
            } else {
                material = createToothMaterial(isHealthy: true)
            }


            applyMaterialRecursively(to: toothEntity, material: material)


            toothEntity.scale = SIMD3<Float>(1.0, 1.0, 1.0)


            toothEntity.position = position
            toothEntity.name = "tooth_\(toothNumber)"
            toothEntity.orientation = getToothOrientation(toothNumber: toothNumber)


            setNameRecursively(entity: toothEntity, name: "tooth_\(toothNumber)")


            let bounds = toothEntity.visualBounds(relativeTo: nil)
            print("  📏 Tooth #\(toothNumber) bounds: \(bounds.extents)")
            print("  📍 Tooth #\(toothNumber) center: \(bounds.center)")
            print("  🎯 Tooth #\(toothNumber) position: \(position)")


            let collisionShape = ShapeResource.generateBox(size: bounds.extents)
            toothEntity.components.set(CollisionComponent(shapes: [collisionShape]))
            toothEntity.components.set(InputTargetComponent())

            return toothEntity
        } else {

            print("⚠️ USDZ model not found for tooth #\(toothNumber), using fallback mesh")
            return createFallbackTooth(toothNumber: toothNumber, position: position)
        }
    }

    private func setNameRecursively(entity: Entity, name: String) {
        entity.name = name
        for child in entity.children {
            setNameRecursively(entity: child, name: name)
        }
    }

    private func applyMaterialRecursively(to entity: Entity, material: SimpleMaterial) {
        
        if var model = entity.components[ModelComponent.self] {
            model.materials = [material]
            entity.components[ModelComponent.self] = model
        }

        
        for child in entity.children {
            applyMaterialRecursively(to: child, material: material)
        }
    }

    private func createFallbackTooth(toothNumber: Int, position: SIMD3<Float>) -> ModelEntity {
        let toothType = getToothType(toothNumber: toothNumber)
        let mesh = generateToothMesh(type: toothType)
        let toothEntity = ModelEntity(mesh: mesh, materials: [])

        let material: SimpleMaterial
        if let painEntry = painEntries[toothNumber] {
            let painColor = colorForPainLevel(painEntry.painLevel)
            var painMaterial = SimpleMaterial(color: painColor, isMetallic: false)
            painMaterial.roughness = .float(0.3)
            painMaterial.metallic = .float(0.1)
            material = painMaterial
        } else {
            material = createToothMaterial(isHealthy: true)
        }

        toothEntity.model?.materials = [material]
        toothEntity.position = position
        toothEntity.name = "tooth_\(toothNumber)"
        toothEntity.orientation = getToothOrientation(toothNumber: toothNumber)

        let bounds = toothEntity.visualBounds(relativeTo: nil)
        let collisionShape = ShapeResource.generateBox(size: bounds.extents)
        toothEntity.components.set(CollisionComponent(shapes: [collisionShape]))
        toothEntity.components.set(InputTargetComponent())

        return toothEntity
    }
    
    private func generateToothMesh(type: ToothType) -> MeshResource {
        switch type {
        case .incisor:
            
            return .generateBox(size: SIMD3<Float>(0.008, 0.025, 0.006))
        case .canine:
            
            return createCanineMesh()
        case .premolar:
            
            return .generateBox(size: SIMD3<Float>(0.012, 0.020, 0.010))
        case .molar:
            
            return createMolarMesh()
        }
    }
    
    private func createCanineMesh() -> MeshResource {
        
        var descriptor = MeshDescriptor()

        let vertices: [SIMD3<Float>] = [
            
            SIMD3<Float>(-0.006, -0.012, -0.006), 
            SIMD3<Float>( 0.006, -0.012, -0.006), 
            SIMD3<Float>( 0.006, -0.012,  0.006), 
            SIMD3<Float>(-0.006, -0.012,  0.006), 
            
            SIMD3<Float>( 0.000,  0.015,  0.000), 
        ]

        let triangles: [UInt32] = [
            
            0, 2, 1, 0, 3, 2,
            
            0, 1, 4,
            1, 2, 4,
            2, 3, 4,
            3, 0, 4
        ]

        descriptor.positions = MeshBuffers.Positions(vertices)
        descriptor.primitives = .triangles(triangles)

        return try! MeshResource.generate(from: [descriptor])
    }
    
    private func createMolarMesh() -> MeshResource {
        
        var descriptor = MeshDescriptor()

        let vertices: [SIMD3<Float>] = [
            
            SIMD3<Float>(-0.008, -0.010, -0.008), 
            SIMD3<Float>( 0.008, -0.010, -0.008), 
            SIMD3<Float>( 0.008, -0.010,  0.008), 
            SIMD3<Float>(-0.008, -0.010,  0.008), 
            
            SIMD3<Float>(-0.004,  0.012, -0.004), 
            SIMD3<Float>( 0.004,  0.012, -0.004), 
            SIMD3<Float>( 0.004,  0.012,  0.004), 
            SIMD3<Float>(-0.004,  0.012,  0.004), 
        ]

        let triangles: [UInt32] = [
            
            0, 2, 1, 0, 3, 2,
            
            4, 5, 6, 4, 6, 7,
            
            0, 1, 5, 0, 5, 4,
            1, 2, 6, 1, 6, 5,
            2, 3, 7, 2, 7, 6,
            3, 0, 4, 3, 4, 7
        ]

        descriptor.positions = MeshBuffers.Positions(vertices)
        descriptor.primitives = .triangles(triangles)

        return try! MeshResource.generate(from: [descriptor])
    }
    
    private func createJawStructure(anchor: AnchorEntity) {
        
        let upperGum = ModelEntity(
            mesh: .generateBox(size: SIMD3<Float>(0.20, 0.008, 0.16)),
            materials: [SimpleMaterial(color: UIColor.systemPink.withAlphaComponent(0.8), isMetallic: false)]
        )
        upperGum.position = SIMD3<Float>(0, 0.015, 0)
        upperGum.name = "upper_gum"
        anchor.addChild(upperGum)
        
        
        let lowerGum = ModelEntity(
            mesh: .generateBox(size: SIMD3<Float>(0.18, 0.008, 0.14)),
            materials: [SimpleMaterial(color: UIColor.systemPink.withAlphaComponent(0.8), isMetallic: false)]
        )
        lowerGum.position = SIMD3<Float>(0, -0.025, 0)
        lowerGum.name = "lower_gum"
        anchor.addChild(lowerGum)
    }
    
    private func createToothMaterial(isHealthy: Bool) -> SimpleMaterial {
        let baseColor: UIColor = isHealthy ? .white : .systemYellow.withAlphaComponent(0.9)
        var material = SimpleMaterial(color: baseColor, isMetallic: false)
        material.roughness = .float(0.3) 
        return material
    }
    
    private func generateToothPositions() -> [SIMD3<Float>] {
        var positions: [SIMD3<Float>] = []

        
        
        let jawSeparation: Float = 0.002  

        
        let upperY: Float = jawSeparation / 2.0  

        for i in 0..<16 {
            let normalizedPosition = Float(i) / 15.0  
            let angle = (normalizedPosition - 0.5) * 1.8  
            let radius: Float = 0.09  

            let x = sin(angle) * radius
            let z = cos(angle) * radius

            positions.append(SIMD3<Float>(x, upperY, z))
        }

        
        let lowerY: Float = -jawSeparation / 2.0 - 0.008  
        let lowerJawOffset: Float = -0.003  

        for i in 0..<16 {
            let normalizedPosition = Float(i) / 15.0
            let angle = (normalizedPosition - 0.5) * 1.8  
            let radius: Float = 0.09  

            let x = sin(angle) * radius
            let z = cos(angle) * radius + lowerJawOffset

            positions.append(SIMD3<Float>(x, lowerY, z))
        }

        return positions
    }
    
    
    
    private func getToothType(toothNumber: Int) -> ToothType {
        
        let adjustedNumber = ((toothNumber - 1) % 16) + 1
        
        switch adjustedNumber {
        case 1, 2:
            return .incisor 
        case 3:
            return .canine
        case 4, 5:
            return .premolar 
        case 6, 7, 8:
            return .molar 
        default:
            return .incisor
        }
    }
    
    private func getToothOrientation(toothNumber: Int) -> simd_quatf {
        
        let positions = generateToothPositions()
        let position = positions[min(toothNumber - 1, positions.count - 1)]

        
        let angle = atan2(position.x, position.z)

        
        let yRotation = simd_quatf(angle: angle, axis: SIMD3<Float>(0, 1, 0))

        
        let isUpperJaw = toothNumber <= 16

        if isUpperJaw {
            
            let verticalRotation = simd_quatf(angle: Float.pi / 2, axis: SIMD3<Float>(1, 0, 0))
            let tiltRotation = simd_quatf(angle: 0.15, axis: SIMD3<Float>(1, 0, 0))
            return yRotation * verticalRotation * tiltRotation
        } else {
            
            let verticalRotation = simd_quatf(angle: -Float.pi / 2, axis: SIMD3<Float>(1, 0, 0))
            let tiltRotation = simd_quatf(angle: 0.15, axis: SIMD3<Float>(1, 0, 0))  
            return yRotation * verticalRotation * tiltRotation
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
    
}


struct ToothDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let toothNumber: Int
    @State private var painEntry: PainEntry
    @State private var toothStatus: ToothStatus
    let onSave: (PainEntry) -> Void
    let onStatusUpdate: (ToothStatus) -> Void

    init(toothNumber: Int, painEntry: PainEntry?, toothStatus: ToothStatus?, onSave: @escaping (PainEntry) -> Void, onStatusUpdate: @escaping (ToothStatus) -> Void) {
        self.toothNumber = toothNumber
        self._painEntry = State(initialValue: painEntry ?? PainEntry(toothNumber: toothNumber, painLevel: 0))
        self._toothStatus = State(initialValue: toothStatus ?? ToothStatus(toothNumber: toothNumber))
        self.onSave = onSave
        self.onStatusUpdate = onStatusUpdate
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    
                    Text("Tooth #\(toothNumber)")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    
                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Tooth Condition")
                                .font(.headline)

                            Picker("Condition", selection: $toothStatus.condition) {
                                ForEach(ToothCondition.allCases, id: \.self) { condition in
                                    Text(condition.displayName).tag(condition)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                    }

                    
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

                    Button("Update") {
                        
                        var updatedEntry = painEntry
                        updatedEntry.toothNumber = toothNumber
                        updatedEntry.timestamp = Date()

                        var updatedStatus = toothStatus
                        print("DEBUG ToothDetailSheet: Before update - toothStatus.toothNumber: \(toothStatus.toothNumber), toothNumber: \(toothNumber)")
                        updatedStatus.toothNumber = toothNumber
                        updatedStatus.lastUpdated = Date()
                        updatedStatus.currentPainLevel = painEntry.painLevel
                        print("DEBUG ToothDetailSheet: After update - updatedStatus.toothNumber: \(updatedStatus.toothNumber), condition: \(updatedStatus.condition.rawValue)")

                        onSave(updatedEntry)
                        onStatusUpdate(updatedStatus)
                        dismiss()
                    }
                    .liquidGlassButton(style: .accent)
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
                .padding()
            }
            .onTapGesture {
                hideKeyboard()
            }
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

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
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
