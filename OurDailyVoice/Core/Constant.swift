//
//  Constant.swift
//  OurDailyVoice
//
//  Created by Kyu Kim on 1/14/26.
//


import Foundation

enum Constants {
    // Your existing Firestore uses "registered_sites". Keep that to avoid migration.
    static let sitesCollection = "registered_sites"

    // One session per site per day stored under: sites/{siteId}/sessions/{dayId}
    // If you prefer, you can rename "sites" later—this keeps it simple now.
    static let sitesRoot = "sites"
    static let sessionsSubcollection = "sessions"

    // Admin PIN (prototype). For real security, validate server-side.
    static let adminPin = "1903"
}

//__________________________________________//

/* Find the keys from the original code!!*/
//__________________________________________//

