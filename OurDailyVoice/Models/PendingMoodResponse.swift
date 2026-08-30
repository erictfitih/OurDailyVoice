import Foundation
import FirebaseFirestore

enum MoodResponseStatus: String, Codable {
    case awaitingDirection
    case needsStaffApproval
    case finalized
}

struct PendingMoodResponse: Identifiable, Equatable, Codable {
    let id: String
    let emoji: String
    let value: Int
    let tappedAt: Date
    let responseDay: Date
    let room: String
    let expectedMode: SessionMode?
    let selectedMode: SessionMode?
    let status: MoodResponseStatus

    init(
        id: String,
        emoji: String,
        value: Int,
        tappedAt: Date,
        responseDay: Date,
        room: String,
        expectedMode: SessionMode?,
        selectedMode: SessionMode?,
        status: MoodResponseStatus
    ) {
        self.id = id
        self.emoji = emoji
        self.value = value
        self.tappedAt = tappedAt
        self.responseDay = responseDay
        self.room = room
        self.expectedMode = expectedMode
        self.selectedMode = selectedMode
        self.status = status
    }

    init?(document: QueryDocumentSnapshot) {
        let data = document.data()
        guard
            let emoji = data["emoji"] as? String,
            let value = data["value"] as? Int,
            let tappedAt = data["tappedAt"] as? Timestamp,
            let room = data["room"] as? String,
            let statusText = data["status"] as? String,
            let status = MoodResponseStatus(rawValue: statusText)
        else { return nil }

        self.id = document.documentID
        self.emoji = emoji
        self.value = value
        self.tappedAt = tappedAt.dateValue()
        self.responseDay = (data["day"] as? Timestamp)?.dateValue() ?? tappedAt.dateValue()
        self.room = room
        self.expectedMode = (data["expectedMode"] as? String).flatMap(SessionMode.init(rawValue:))
        self.selectedMode = (data["selectedMode"] as? String).flatMap(SessionMode.init(rawValue:))
        self.status = status
    }

    func selecting(_ mode: SessionMode, status: MoodResponseStatus) -> PendingMoodResponse {
        PendingMoodResponse(
            id: id,
            emoji: emoji,
            value: value,
            tappedAt: tappedAt,
            responseDay: responseDay,
            room: room,
            expectedMode: expectedMode,
            selectedMode: mode,
            status: status
        )
    }
}
