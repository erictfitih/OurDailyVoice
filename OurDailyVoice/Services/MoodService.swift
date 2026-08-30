//
//  MoodService.swift
//  OurDailyVoice
//
//  Created by Kyu Kim on 1/14/26.
//

// Stores JSON from MoodEntry to Firebase
import Foundation
import FirebaseAuth
import FirebaseFirestore

final class MoodService {

    // MARK: - Models

    struct Club: Identifiable, Hashable, Codable {
        var id: String
        var name: String
        var rooms: [String]
    }

    // MARK: - Defaults

    private let defaultClubs: [Club] = [
        
        
        Club(id: "AJ", name: "Andrew Jackson", rooms: ["Front Room", "Dreamerville", "Music Studio", "Art Room", "Gym", "Game Room"]),
        Club(id: "TTC", name: "Teen Tech Center", rooms: ["Teen Tech Center"]),
        Club(id: "Chad", name: "Chadwell", rooms: ["Cafeteria", "Gymnasium", "Classroom #6", "Classroom #16"]),
        Club(id: "EEP", name: "East End Prep", rooms: ["PD Room", "Game Rooom"]),
        Club(id: "EV", name: "Eagle View", rooms: ["Classroom"]),
        Club(id: "FV", name: "Fairview", rooms: ["Main Room", "Tech Lab", "STEM Lab", "Gamesroom", "Art Room"]),
        Club(id: "FR", name: "Franklin", rooms: ["Gamesroom", "Homework Room", "Gym", "Tech Lab", "Snack Room", "Art Room", "Teen Room", "Music Studio"]),
        Club(id: "GG", name: "Glengarry", rooms: ["Games room", "Classroom", "Cafeteria", "Gym"]),
        Club(id: "NB", name: "Neely's Bend", rooms: ["Classroom"]),
        Club(id: "PT", name: "Preston Taylor", rooms: ["Classroom"]),
        Club(id: "SHW", name: "Shwab", rooms: ["Room 204", "Room 247"]),
        Club(id: "VAL", name: "Valor Clubhouse", rooms: ["Cafeteria", "Classroom 1", "Classroom 2", "Classroom 3", "Tech Area", "Multipurpose Area"]),
        Club(id: "VALHS", name: "Valor High School", rooms: ["Classroom"])
    ]

    private lazy var db = Firestore.firestore()
    private let selectedClubDefaultsKey = "SelectedClubId"

    // MARK: - Club Selection

    private func clubsCollection() -> CollectionReference {
        db.collection(Constants.sitesCollection)
    }

    func setSelectedClubId(_ clubId: String?) {
        let defaults = UserDefaults.standard
        if let clubId {
            defaults.set(clubId, forKey: selectedClubDefaultsKey)
        } else {
            defaults.removeObject(forKey: selectedClubDefaultsKey)
        }
    }

    func getSelectedClubId() -> String? {
        UserDefaults.standard.string(forKey: selectedClubDefaultsKey)
    }

    var selectedClubId: String? { getSelectedClubId() }

    // MARK: - Club Schedule

    private func scheduleDocument(clubId: String) -> DocumentReference {
        clubsCollection()
            .document(clubId)
            .collection("settings")
            .document("entryExitSchedule")
    }

    func fetchScheduleConfiguration(clubId: String) async throws -> ClubScheduleConfiguration {
        let snapshot = try await scheduleDocument(clubId: clubId).getDocument()
        guard snapshot.exists, let data = snapshot.data() else {
            let configuration = ClubScheduleConfiguration.standard
            ClubSchedule.cache(configuration, for: clubId)
            return configuration
        }

        func intValue(_ key: String, default fallback: Int) -> Int {
            if let value = data[key] as? Int { return value }
            if let value = data[key] as? NSNumber { return value.intValue }
            return fallback
        }

        let exceptionsData = data["exceptions"] as? [[String: Any]] ?? []
        let exceptions = exceptionsData.compactMap { item -> ClubScheduleException? in
            guard let dateKey = item["dateKey"] as? String else { return nil }
            let entry = (item["entryStartMinutes"] as? NSNumber)?.intValue
                ?? item["entryStartMinutes"] as? Int
            let exit = (item["exitStartMinutes"] as? NSNumber)?.intValue
                ?? item["exitStartMinutes"] as? Int
            guard let entry, let exit else { return nil }
            return ClubScheduleException(
                dateKey: dateKey,
                entryStartMinutes: entry,
                exitStartMinutes: exit
            )
        }

        let standard = ClubScheduleConfiguration.standard
        let configuration = ClubScheduleConfiguration(
            summerEntryStartMinutes: intValue(
                "summerEntryStartMinutes",
                default: standard.summerEntryStartMinutes
            ),
            summerExitStartMinutes: intValue(
                "summerExitStartMinutes",
                default: standard.summerExitStartMinutes
            ),
            schoolYearEntryStartMinutes: intValue(
                "schoolYearEntryStartMinutes",
                default: standard.schoolYearEntryStartMinutes
            ),
            schoolYearExitStartMinutes: intValue(
                "schoolYearExitStartMinutes",
                default: standard.schoolYearExitStartMinutes
            ),
            roomPromptIntervalMinutes: intValue(
                "roomPromptIntervalMinutes",
                default: standard.roomPromptIntervalMinutes
            ),
            exceptions: exceptions.sorted { $0.dateKey < $1.dateKey }
        )

        ClubSchedule.cache(configuration, for: clubId)
        return configuration
    }

