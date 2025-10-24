//
//  PhotoStorageService.swift
//  BrightBite
//
//  Created by Tuan Nguyen on 10/7/25.
//

import Foundation
import UIKit

import Combine


class PhotoStorageService: ObservableObject {
    static let shared = PhotoStorageService()
    
    
    
    
    
    private let documentsDirectory: URL
    
    private init() {
        print("DEBUG: PhotoStorageService initialization starting...")
        
        guard let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("ERROR: Could not access documents directory")
            fatalError("Documents directory not accessible")
        }
        
        self.documentsDirectory = documentsDir
        print("DEBUG: PhotoStorageService initialized - local storage only at: \(documentsDir.path)")
    }
    
    
    
    
    func saveChewCheckPhoto(_ image: UIImage, userId: String) throws -> URL {
        let filename = "chewcheck_\(userId)_\(Date().timeIntervalSince1970).jpg"
        let url = documentsDirectory.appendingPathComponent("chewcheck").appendingPathComponent(filename)
        
        
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), 
                                              withIntermediateDirectories: true)
        
        
        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            throw StorageError.imageCompressionFailed
        }
        
        try imageData.write(to: url)
        
        
        scheduleCleanup(for: url, afterDays: 7)
        
        return url
    }
    
    
    func savePersistentPhoto(_ image: UIImage, userId: String, type: PhotoType) async throws -> String {
        let filename = "\(type.rawValue)_\(userId)_\(Date().timeIntervalSince1970).jpg"
        let localURL = documentsDirectory.appendingPathComponent("persistent").appendingPathComponent(filename)
        
        
        try FileManager.default.createDirectory(at: localURL.deletingLastPathComponent(), 
                                              withIntermediateDirectories: true)
        
        
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw StorageError.imageCompressionFailed
        }
        
        try imageData.write(to: localURL)
        print("DEBUG: Saved photo locally: \(filename)")
        
        return filename
    }
    
    
    func loadPhoto(filename: String, type: PhotoType) async -> UIImage? {
        let localURL = documentsDirectory.appendingPathComponent("persistent").appendingPathComponent(filename)
        
        
        if let localImage = UIImage(contentsOfFile: localURL.path) {
            print("DEBUG: Loaded photo from local storage: \(filename)")
            return localImage
        }
        
        print("DEBUG: Photo not found locally: \(filename)")
        return nil
    }
    
    
    
    private func scheduleCleanup(for url: URL, afterDays days: Int) {
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + .seconds(days * 24 * 60 * 60)) {
            try? FileManager.default.removeItem(at: url)
            print("DEBUG: Cleaned up old photo: \(url.lastPathComponent)")
        }
    }
    
    
    func cleanupOldChewCheckPhotos() {
        let chewCheckDir = documentsDirectory.appendingPathComponent("chewcheck")
        
        do {
            let files = try FileManager.default.contentsOfDirectory(at: chewCheckDir, 
                                                                   includingPropertiesForKeys: [.creationDateKey])
            let oneWeekAgo = Date().addingTimeInterval(-7 * 24 * 60 * 60)
            
            for file in files {
                if let creationDate = try file.resourceValues(forKeys: [.creationDateKey]).creationDate,
                   creationDate < oneWeekAgo {
                    try FileManager.default.removeItem(at: file)
                    print("DEBUG: Cleaned up old ChewCheck photo: \(file.lastPathComponent)")
                }
            }
        } catch {
            print("Error cleaning up photos: \(error)")
        }
    }
    
    
    func getStorageUsage() -> (localSizeMB: Double, fileCount: Int) {
        do {
            let files = try FileManager.default.contentsOfDirectory(at: documentsDirectory, 
                                                                   includingPropertiesForKeys: [.fileSizeKey],
                                                                   options: .skipsHiddenFiles)
            
            let totalBytes = files.compactMap { url in
                try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize
            }.reduce(0, +)
            
            return (Double(totalBytes) / 1_000_000, files.count)
            
        } catch {
            return (0, 0)
        }
    }
    
    
    
    


    
    
    func saveProfilePhoto(_ image: UIImage, userId: String) async throws -> String {
        let filename = "profile_\(userId)_latest.jpg"
        let localURL = documentsDirectory.appendingPathComponent("persistent").appendingPathComponent(filename)
        
        
        try FileManager.default.createDirectory(at: localURL.deletingLastPathComponent(), 
                                              withIntermediateDirectories: true)
        
        
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw StorageError.imageCompressionFailed
        }
        
        try imageData.write(to: localURL)
        
        
        print("DEBUG: Saved profile photo locally: \(filename)")
        
        return filename
    }
    
    
    func loadProfilePhoto(userId: String) async -> UIImage? {
        let filename = "profile_\(userId)_latest.jpg"
        return await loadPhoto(filename: filename, type: .profile)
    }
}


enum PhotoType: String, CaseIterable {
    case profile = "profile"
    case dentistNote = "dentist_note"
    case chewCheck = "chewcheck"
    case painPhoto = "pain_photo"
}

enum StorageError: Error, LocalizedError {
    case imageCompressionFailed
    case cloudKitUnavailable
    case fileNotFound
    
    var errorDescription: String? {
        switch self {
        case .imageCompressionFailed:
            return "Failed to compress image for storage"
        case .cloudKitUnavailable:
            return "iCloud is not available for backup"
        case .fileNotFound:
            return "Photo file not found"
        }
    }
}
