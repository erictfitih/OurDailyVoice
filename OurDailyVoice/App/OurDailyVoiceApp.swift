//
//  OurDailyVoiceApp.swift
//  OurDailyVoice
//
//  Created by Kyu Kim on 1/14/26.
//

import SwiftUI
import FirebaseCore

@main
struct OurDailyVoiceApp: App {
    @StateObject private var appState = AppState()
    @State private var isShowingClubData = false
    @State private var isShowingOrganizationAnalytics = false
    @State private var isShowingScheduleEditor = false

    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                Group {
                    if isShowingScheduleEditor, let site = appState.selectedSite {
                        ClubScheduleEditorView(site: site)
                    } else if isShowingOrganizationAnalytics {
                        OrganizationAnalyticsContainerView()
                    } else if isShowingClubData, let site = appState.selectedSite {
                        ClubDataContainerView(site: site)
                    } else if appState.selectedSite == nil {
                        ClubPickerView()
                    } else if appState.selectedRoom == nil {
                        RoomListView(site: appState.selectedSite!)
                    } else {
                        ContentView()
                    }
                }

                GlobalPancakeMenu(
                    isShowingClubData: $isShowingClubData,
                    isShowingOrganizationAnalytics: $isShowingOrganizationAnalytics,
                    isShowingScheduleEditor: $isShowingScheduleEditor
                )
            }
            .environmentObject(appState)
            .onChange(of: appState.selectedSite?.id) { _, selectedSiteID in
                if selectedSiteID == nil {
                    isShowingClubData = false
                    isShowingScheduleEditor = false
                }
            }
            .task {
                let moodService = MoodService()
                _ = try? await moodService.ensureSignedIn()
            }
        }
    }
}
