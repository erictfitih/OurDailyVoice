//
//  Theme.swift
//  OurDailyVoice
//
//  Created by Kyu Kim on 1/14/26.
//

// UI Theme for the app

import SwiftUI


enum Theme {
    static let corner: CGFloat = 20
    static let cardOpacity: Double = 0.25

    static let bgGradient = LinearGradient(
        colors: [Color.blue.opacity(0.9), Color.blue.opacity(0.8), Color.blue.opacity(0.65)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
