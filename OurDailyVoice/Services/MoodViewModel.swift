//
//  MoodViewModel.swift
//  OurDailyVoice
//
//  Created by Kyu Kim on 1/14/26.
//

import Foundation
import SwiftUI

@MainActor
final class MoodViewModel: ObservableObject {
    @Published var selectedDay: Date = Calendar.current.startOfDay(for: Date())
    @Published var entries: [MoodEntry] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var session: SessionDay?
    @Published var allSessions: [SessionDay] = []
    @Published var appState: AppState?
    @Published var scheduleStatus = ClubSchedule.status(at: Date())
    @Published var moodOptions = MoodPalette.options
    @Published private(set) var manualModeOverride: SessionMode?
    @Published private(set) var roomPromptMode: SessionMode?
    @Published private(set) var roomPromptIntervalMinutes = 30

    private let service = MoodService()
    private var uid: String?
    private var automaticModeWhenOverridden: SessionMode?

    var displayMode: SessionMode {
        roomPromptMode ?? manualModeOverride ?? scheduleStatus.expectedMode ?? .enter
    }

    var isUsingManualMode: Bool { manualModeOverride != nil }

    func start() async {
        do {
            uid = try await service.ensureSignedIn()
            print("UID:", uid ?? "nil")
            if let clubId = appState?.selectedSite?.id {
                selectedDay = ResponseDatePreference.date(for: clubId)
                let configuration = try? await service.fetchScheduleConfiguration(clubId: clubId)
                roomPromptIntervalMinutes = configuration?.roomPromptIntervalMinutes
                    ?? ClubSchedule.cachedConfiguration(for: clubId).roomPromptIntervalMinutes
                _ = try? await service.fetchMoodPaletteConfiguration(clubId: clubId)
                updateSchedule()
            }
            PendingResponseStore.clear()
            try await refresh()
            try await refreshAnalytics()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refresh() async throws {
        isLoading = true
        defer { isLoading = false }

        entries = try await service.fetchMoodsForDayUsingSelectedClub(day: selectedDay)
        guard let room = appState?.selectedRoom else {
            session = nil
            return
        }
        session = try await service.fetchSessionDayUsingSelectedClub(
            day: selectedDay,
            room: room
        )
    }

    func refreshAnalytics() async throws {
        allSessions = try await service.fetchAllSessionDaysUsingSelectedClub()
    }

    func setDay(_ day: Date) {
        selectedDay = Calendar.current.startOfDay(for: day)
        Task {
            do {
                try await refresh()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func log(option: MoodOption) {
        isLoading = true
        Haptics.tap()

        Task {
            defer { isLoading = false }

            do {
                try await service.addMoodUsingSelectedClub(
                    emoji: option.emoji,
                    value: option.value,
                    day: selectedDay
                )
                Haptics.success()
                try await refresh()
                try await refreshAnalytics()
            } catch {
                Haptics.error()
                errorMessage = error.localizedDescription
            }
        }
    }

    func updateSchedule(at date: Date = Date()) {
        let updatedStatus = ClubSchedule.status(
            at: date,
            clubId: appState?.selectedSite?.id
        )

        if manualModeOverride != nil,
           updatedStatus.expectedMode != automaticModeWhenOverridden {
            manualModeOverride = nil
            automaticModeWhenOverridden = nil
        }

        scheduleStatus = updatedStatus
        moodOptions = MoodPalette.options(
            for: appState?.selectedSite?.id,
            at: date
        )
    }

    func beginResponse(option: MoodOption) {
        guard !isLoading else { return }
        isLoading = true
        Haptics.tap()
        let tappedAt = Date()
        updateSchedule(at: tappedAt)
        let submissionMode = displayMode
        let approvalType: String
        if roomPromptMode != nil {
            approvalType = "roomDirectionPrompt"
        } else if isUsingManualMode {
            approvalType = "staffManualMode"
        } else {
            approvalType = "automaticSchedule"
        }

        Task {
            defer { isLoading = false }

            guard let room = appState?.selectedRoom else {
                errorMessage = "No room selected."
                return
            }

            do {
                let response = try await service.createMoodResponseUsingSelectedClub(
                    option: option,
                    room: room,
                    tappedAt: tappedAt,
                    responseDay: selectedDay
                )
                try await service.finalizeMoodResponseUsingSelectedClub(
                    response: response,
                    selectedMode: submissionMode,
                    finalMode: submissionMode,
                    approvalType: approvalType
                )
                Haptics.success()
                try await refreshAfterSubmission()
            } catch {
                Haptics.error()
                errorMessage = error.localizedDescription
            }
        }
    }

    func setManualMode(_ mode: SessionMode, pin: String) -> Bool {
        guard pin == Constants.adminPin else {
            Haptics.error()
            return false
        }

        manualModeOverride = mode
        automaticModeWhenOverridden = scheduleStatus.expectedMode
        Haptics.success()
        return true
    }

    func setRoomPromptMode(_ mode: SessionMode) {
        roomPromptMode = mode
        Haptics.success()
    }

    func clearRoomPromptMode() {
        roomPromptMode = nil
    }

    private func refreshAfterSubmission() async throws {
        try await refresh()
        try await refreshAnalytics()
    }

    var average: Double? {
        let values = displayMode == .enter
            ? (session?.enterValues ?? [])
            : (session?.leaveValues ?? [])

        guard !values.isEmpty else { return nil }
        let sum = values.reduce(0, +)
        return Double(sum) / Double(values.count)
    }

    var topEmoji: String? {
        let values = displayMode == .enter
            ? (session?.enterValues ?? [])
            : (session?.leaveValues ?? [])

        guard !values.isEmpty else { return nil }

        var counts: [Int: Int] = [:]
        for value in values {
            counts[value, default: 0] += 1
        }

        guard let topValue = counts.max(by: { $0.value < $1.value })?.key else {
            return nil
        }

        return moodOptions.first(where: { $0.value == topValue })?.emoji
    }
    
    private func averageDate(from dates: [Date]) -> Date? {
        guard !dates.isEmpty else { return nil }
        let avg = dates.map(\.timeIntervalSince1970).reduce(0, +) / Double(dates.count)
        return Date(timeIntervalSince1970: avg)
    }

    private func formattedDuration(from start: Date?, to end: Date?) -> String {
        guard let start, let end else { return "—" }

        let duration = end.timeIntervalSince(start)
        guard duration >= 0 else { return "—" }

        let totalMinutes = Int(duration / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    var dailyAnalytics: [DailyAnalytics] {
        DailyAnalytics.from(sessions: allSessions)
    }
    
    var youthsServed: Int {
        let enterCount = session?.enterValues.count ?? 0
        let leaveCount = session?.leaveValues.count ?? 0
        return max(enterCount, leaveCount)
    }

    var averageEnterTime: Date? {
        averageDate(from: session?.enterTimestamps ?? [])
    }

    var averageLeaveTime: Date? {
        averageDate(from: session?.leaveTimestamps ?? [])
    }


    var programDuration: TimeInterval? {
        guard
            let enterAvg = averageEnterTime,
            let leaveAvg = averageLeaveTime
        else { return nil }

        return leaveAvg.timeIntervalSince(enterAvg)
    }

    var formattedProgramDuration: String {
        guard let duration = programDuration, duration >= 0 else { return "—" }

        let totalMinutes = Int(duration / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

}
