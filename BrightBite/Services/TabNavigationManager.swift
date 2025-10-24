//
//  TabNavigationManager.swift
//  BrightBite
//
//  Created by Tuan Nguyen on 8/25/25.
//

import SwiftUI
import Foundation
import Combine

class TabNavigationManager: ObservableObject {
    @Published var selectedTab: Int = 0
    @Published var selectedToothNumber: Int?

    func switchToHome() {
        selectedTab = 0
    }

    func switchToChat() {
        selectedTab = 1
    }

    func switchToMap() {
        selectedTab = 2
    }

    func switchToMap(withTooth toothNumber: Int) {
        selectedToothNumber = toothNumber
        selectedTab = 2
    }

    func switchToPlan() {
        selectedTab = 3
    }
}
