import Foundation

enum SchedulePeriod: Equatable {
    case inactive
    case entry
    case exit

    var mode: SessionMode? {
        switch self {
        case .inactive: nil
        case .entry: .enter
        case .exit: .leave
        }
    }

    var title: String {
        switch self {
        case .inactive: "Inactive"
        case .entry: "Entry"
        case .exit: "Exit"
        }
    }
}

struct ScheduleStatus: Equatable {
    enum Season: String {
        case summer = "Summer"
        case schoolYear = "School Year"
    }

    let season: Season
    let period: SchedulePeriod
    let entryStartMinutes: Int
    let exitStartMinutes: Int
    let isOneDayException: Bool

    var expectedMode: SessionMode? { period.mode }
    var entryStartText: String { ClubSchedule.timeText(minutes: entryStartMinutes) }
    var exitStartText: String { ClubSchedule.timeText(minutes: exitStartMinutes) }
}

struct ClubScheduleException: Identifiable, Codable, Equatable {
    var dateKey: String
    var entryStartMinutes: Int
    var exitStartMinutes: Int

    var id: String { dateKey }
}

struct ClubScheduleConfiguration: Codable, Equatable {
    var summerEntryStartMinutes: Int
    var summerExitStartMinutes: Int
    var schoolYearEntryStartMinutes: Int
    var schoolYearExitStartMinutes: Int
    var roomPromptIntervalMinutes: Int
    var exceptions: [ClubScheduleException]

    init(
        summerEntryStartMinutes: Int,
        summerExitStartMinutes: Int,
        schoolYearEntryStartMinutes: Int,
        schoolYearExitStartMinutes: Int,
        roomPromptIntervalMinutes: Int = 30,
        exceptions: [ClubScheduleException]
    ) {
        self.summerEntryStartMinutes = summerEntryStartMinutes
        self.summerExitStartMinutes = summerExitStartMinutes
        self.schoolYearEntryStartMinutes = schoolYearEntryStartMinutes
        self.schoolYearExitStartMinutes = schoolYearExitStartMinutes
        self.roomPromptIntervalMinutes = roomPromptIntervalMinutes
        self.exceptions = exceptions
    }

    private enum CodingKeys: String, CodingKey {
        case summerEntryStartMinutes
        case summerExitStartMinutes
        case schoolYearEntryStartMinutes
        case schoolYearExitStartMinutes
        case roomPromptIntervalMinutes
        case exceptions
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        summerEntryStartMinutes = try container.decode(Int.self, forKey: .summerEntryStartMinutes)
        summerExitStartMinutes = try container.decode(Int.self, forKey: .summerExitStartMinutes)
        schoolYearEntryStartMinutes = try container.decode(Int.self, forKey: .schoolYearEntryStartMinutes)
        schoolYearExitStartMinutes = try container.decode(Int.self, forKey: .schoolYearExitStartMinutes)
        roomPromptIntervalMinutes = try container.decodeIfPresent(
            Int.self,
            forKey: .roomPromptIntervalMinutes
        ) ?? 30
        exceptions = try container.decodeIfPresent(
            [ClubScheduleException].self,
            forKey: .exceptions
        ) ?? []
    }

    static let standard = ClubScheduleConfiguration(
        summerEntryStartMinutes: 6 * 60 + 45,
        summerExitStartMinutes: 12 * 60,
        schoolYearEntryStartMinutes: 13 * 60 + 45,
        schoolYearExitStartMinutes: 15 * 60 + 30,
        roomPromptIntervalMinutes: 30,
        exceptions: []
    )
}

enum ClubSchedule {
    static let timeZone = TimeZone(identifier: "America/Chicago")!
    private static let cacheKeyPrefix = "ClubScheduleConfiguration."

    static func status(at date: Date, clubId: String? = nil) -> ScheduleStatus {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        let components = calendar.dateComponents([.month, .day, .hour, .minute], from: date)
        let month = components.month ?? 1
        let day = components.day ?? 1
        let minutes = (components.hour ?? 0) * 60 + (components.minute ?? 0)
        let configuration = cachedConfiguration(for: clubId)

        let isSummer =
            (month == 5 && day >= 26) ||
            month == 6 ||
            month == 7 ||
            (month == 8 && day <= 16)

        let season: ScheduleStatus.Season = isSummer ? .summer : .schoolYear
        let exception = configuration.exceptions.first { $0.dateKey == dateKey(for: date) }
        let entryStart = exception?.entryStartMinutes ?? (
            isSummer
                ? configuration.summerEntryStartMinutes
                : configuration.schoolYearEntryStartMinutes
        )
        let exitStart = exception?.exitStartMinutes ?? (
            isSummer
                ? configuration.summerExitStartMinutes
                : configuration.schoolYearExitStartMinutes
        )

        let period: SchedulePeriod
        if minutes < entryStart {
            period = .inactive
        } else if minutes < exitStart {
            period = .entry
        } else {
            period = .exit
        }

        return ScheduleStatus(
            season: season,
            period: period,
            entryStartMinutes: entryStart,
            exitStartMinutes: exitStart,
            isOneDayException: exception != nil
        )
    }

    static func cachedConfiguration(for clubId: String?) -> ClubScheduleConfiguration {
        guard
            let clubId,
            let data = UserDefaults.standard.data(forKey: cacheKeyPrefix + clubId),
            let configuration = try? JSONDecoder().decode(ClubScheduleConfiguration.self, from: data)
        else {
            return .standard
        }

        return configuration
    }

    static func cache(_ configuration: ClubScheduleConfiguration, for clubId: String) {
        guard let data = try? JSONEncoder().encode(configuration) else { return }
        UserDefaults.standard.set(data, forKey: cacheKeyPrefix + clubId)
    }

    static func startOfDay(for date: Date) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.startOfDay(for: date)
    }

    static func dateKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    static func date(from key: String) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: key)
    }

    static func timeText(minutes: Int) -> String {
        let hour24 = minutes / 60
        let minute = minutes % 60
        let suffix = hour24 >= 12 ? "PM" : "AM"
        let hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12
        return String(format: "%d:%02d %@", hour12, minute, suffix)
    }
}

enum ResponseDatePreference {
    private static let keyPrefix = "ResponseDatePreference."

    static func date(for clubId: String?) -> Date {
        guard let clubId,
              let savedDate = UserDefaults.standard.object(forKey: keyPrefix + clubId) as? Date
        else {
            return ClubSchedule.startOfDay(for: Date())
        }

        return ClubSchedule.startOfDay(for: savedDate)
    }

    static func set(_ date: Date, for clubId: String) {
        UserDefaults.standard.set(
            ClubSchedule.startOfDay(for: date),
            forKey: keyPrefix + clubId
        )
    }
}