    func saveScheduleConfiguration(
        _ configuration: ClubScheduleConfiguration,
        clubId: String
    ) async throws {
        guard configuration.summerEntryStartMinutes < configuration.summerExitStartMinutes,
              configuration.schoolYearEntryStartMinutes < configuration.schoolYearExitStartMinutes,
              (1...120).contains(configuration.roomPromptIntervalMinutes),
              configuration.exceptions.allSatisfy({ $0.entryStartMinutes < $0.exitStartMinutes })
        else {
            throw NSError(domain: "MoodService", code: 422, userInfo: [
                NSLocalizedDescriptionKey: "Every entry start time must be earlier than its exit start time."
            ])
        }

        let exceptions: [[String: Any]] = configuration.exceptions.map {
            [
                "dateKey": $0.dateKey,
                "entryStartMinutes": $0.entryStartMinutes,
                "exitStartMinutes": $0.exitStartMinutes
            ]
        }

        try await scheduleDocument(clubId: clubId).setData([
            "summerEntryStartMinutes": configuration.summerEntryStartMinutes,
            "summerExitStartMinutes": configuration.summerExitStartMinutes,
            "schoolYearEntryStartMinutes": configuration.schoolYearEntryStartMinutes,
            "schoolYearExitStartMinutes": configuration.schoolYearExitStartMinutes,
            "roomPromptIntervalMinutes": configuration.roomPromptIntervalMinutes,
            "exceptions": exceptions,
            "updatedAt": FieldValue.serverTimestamp()
        ], merge: true)

        ClubSchedule.cache(configuration, for: clubId)
    }

    // MARK: - Club Emoji Palette

    private func emojiPaletteDocument(clubId: String) -> DocumentReference {
        clubsCollection()
            .document(clubId)
            .collection("settings")
            .document("emojiPalette")
    }

    func fetchMoodPaletteConfiguration(clubId: String) async throws -> ClubMoodPaletteConfiguration {
        let snapshot = try await emojiPaletteDocument(clubId: clubId).getDocument()
        guard snapshot.exists, let data = snapshot.data() else {
            let configuration = ClubMoodPaletteConfiguration.standard
            MoodPalette.cache(configuration, for: clubId)
            return configuration
        }

        let regularEmojis = data["regularEmojis"] as? [String] ?? MoodPalette.defaultEmojis
        let regularDisplayNumbers = data["regularDisplayNumbers"] as? [String]
            ?? MoodPalette.defaultDisplayNumbers
        let regularDisplayNames = data["regularDisplayNames"] as? [String]
            ?? MoodPalette.defaultDisplayNames
        let temporaryData = data["temporaryPalettes"] as? [[String: Any]] ?? []
        let temporaryPalettes = temporaryData.compactMap { item -> TemporaryMoodPalette? in
            guard
                let id = item["id"] as? String,
                let name = item["name"] as? String,
                let startDateKey = item["startDateKey"] as? String,
                let endDateKey = item["endDateKey"] as? String,
                let emojis = item["emojis"] as? [String],
                MoodPalette.isValid(emojis)
            else { return nil }

            return TemporaryMoodPalette(
                id: id,
                name: name,
                startDateKey: startDateKey,
                endDateKey: endDateKey,
                emojis: emojis,
                displayNumbers: {
                    let values = item["displayNumbers"] as? [String] ?? []
                    return MoodPalette.isValidDisplayText(values)
                        ? values
                        : MoodPalette.defaultDisplayNumbers
                }(),
                displayNames: {
                    let values = item["displayNames"] as? [String] ?? []
                    return MoodPalette.isValidDisplayText(values)
                        ? values
                        : MoodPalette.defaultDisplayNames
                }()
            )
        }

        let configuration = ClubMoodPaletteConfiguration(
            regularEmojis: MoodPalette.isValid(regularEmojis)
                ? regularEmojis
                : MoodPalette.defaultEmojis,
            regularDisplayNumbers: MoodPalette.isValidDisplayText(regularDisplayNumbers)
                ? regularDisplayNumbers
                : MoodPalette.defaultDisplayNumbers,
            regularDisplayNames: MoodPalette.isValidDisplayText(regularDisplayNames)
                ? regularDisplayNames
                : MoodPalette.defaultDisplayNames,
            temporaryPalettes: temporaryPalettes
        )
        MoodPalette.cache(configuration, for: clubId)
        return configuration
    }

