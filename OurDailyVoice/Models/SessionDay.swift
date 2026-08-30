//
//  SessionDay.swift
//  OurDailyVoice
//
//  Created by Kyu Kim on 2/18/26.
//

import Foundation
import FirebaseFirestore

struct SessionDay: Identifiable {
    let id: String           // yyyy-MM-dd
    let day: Date
    let enterValues: [Int]
    let leaveValues: [Int]
    let enterTimestamps: [Date]
    let leaveTimestamps: [Date]
    let enterAvg: Double?
    let leaveAvg: Double?
    let delta: Double?
    let room: String

    init?(doc: DocumentSnapshot) {
        let data = doc.data() ?? [:]

        guard let dayTS = data["day"] as? Timestamp else { return nil }

        self.id = doc.documentID
        self.day = dayTS.dateValue()
        self.enterValues = data["enterValues"] as? [Int] ?? []
        self.leaveValues = data["leaveValues"] as? [Int] ?? []

        let enterTS = data["enterTimestamps"] as? [Timestamp] ?? []
        let leaveTS = data["leaveTimestamps"] as? [Timestamp] ?? []

        self.enterTimestamps = enterTS.map { $0.dateValue() }
        self.leaveTimestamps = leaveTS.map { $0.dateValue() }

        self.enterAvg = data["enterAvg"] as? Double
        self.leaveAvg = data["leaveAvg"] as? Double
        self.delta = data["delta"] as? Double
        
        self.room = data["room"] as? String ?? "Unknown"
    }

    static func dayId(for day: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = ClubSchedule.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: ClubSchedule.startOfDay(for: day))
    }
}
