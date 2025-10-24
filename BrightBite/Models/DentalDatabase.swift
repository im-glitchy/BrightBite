//
//  DentalDatabase.swift
//  BrightBite
//
//  Created by Tuan Nguyen on 9/12/25.
//

import Foundation


struct DentalProcedureInfo: Codable {
    let name: String
    let category: ProcedureCategory
    let typicalDuration: String
    let commonReasons: [String]
    let postOpCare: [String]
    let dietRestrictions: [String]
    let painLevel: String 
    let recoveryTime: String
    let followUpNeeded: Bool
    let commonMedications: [String]
}

enum ProcedureCategory: String, Codable {
    case preventive = "Preventive"
    case restorative = "Restorative"
    case cosmetic = "Cosmetic"
    case orthodontic = "Orthodontic"
    case surgical = "Surgical"
    case endodontic = "Endodontic"
    case periodontic = "Periodontic"
}

class DentalDatabase {
    static let shared = DentalDatabase()

    private init() {}

    

    let procedures: [String: DentalProcedureInfo] = [
        "cleaning": DentalProcedureInfo(
            name: "Dental Cleaning (Prophylaxis)",
            category: .preventive,
            typicalDuration: "30-60 minutes",
            commonReasons: ["Routine maintenance", "Plaque removal", "Tartar removal"],
            postOpCare: ["Brush twice daily", "Floss daily", "Use mouthwash"],
            dietRestrictions: [],
            painLevel: "Minimal",
            recoveryTime: "Immediate",
            followUpNeeded: false,
            commonMedications: []
        ),

        "filling": DentalProcedureInfo(
            name: "Dental Filling",
            category: .restorative,
            typicalDuration: "30-60 minutes per tooth",
            commonReasons: ["Cavity", "Tooth decay", "Damaged tooth"],
            postOpCare: ["Avoid hard foods for 24 hours", "May have sensitivity"],
            dietRestrictions: ["Avoid very hot/cold foods for 24-48 hours", "Soft foods recommended"],
            painLevel: "Minimal to Moderate",
            recoveryTime: "24-48 hours",
            followUpNeeded: false,
            commonMedications: ["Ibuprofen", "Acetaminophen"]
        ),

        "crown": DentalProcedureInfo(
            name: "Dental Crown",
            category: .restorative,
            typicalDuration: "2 appointments, 1-2 hours each",
            commonReasons: ["Damaged tooth", "Root canal protection", "Cosmetic improvement"],
            postOpCare: ["Avoid sticky foods", "Gentle brushing around crown", "Use temporary crown carefully"],
            dietRestrictions: ["Avoid hard foods", "No sticky candy", "Soft foods for first few days"],
            painLevel: "Moderate",
            recoveryTime: "3-5 days",
            followUpNeeded: true,
            commonMedications: ["Ibuprofen", "Acetaminophen"]
        ),

        "extraction": DentalProcedureInfo(
            name: "Tooth Extraction",
            category: .surgical,
            typicalDuration: "30-60 minutes",
            commonReasons: ["Severe decay", "Infection", "Crowding", "Impacted wisdom tooth"],
            postOpCare: ["Bite on gauze", "Ice packs", "No smoking", "No straws", "Salt water rinse after 24 hours"],
            dietRestrictions: ["Soft foods only for 3-7 days", "No hot liquids for 24 hours", "Avoid spicy/acidic foods"],
            painLevel: "Moderate to Significant",
            recoveryTime: "7-10 days",
            followUpNeeded: true,
            commonMedications: ["Ibuprofen", "Acetaminophen with Codeine", "Amoxicillin (antibiotic)"]
        ),

        "rootCanal": DentalProcedureInfo(
            name: "Root Canal",
            category: .endodontic,
            typicalDuration: "1-2 hours, may require 2 visits",
            commonReasons: ["Infected tooth pulp", "Deep cavity", "Cracked tooth"],
            postOpCare: ["Avoid chewing on treated tooth until permanent restoration", "Take prescribed medications"],
            dietRestrictions: ["Soft foods for 2-3 days", "Avoid hard/crunchy foods"],
            painLevel: "Moderate",
            recoveryTime: "3-5 days",
            followUpNeeded: true,
            commonMedications: ["Ibuprofen", "Acetaminophen", "Amoxicillin (if infection present)"]
        ),

        "implant": DentalProcedureInfo(
            name: "Dental Implant",
            category: .surgical,
            typicalDuration: "Multiple visits over 3-6 months",
            commonReasons: ["Missing tooth replacement", "Permanent solution for tooth loss"],
            postOpCare: ["Ice packs for swelling", "Gentle brushing", "No smoking", "Salt water rinses"],
            dietRestrictions: ["Soft foods for 1-2 weeks", "No hard/crunchy foods until healed"],
            painLevel: "Moderate to Significant",
            recoveryTime: "3-6 months for full healing",
            followUpNeeded: true,
            commonMedications: ["Ibuprofen", "Acetaminophen with Codeine", "Amoxicillin", "Chlorhexidine mouthwash"]
        ),

        "braces": DentalProcedureInfo(
            name: "Braces Installation",
            category: .orthodontic,
            typicalDuration: "1-2 hours installation, 12-36 months treatment",
            commonReasons: ["Crooked teeth", "Bite correction", "Spacing issues"],
            postOpCare: ["Brush after every meal", "Use orthodontic wax for irritation", "Regular adjustments"],
            dietRestrictions: ["No hard foods", "No sticky candy", "No popcorn", "No ice", "Cut food into small pieces"],
            painLevel: "Moderate (especially after adjustments)",
            recoveryTime: "3-5 days per adjustment",
            followUpNeeded: true,
            commonMedications: ["Ibuprofen", "Orthodontic wax"]
        ),

        "invisalign": DentalProcedureInfo(
            name: "Invisalign/Clear Aligners",
            category: .orthodontic,
            typicalDuration: "12-18 months typical treatment",
            commonReasons: ["Mild to moderate alignment issues", "Cosmetic preference for clear braces"],
            postOpCare: ["Wear 20-22 hours per day", "Remove for eating/drinking", "Clean aligners daily"],
            dietRestrictions: ["Remove aligners before eating", "No restrictions when aligners removed"],
            painLevel: "Minimal to Moderate",
            recoveryTime: "2-3 days per new aligner",
            followUpNeeded: true,
            commonMedications: ["Ibuprofen"]
        ),

        "whitening": DentalProcedureInfo(
            name: "Teeth Whitening",
            category: .cosmetic,
            typicalDuration: "1 hour in-office, or 2 weeks at home",
            commonReasons: ["Tooth discoloration", "Cosmetic improvement"],
            postOpCare: ["Avoid staining foods/drinks for 48 hours", "Use sensitivity toothpaste if needed"],
            dietRestrictions: ["Avoid coffee, tea, red wine for 48 hours", "No dark-colored foods"],
            painLevel: "Minimal (may have sensitivity)",
            recoveryTime: "Immediate",
            followUpNeeded: false,
            commonMedications: ["Sensitivity toothpaste"]
        ),

        "deepCleaning": DentalProcedureInfo(
            name: "Deep Cleaning (Scaling & Root Planing)",
            category: .periodontic,
            typicalDuration: "1-2 hours, may require multiple visits",
            commonReasons: ["Gum disease", "Periodontal pockets", "Heavy tartar buildup"],
            postOpCare: ["Gentle brushing", "Warm salt water rinses", "Avoid irritating area"],
            dietRestrictions: ["Soft foods for 24 hours", "Avoid spicy/acidic foods"],
            painLevel: "Moderate",
            recoveryTime: "3-7 days",
            followUpNeeded: true,
            commonMedications: ["Ibuprofen", "Chlorhexidine mouthwash"]
        ),

        "veneer": DentalProcedureInfo(
            name: "Dental Veneers",
            category: .cosmetic,
            typicalDuration: "2 appointments, 1-2 hours each",
            commonReasons: ["Cosmetic improvement", "Discolored teeth", "Chipped teeth", "Gap closure"],
            postOpCare: ["Avoid biting hard objects", "Good oral hygiene", "Regular dental visits"],
            dietRestrictions: ["Avoid very hard foods", "No ice chewing", "Limit staining foods"],
            painLevel: "Minimal",
            recoveryTime: "Immediate",
            followUpNeeded: true,
            commonMedications: []
        ),

        "bonding": DentalProcedureInfo(
            name: "Dental Bonding",
            category: .cosmetic,
            typicalDuration: "30-60 minutes per tooth",
            commonReasons: ["Chipped tooth repair", "Gap closure", "Tooth reshaping"],
            postOpCare: ["Avoid hard foods for 24 hours", "Normal brushing/flossing"],
            dietRestrictions: ["Avoid staining foods for 48 hours"],
            painLevel: "Minimal",
            recoveryTime: "Immediate",
            followUpNeeded: false,
            commonMedications: []
        )
    ]

    

