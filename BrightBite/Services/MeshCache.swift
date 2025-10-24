//
//  MeshCache.swift
//  BrightBite
//
//  Created by Tuan Nguyen on 10/1/25.
//

import RealityKit
import Foundation
import Combine

class MeshCache: ObservableObject {
    static let shared = MeshCache()

    @Published var isPreloaded = false
    private var cachedEntities: [Int: ModelEntity] = [:]

    private init() {}

    func preloadAllTeeth() async {
        print("🦷 Starting USDZ tooth model preloading...")

        await withTaskGroup(of: (Int, ModelEntity?).self) { group in
            
            for toothNumber in 1...32 {
                group.addTask {
                    let entity = await self.loadToothModel(toothNumber: toothNumber)
                    return (toothNumber, entity)
                }
            }

            for await (toothNumber, entity) in group {
                if let entity = entity {
                    await MainActor.run {
                        self.cachedEntities[toothNumber] = entity
                    }
                }
            }
        }

        await MainActor.run {
            self.isPreloaded = true
        }

        print("✅ Preloaded \(cachedEntities.count) USDZ tooth models")
    }

    func getToothEntity(toothNumber: Int) -> ModelEntity? {
        return cachedEntities[toothNumber]?.clone(recursive: true)
    }

    private func loadToothModel(toothNumber: Int) async -> ModelEntity? {
        
        let jawType = toothNumber <= 16 ? "top" : "bottom"
        let filename = "\(toothNumber)"

        
        if toothNumber == 1 {
            print("🔍 Debugging: Searching for USDZ files in bundle...")
            if let resourcePath = Bundle.main.resourcePath {
                print("📦 Bundle resource path: \(resourcePath)")

                
                let teethPath = (resourcePath as NSString).appendingPathComponent("Teeth")
                let fileManager = FileManager.default
                if fileManager.fileExists(atPath: teethPath) {
                    print("✅ Teeth folder found at: \(teethPath)")
                } else {
                    print("❌ Teeth folder NOT found in bundle")
                    print("🔍 Listing all directories in bundle:")
                    if let contents = try? fileManager.contentsOfDirectory(atPath: resourcePath) {
                        for item in contents.prefix(10) {
                            print("  - \(item)")
                        }
                    }
                }
            }

            
            let allUSDZ = Bundle.main.paths(forResourcesOfType: "usdz", inDirectory: nil)
            print("📁 Total USDZ files in bundle: \(allUSDZ.count)")
            for path in allUSDZ.prefix(5) {
                print("  - \(path)")
            }
        }

        do {
            
            if let url = Bundle.main.url(forResource: filename, withExtension: "usdz") {
                let entity = try await ModelEntity(contentsOf: url)
                print("✅ Loaded tooth #\(toothNumber) (jaw: \(jawType))")
                return entity
            }

            print("❌ Could not find USDZ for tooth #\(toothNumber)")
            return nil

        } catch {
            print("❌ Error loading tooth #\(toothNumber): \(error)")
            return nil
        }
    }
}