    func saveMoodPaletteConfiguration(
        _ configuration: ClubMoodPaletteConfiguration,
        clubId: String
    ) async throws {
        guard MoodPalette.isValid(configuration.regularEmojis),
              MoodPalette.isValidDisplayText(configuration.regularDisplayNumbers),
              MoodPalette.isValidDisplayText(configuration.regularDisplayNames),
              configuration.temporaryPalettes.allSatisfy({
                  MoodPalette.isValid($0.emojis) &&
                  MoodPalette.isValidDisplayText($0.displayNumbers) &&
                  MoodPalette.isValidDisplayText($0.displayNames) &&
                  !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                  $0.startDateKey <= $0.endDateKey
              })
        else {
            throw NSError(domain: "MoodService", code: 422, userInfo: [
                NSLocalizedDescriptionKey: "Each palette needs nine emojis and a valid date range."
            ])
        }

        let temporaryPalettes: [[String: Any]] = configuration.temporaryPalettes.map {
            [
                "id": $0.id,
                "name": $0.name,
                "startDateKey": $0.startDateKey,
                "endDateKey": $0.endDateKey,
                "emojis": $0.emojis,
                "displayNumbers": $0.displayNumbers,
                "displayNames": $0.displayNames
            ]
        }

        try await emojiPaletteDocument(clubId: clubId).setData([
            "regularEmojis": configuration.regularEmojis,
            "regularDisplayNumbers": configuration.regularDisplayNumbers,
            "regularDisplayNames": configuration.regularDisplayNames,
            "temporaryPalettes": temporaryPalettes,
            "updatedAt": FieldValue.serverTimestamp()
        ], merge: true)

        MoodPalette.cache(configuration, for: clubId)
    }

    // MARK: - Clubs

    func fetchClubs() async throws -> [Club] {
        var clubs = defaultClubs

        let snapshot = try await clubsCollection().getDocuments()

        for doc in snapshot.documents {
            let data = doc.data()

            guard let name = data["name"] as? String, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                continue
            }

            let rooms = (data["rooms"] as? [String]) ?? []
            let club = Club(id: doc.documentID, name: name, rooms: rooms)

            if let index = clubs.firstIndex(where: { $0.name.caseInsensitiveCompare(club.name) == .orderedSame }) {
                clubs[index] = club
            } else {
                clubs.append(club)
            }
        }

