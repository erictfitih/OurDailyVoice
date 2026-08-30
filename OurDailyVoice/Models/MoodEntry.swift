//
//  MoodEntry.swift
//  OurDailyVoice
//
//  Created by Kyu Kim on 1/14/26.
//

// json format for the emoji inputs

import Foundation

struct MoodEntry: Identifiable, Hashable {
    let id: String
    let emoji: String
    let value: Int
    let timestamp: Date
    let day: Date
}

