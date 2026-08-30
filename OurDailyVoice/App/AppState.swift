//
//  AppState.swift
//  OurDailyVoice
//
//  Created by Kyu Kim on 2/18/26.
//

import Foundation
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published var selectedSite: Site? {
        didSet { persistSelection() }
    }
    @Published var selectedRoom: String? {
        didSet { persistSelection() }
    }
    @Published var isSupervisorReady: Bool = false
    @Published var isAdminUnlocked: Bool = false
    @Published var isStaffVerificationRequired: Bool = false

    private static let selectedSiteKey = "PersistedSelectedSite"
    private static let selectedRoomKey = "PersistedSelectedRoom"

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.selectedSiteKey) {
            if let savedSite = try? JSONDecoder().decode(Site.self, from: data) {
                let hasFrontRoom = savedSite.rooms.contains {
                    $0.trimmingCharacters(in: .whitespacesAndNewlines)
                        .localizedCaseInsensitiveCompare("Front Room") == .orderedSame
                }
                selectedSite = Site(
                    id: savedSite.id,
                    name: savedSite.name,
                    rooms: hasFrontRoom ? savedSite.rooms : ["Front Room"] + savedSite.rooms
                )
            } else {
                selectedSite = nil
            }
        } else {
            selectedSite = nil
        }
        selectedRoom = UserDefaults.standard.string(forKey: Self.selectedRoomKey)

        if selectedSite == nil {
            selectedRoom = nil
        }
    }

    private func persistSelection() {
        if let selectedSite, let data = try? JSONEncoder().encode(selectedSite) {
            UserDefaults.standard.set(data, forKey: Self.selectedSiteKey)
        } else {
            UserDefaults.standard.removeObject(forKey: Self.selectedSiteKey)
        }

        if let selectedRoom, selectedSite != nil {
            UserDefaults.standard.set(selectedRoom, forKey: Self.selectedRoomKey)
        } else {
            UserDefaults.standard.removeObject(forKey: Self.selectedRoomKey)
        }
    }
}
