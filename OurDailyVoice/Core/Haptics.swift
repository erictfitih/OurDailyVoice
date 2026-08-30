//
//  Haptics.swift
//  OurDailyVoice
//
//  Created by Kyu Kim on 1/14/26.
//

// Actions for tapping emojis

import UIKit

enum Haptics {
    static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func error() { UINotificationFeedbackGenerator().notificationOccurred(.error) }
}
