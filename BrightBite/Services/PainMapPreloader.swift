//
//  PainMapPreloader.swift
//  BrightBite
//
//  Created by Tuan Nguyen on 10/1/25.
//

import Foundation
import RealityKit
import Combine


class PainMapPreloader: ObservableObject {
    static let shared = PainMapPreloader()
    
    @Published var isPreloaded = false
    @Published var preloadProgress: Double = 0.0
    
    private var preloadedToothMeshes: [ToothType: MeshResource] = [:]
    private var preloadedToothModels: [ToothType: ModelEntity] = [:]
    
    private init() {}
    
    
    func preloadPainMapAssets() async {
        print("DEBUG: PainMapPreloader starting asset preload...")
        await MainActor.run {
            preloadProgress = 0.0
        }
        
        
        await preloadToothMeshes()
        await MainActor.run { preloadProgress = 0.25 }
        
        
        await preload3DModels()
        await MainActor.run { preloadProgress = 0.50 }
        
        
        await preloadMaterials()
        await MainActor.run { preloadProgress = 0.75 }
        
        
        await preloadPositionData()
        await MainActor.run { 
            preloadProgress = 1.0
            isPreloaded = true
        }
    }
    
    private func preloadToothMeshes() async {
        
        for toothType in [ToothType.incisor, .canine, .premolar, .molar] {
            let mesh = generateToothMesh(type: toothType)
            preloadedToothMeshes[toothType] = mesh
        }
    }
    
    private func preload3DModels() async {
        
        for toothType in [ToothType.incisor, .canine, .premolar, .molar] {
            if let model = await loadReal3DToothModel(type: toothType) {
                preloadedToothModels[toothType] = model
            }
        }
    }
    
    private func preloadMaterials() async {
        
        
    }
    
    private func preloadPositionData() async {
        
        _ = generateToothPositions()
    }
    
    
    
    func getPreloadedMesh(for type: ToothType) -> MeshResource? {
        return preloadedToothMeshes[type]
    }
    
    func getPreloaded3DModel(for type: ToothType) -> ModelEntity? {
        return preloadedToothModels[type]?.clone(recursive: true)
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
            
            0, 1, 2, 0, 2, 3,
            
            0, 4, 1, 1, 4, 2, 2, 4, 3, 3, 4, 0
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
            
            0, 1, 2, 0, 2, 3,
            
            4, 6, 5, 4, 7, 6,
            
            0, 4, 1, 1, 4, 5,
            1, 5, 2, 2, 5, 6,
            2, 6, 3, 3, 6, 7,
            3, 7, 0, 0, 7, 4
        ]
        
        descriptor.positions = MeshBuffers.Positions(vertices)
        descriptor.primitives = .triangles(triangles)
        
        return try! MeshResource.generate(from: [descriptor])
    }
    
    private func loadReal3DToothModel(type: ToothType) async -> ModelEntity? {
        
        let modelName: String
        switch type {
        case .incisor:
            modelName = "Tooth_Incisor"
        case .canine:
            modelName = "Tooth_Canine"
        case .premolar:
            modelName = "Tooth_Premolar"
        case .molar:
            modelName = "Tooth_Molar"
        }
        
        
        
        
        return nil
    }
    
    private func generateToothPositions() -> [SIMD3<Float>] {
        var positions: [SIMD3<Float>] = []
        
        
        for i in 0..<16 {
            let angle = Float(i) * 0.2 - 1.5
            let x = sin(angle) * 0.08
            let z = cos(angle) * 0.08
            positions.append(SIMD3<Float>(x, 0.02, z))
        }
        
        
        for i in 0..<16 {
            let angle = Float(i) * 0.2 - 1.5
            let x = sin(angle) * 0.08
            let z = cos(angle) * 0.08
            positions.append(SIMD3<Float>(x, -0.02, z))
        }
        
        return positions
    }
}