    let dietRestrictionTemplates: [String: [String]] = [
        "softOnly": ["Soft foods", "Mashed potatoes", "Yogurt", "Smoothies", "Soup", "Scrambled eggs"],
        "noHard": ["No nuts", "No hard candy", "No ice", "No hard bread/crackers", "No raw vegetables"],
        "noSticky": ["No caramel", "No taffy", "No gum", "No sticky candy", "No dried fruit"],
        "noChewy": ["No tough meats", "No bagels", "No chewy candy"],
        "noHot": ["No hot beverages", "No hot foods", "Room temperature only"],
        "noCold": ["No ice cream", "No cold drinks", "Warm or room temperature only"],
        "noAcidic": ["No citrus fruits", "No tomato sauce", "No vinegar", "No soda"],
        "noSugary": ["No candy", "No soda", "No desserts", "Limit sugar intake"]
    ]

    

    let medicationTemplates: [String: (dosage: String, frequency: String, instructions: String)] = [
        "Ibuprofen": (
            dosage: "400mg",
            frequency: "Every 6 hours as needed",
            instructions: "Take with food to avoid stomach upset"
        ),
        "Acetaminophen": (
            dosage: "500mg",
            frequency: "Every 6 hours as needed",
            instructions: "Do not exceed 4000mg per day"
        ),
        "Amoxicillin": (
            dosage: "500mg",
            frequency: "3 times daily",
            instructions: "Complete full course even if feeling better"
        ),
        "Acetaminophen with Codeine": (
            dosage: "300mg/30mg",
            frequency: "Every 4-6 hours as needed",
            instructions: "May cause drowsiness. Do not drive or operate machinery"
        ),
        "Chlorhexidine": (
            dosage: "0.12% solution",
            frequency: "Rinse twice daily",
            instructions: "Do not swallow. May cause temporary staining of teeth"
        )
    ]

    

    func getProcedureInfo(for procedureType: String) -> DentalProcedureInfo? {
        return procedures[procedureType.lowercased()]
    }

    func generatePromptContext() -> String {
        var context = "DENTAL PROCEDURES DATABASE:\n\n"

        for (key, info) in procedures.sorted(by: { $0.key < $1.key }) {
            context += "- \(info.name) (\(key)):\n"
            context += "  Category: \(info.category.rawValue)\n"
            context += "  Duration: \(info.typicalDuration)\n"
            context += "  Recovery: \(info.recoveryTime)\n"
            context += "  Diet Restrictions: \(info.dietRestrictions.joined(separator: ", "))\n"
            context += "  Common Medications: \(info.commonMedications.joined(separator: ", "))\n\n"
        }

        return context
    }
}
