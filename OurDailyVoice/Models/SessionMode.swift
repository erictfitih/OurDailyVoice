import Foundation

enum SessionMode: String, Codable {
    case enter
    case leave

    var title: String {
        self == .enter ? "Entry" : "Exit"
    }

    var childActionTitle: String {
        self == .enter ? "Coming In" : "Leaving"
    }
}
