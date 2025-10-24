//
//  KeyboardPreloader.swift
//  BrightBite
//
//  Created by Tuan Nguyen on 10/1/25.
//

import UIKit

class KeyboardPreloader {
    private static var isPreloaded = false

    static func preloadKeyboard() {
        guard !isPreloaded else { return }

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            print("⚠️ Cannot preload keyboard - no window found")
            return
        }

        print("⌨️ Starting keyboard preload...")
        let startTime = Date()

        let textField = UITextField()
        textField.frame = CGRect(x: -10000, y: -10000, width: 1, height: 1)
        textField.autocorrectionType = .default
        textField.keyboardType = .default

        window.addSubview(textField)

        textField.becomeFirstResponder()

        Task {
            try? await Task.sleep(nanoseconds: 400_000_000)

            await MainActor.run {
                textField.resignFirstResponder()
                textField.removeFromSuperview()
            }
        }

        isPreloaded = true
        let elapsed = Date().timeIntervalSince(startTime)
        print("✅ Keyboard preloaded in \(Int(elapsed * 1000))ms")
    }

    static func preloadKeyboardAsync(completion: @escaping () -> Void) {
        DispatchQueue.main.async {
            preloadKeyboard()
            completion()
        }
    }
}
