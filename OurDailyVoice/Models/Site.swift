//
//  Site.swift
//  OurDailyVoice
//
//  Created by Kyu Kim on 2/18/26.
//

import Foundation
import FirebaseFirestore

struct Site: Identifiable, Hashable, Codable {
    let id: String
    let name: String
    let rooms: [String]

    init(id: String, name: String, rooms: [String] = []) {
        self.id = id
        self.name = name
        self.rooms = rooms
    }

    init?(doc: DocumentSnapshot) {
        let data = doc.data() ?? [:]

        let name =
            (data["name"] as? String) ??
            (data["siteID"] as? String) ??
            doc.documentID

        let rooms = (data["rooms"] as? [String]) ?? []

        self.id = doc.documentID
        self.name = name
        self.rooms = rooms
    }
}
