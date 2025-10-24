//
//  ToothOffsetCalculator.swift
//  BrightBite
//
//  Created by Tuan Nguyen on 10/10/25.
//

import Foundation
import RealityKit

class ToothOffsetCalculator {
    static func calculateAndSaveOffsets() async {
        print("🔧 Calculating tooth center offsets...")

        var offsets: [Int: SIMD3<Float>] = [:]

        
        for toothNumber in 1...32 {
            if let url = Bundle.main.url(forResource: "\(toothNumber)", withExtension: "usdz") {
                do {
                    let entity = try await ModelEntity(contentsOf: url)
                    let bounds = entity.visualBounds(relativeTo: nil)
                    let centerOffset = bounds.center

                    offsets[toothNumber] = centerOffset
                    print("Tooth \(toothNumber): offset = \(centerOffset)")
                } catch {
                    print("Error loading tooth \(toothNumber): \(error)")
                }
            }
        }

        
        saveOffsetsAsCode(offsets)
    }

    static func saveOffsetsAsCode(_ offsets: [Int: SIMD3<Float>]) {
        print("\n// Generated tooth offsets - paste this into PainMapView.swift:")
        print("private func getToothCenterOffset(toothNumber: Int) -> SIMD3<Float> {")
        print("    switch toothNumber {")
        for tooth in 1...32 {
            if let offset = offsets[tooth] {
                print("    case \(tooth): return SIMD3<Float>(\(offset.x), \(offset.y), \(offset.z))")
            }
        }
        print("    default: return SIMD3<Float>(0, 0, 0)")
        print("    }")
        print("}")
    }
}