        clubs = clubs.map { club in
            Club(
                id: club.id,
                name: club.name,
                rooms: roomsIncludingFrontRoom(club.rooms)
            )
        }
        clubs.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        return clubs
    }

    @discardableResult
    func addClub(name: String, rooms: [String] = []) async throws -> Club {
        let ref = clubsCollection().document()
        let normalizedRooms = roomsIncludingFrontRoom(rooms)

        try await ref.setData([
            "name": name,
            "rooms": normalizedRooms,
            "createdAt": FieldValue.serverTimestamp()
        ])

        let club = Club(id: ref.documentID, name: name, rooms: normalizedRooms)
        setSelectedClubId(club.id)
        return club
    }

    private func roomsIncludingFrontRoom(_ rooms: [String]) -> [String] {
        guard !rooms.contains(where: {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
                .localizedCaseInsensitiveCompare("Front Room") == .orderedSame
        }) else { return rooms }

        return ["Front Room"] + rooms
    }

    // MARK: - Auth

    func ensureSignedIn() async throws -> String {
        if let user = Auth.auth().currentUser {
            return user.uid
        }

        let result = try await Auth.auth().signInAnonymously()
        return result.user.uid
    }

    // MARK: - Individual Mood Logging

    private func clubMoodsCollection(clubId: String) -> CollectionReference {
        db.collection(Constants.sitesCollection)
            .document(clubId)
            .collection("moods")
    }

    func addMood(clubId: String, emoji: String, value: Int, day: Date) async throws {
        let ref = clubMoodsCollection(clubId: clubId).document()

        try await ref.setData([
            "emoji": emoji,
            "value": value,
            "day": Timestamp(date: Calendar.current.startOfDay(for: day)),
            "timestamp": FieldValue.serverTimestamp()
        ])

        print("[Firestore] wrote: \(Constants.sitesCollection)/\(clubId)/moods/\(ref.documentID)")
    }

    func addMoodUsingSelectedClub(emoji: String, value: Int, day: Date) async throws {
        guard let clubId = selectedClubId else {
            throw NSError(domain: "MoodService", code: 400, userInfo: [
                NSLocalizedDescriptionKey: "No club selected."
            ])
        }

        try await addMood(clubId: clubId, emoji: emoji, value: value, day: day)
    }

    func fetchMoodsForDay(clubId: String, day: Date) async throws -> [MoodEntry] {
        let start = Calendar.current.startOfDay(for: day)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start)!

        let snap = try await clubMoodsCollection(clubId: clubId)
            .whereField("day", isGreaterThanOrEqualTo: Timestamp(date: start))
            .whereField("day", isLessThan: Timestamp(date: end))
            .order(by: "day")
            .order(by: "timestamp", descending: true)
            .getDocuments(source: .server)

        return snap.documents.compactMap { doc -> MoodEntry? in
            let data = doc.data()

            guard
                let emoji = data["emoji"] as? String,
                let value = data["value"] as? Int,
                let dayTS = data["day"] as? Timestamp,
                let timeTS = data["timestamp"] as? Timestamp
            else { return nil }

            return MoodEntry(
                id: doc.documentID,
                emoji: emoji,
                value: value,
                timestamp: timeTS.dateValue(),
                day: dayTS.dateValue()
            )
        }
    }
    
    func fetchMoodsForDayUsingSelectedClub(day: Date) async throws -> [MoodEntry] {
        guard let clubId = selectedClubId else {
            throw NSError(domain: "MoodService", code: 400, userInfo: [
                NSLocalizedDescriptionKey: "No club selected."
            ])
        }

        return try await fetchMoodsForDay(clubId: clubId, day: day)
    }

    // MARK: - Durable Mood Responses

    private func moodResponsesCollection(clubId: String) -> CollectionReference {
        db.collection(Constants.sitesCollection)
            .document(clubId)
            .collection("moodResponses")
    }

    func createMoodResponseUsingSelectedClub(
        option: MoodOption,
        room: String,
        tappedAt: Date,
        responseDay: Date
    ) async throws -> PendingMoodResponse {
        guard let clubId = selectedClubId else {
            throw NSError(domain: "MoodService", code: 400, userInfo: [
                NSLocalizedDescriptionKey: "No club selected."
            ])
        }

        let ref = moodResponsesCollection(clubId: clubId).document()
        let schedule = ClubSchedule.status(at: tappedAt, clubId: clubId)
        let expectedMode = schedule.expectedMode

        try await ref.setData([
            "emoji": option.emoji,
            "value": option.value,
            "room": room,
            "tappedAt": Timestamp(date: tappedAt),
            "day": Timestamp(date: ClubSchedule.startOfDay(for: responseDay)),
            "expectedMode": expectedMode?.rawValue ?? "inactive",
            "schedule": schedule.season.rawValue,
            "status": MoodResponseStatus.awaitingDirection.rawValue,
            "createdAt": FieldValue.serverTimestamp()
        ])

        return PendingMoodResponse(
            id: ref.documentID,
            emoji: option.emoji,
            value: option.value,
            tappedAt: tappedAt,
            responseDay: responseDay,
            room: room,
            expectedMode: expectedMode,
            selectedMode: nil,
            status: .awaitingDirection
        )
    }

    func markResponseForStaffApprovalUsingSelectedClub(
        response: PendingMoodResponse,
        selectedMode: SessionMode
    ) async throws {
        guard let clubId = selectedClubId else {
            throw NSError(domain: "MoodService", code: 400, userInfo: [
                NSLocalizedDescriptionKey: "No club selected."
            ])
        }

        try await moodResponsesCollection(clubId: clubId)
            .document(response.id)
            .updateData([
                "selectedMode": selectedMode.rawValue,
                "status": MoodResponseStatus.needsStaffApproval.rawValue,
                "staffReviewRequestedAt": FieldValue.serverTimestamp()
            ])
    }

    func finalizeMoodResponseUsingSelectedClub(
        response: PendingMoodResponse,
        selectedMode: SessionMode,
        finalMode: SessionMode,
        approvalType: String
    ) async throws {
        guard let clubId = selectedClubId else {
            throw NSError(domain: "MoodService", code: 400, userInfo: [
                NSLocalizedDescriptionKey: "No club selected."
            ])
        }

        let responseRef = moodResponsesCollection(clubId: clubId).document(response.id)
        let sessionRef = sessionDoc(
            clubId: clubId,
            day: response.responseDay,
            room: response.room
        )
        let approverUID = Auth.auth().currentUser?.uid ?? "unknown"

        _ = try await db.runTransaction { transaction, errorPointer in
            do {
                let responseSnapshot = try transaction.getDocument(responseRef)
                let responseData = responseSnapshot.data() ?? [:]

                if responseData["status"] as? String == MoodResponseStatus.finalized.rawValue {
                    return nil
                }

                guard responseSnapshot.exists else {
                    throw NSError(domain: "MoodService", code: 404, userInfo: [
                        NSLocalizedDescriptionKey: "The saved mood response could not be found."
                    ])
                }

                let sessionSnapshot = try transaction.getDocument(sessionRef)
                var sessionData = sessionSnapshot.data() ?? [:]
                var enterValues = sessionData["enterValues"] as? [Int] ?? []
                var leaveValues = sessionData["leaveValues"] as? [Int] ?? []
                var enterTimestamps = sessionData["enterTimestamps"] as? [Timestamp] ?? []
                var leaveTimestamps = sessionData["leaveTimestamps"] as? [Timestamp] ?? []
                let originalTimestamp = Timestamp(date: response.tappedAt)

                if finalMode == .enter {
                    enterValues.append(response.value)
                    enterTimestamps.append(originalTimestamp)
                } else {
                    leaveValues.append(response.value)
                    leaveTimestamps.append(originalTimestamp)
                }

                func average(_ values: [Int]) -> Double? {
                    guard !values.isEmpty else { return nil }
                    return Double(values.reduce(0, +)) / Double(values.count)
                }

                let enterAverage = average(enterValues)
                let leaveAverage = average(leaveValues)
                let delta = (enterAverage != nil && leaveAverage != nil)
                    ? leaveAverage! - enterAverage!
                    : nil

                sessionData["day"] = Timestamp(date: ClubSchedule.startOfDay(for: response.responseDay))
                sessionData["room"] = response.room
                sessionData["enterValues"] = enterValues
                sessionData["leaveValues"] = leaveValues
                sessionData["enterTimestamps"] = enterTimestamps
                sessionData["leaveTimestamps"] = leaveTimestamps
                sessionData["enterAvg"] = enterAverage.map { $0 as Any } ?? NSNull()
                sessionData["leaveAvg"] = leaveAverage.map { $0 as Any } ?? NSNull()
                sessionData["delta"] = delta.map { $0 as Any } ?? NSNull()
                sessionData["updatedAt"] = FieldValue.serverTimestamp()

                transaction.setData(sessionData, forDocument: sessionRef, merge: true)
                transaction.updateData([
                    "selectedMode": selectedMode.rawValue,
                    "finalMode": finalMode.rawValue,
                    "status": MoodResponseStatus.finalized.rawValue,
                    "approvalType": approvalType,
                    "approvedBy": approverUID,
                    "confirmedAt": FieldValue.serverTimestamp()
                ], forDocument: responseRef)
            } catch {
                errorPointer?.pointee = error as NSError
            }

            return nil
        }
    }

    func fetchUnresolvedResponseUsingSelectedClub(room: String) async throws -> PendingMoodResponse? {
        guard let clubId = selectedClubId else {
            throw NSError(domain: "MoodService", code: 400, userInfo: [
                NSLocalizedDescriptionKey: "No club selected."
            ])
        }

        let snapshot = try await moodResponsesCollection(clubId: clubId)
            .whereField("status", in: [
                MoodResponseStatus.awaitingDirection.rawValue,
                MoodResponseStatus.needsStaffApproval.rawValue
            ])
            .getDocuments()

        return snapshot.documents
            .compactMap { PendingMoodResponse(document: $0) }
            .filter { $0.room == room }
            .sorted { $0.tappedAt < $1.tappedAt }
            .first
    }

    // MARK: - Aggregated Session Logging

    private func sessionDoc(
        clubId: String,
        day: Date,
        room: String? = nil
    ) -> DocumentReference {
        let dayId = SessionDay.dayId(for: day)
        let documentId: String
        if let room {
            let encodedRoom = Data(room.utf8)
                .base64EncodedString()
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "+", with: "-")
                .replacingOccurrences(of: "=", with: "")
            documentId = "\(dayId)--\(encodedRoom)"
        } else {
            documentId = dayId
        }

        return db.collection(Constants.sitesCollection)
            .document(clubId)
            .collection("sessions")
            .document(documentId)
    }

    func appendGroupMoodUsingSelectedClub(
        day: Date,
        mode: SessionMode,
        value: Int,
        room: String
    ) async throws {
        guard let clubId = selectedClubId else {
            throw NSError(domain: "MoodService", code: 400, userInfo: [
                NSLocalizedDescriptionKey: "No club selected."
            ])
        }

        let ref = sessionDoc(clubId: clubId, day: day, room: room)
        let dayStart = Calendar.current.startOfDay(for: day)

        _ = try await db.runTransaction { txn, errPtr in
            do {
                let snap = try txn.getDocument(ref)
                var data = snap.data() ?? [:]

                var enterValues = data["enterValues"] as? [Int] ?? []
                var leaveValues = data["leaveValues"] as? [Int] ?? []
                var enterTimestamps = (data["enterTimestamps"] as? [Timestamp]) ?? []
                var leaveTimestamps = (data["leaveTimestamps"] as? [Timestamp]) ?? []

                let now = Timestamp(date: Date())

                if mode == .enter {
                    enterValues.append(value)
                    enterTimestamps.append(now)
                } else {
                    leaveValues.append(value)
                    leaveTimestamps.append(now)
                }

                func avg(_ xs: [Int]) -> Double? {
                    guard !xs.isEmpty else { return nil }
                    return Double(xs.reduce(0, +)) / Double(xs.count)
                }

                let enterAvg = avg(enterValues)
                let leaveAvg = avg(leaveValues)
                let delta = (enterAvg != nil && leaveAvg != nil) ? leaveAvg! - enterAvg! : nil

                data["day"] = Timestamp(date: dayStart)
                data["room"] = room
                data["enterValues"] = enterValues
                data["leaveValues"] = leaveValues
                data["enterTimestamps"] = enterTimestamps
                data["leaveTimestamps"] = leaveTimestamps
                data["enterAvg"] = enterAvg as Any
                data["leaveAvg"] = leaveAvg as Any
                data["delta"] = delta as Any
                data["updatedAt"] = FieldValue.serverTimestamp()

                txn.setData(data, forDocument: ref, merge: true)
            } catch {
                errPtr?.pointee = error as NSError
            }

            return nil
        }
    }

    func fetchSessionDayUsingSelectedClub(day: Date, room: String) async throws -> SessionDay? {
        guard let clubId = selectedClubId else {
            throw NSError(domain: "MoodService", code: 400, userInfo: [
                NSLocalizedDescriptionKey: "No club selected."
            ])
        }

        let roomDocument = try await sessionDoc(
            clubId: clubId,
            day: day,
            room: room
        ).getDocument()
        if roomDocument.exists {
            return SessionDay(doc: roomDocument)
        }

        // Preserve access to records created before sessions were separated by room.
        let legacyDocument = try await sessionDoc(clubId: clubId, day: day).getDocument()
        guard let legacySession = SessionDay(doc: legacyDocument),
              legacySession.room == room
        else { return nil }
        return legacySession
    }

    func fetchAllSessionDays(clubId: String) async throws -> [SessionDay] {
        let snap = try await db.collection(Constants.sitesCollection)
            .document(clubId)
            .collection("sessions")
            .order(by: "day", descending: false)
            .getDocuments()

        return snap.documents.compactMap { SessionDay(doc: $0) }
    }

    func fetchAllSessionDaysUsingSelectedClub() async throws -> [SessionDay] {
        guard let clubId = selectedClubId else {
            throw NSError(domain: "MoodService", code: 400, userInfo: [
                NSLocalizedDescriptionKey: "No club selected."
            ])
        }

        return try await fetchAllSessionDays(clubId: clubId)
    }
}
