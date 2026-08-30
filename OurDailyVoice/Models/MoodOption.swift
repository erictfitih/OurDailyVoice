import Foundation

struct MoodOption: Identifiable, Hashable {
    let emoji: String
    let value: Int
    let displayNumber: String
    let label: String

    var id: Int { value }
}

struct TemporaryMoodPalette: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var startDateKey: String
    var endDateKey: String
    var emojis: [String]
    var displayNumbers: [String]
    var displayNames: [String]

    init(
        id: String,
        name: String,
        startDateKey: String,
        endDateKey: String,
        emojis: [String],
        displayNumbers: [String] = MoodPalette.defaultDisplayNumbers,
        displayNames: [String] = MoodPalette.defaultDisplayNames
    ) {
        self.id = id
        self.name = name
        self.startDateKey = startDateKey
        self.endDateKey = endDateKey
        self.emojis = emojis
        self.displayNumbers = displayNumbers
        self.displayNames = displayNames
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, startDateKey, endDateKey, emojis, displayNumbers, displayNames
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        startDateKey = try container.decode(String.self, forKey: .startDateKey)
        endDateKey = try container.decode(String.self, forKey: .endDateKey)
        emojis = try container.decode([String].self, forKey: .emojis)
        displayNumbers = try container.decodeIfPresent([String].self, forKey: .displayNumbers)
            ?? MoodPalette.defaultDisplayNumbers
        displayNames = try container.decodeIfPresent([String].self, forKey: .displayNames)
            ?? MoodPalette.defaultDisplayNames
    }
}

struct ClubMoodPaletteConfiguration: Codable, Equatable {
    var regularEmojis: [String]
    var regularDisplayNumbers: [String]
    var regularDisplayNames: [String]
    var temporaryPalettes: [TemporaryMoodPalette]

    init(
        regularEmojis: [String],
        regularDisplayNumbers: [String] = MoodPalette.defaultDisplayNumbers,
        regularDisplayNames: [String] = MoodPalette.defaultDisplayNames,
        temporaryPalettes: [TemporaryMoodPalette]
    ) {
        self.regularEmojis = regularEmojis
        self.regularDisplayNumbers = regularDisplayNumbers
        self.regularDisplayNames = regularDisplayNames
        self.temporaryPalettes = temporaryPalettes
    }

    static let standard = ClubMoodPaletteConfiguration(
        regularEmojis: MoodPalette.defaultEmojis,
        regularDisplayNumbers: MoodPalette.defaultDisplayNumbers,
        regularDisplayNames: MoodPalette.defaultDisplayNames,
        temporaryPalettes: []
    )

    private enum CodingKeys: String, CodingKey {
        case regularEmojis, regularDisplayNumbers, regularDisplayNames, temporaryPalettes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        regularEmojis = try container.decode([String].self, forKey: .regularEmojis)
        regularDisplayNumbers = try container.decodeIfPresent([String].self, forKey: .regularDisplayNumbers)
            ?? MoodPalette.defaultDisplayNumbers
        regularDisplayNames = try container.decodeIfPresent([String].self, forKey: .regularDisplayNames)
            ?? MoodPalette.defaultDisplayNames
        temporaryPalettes = try container.decodeIfPresent([TemporaryMoodPalette].self, forKey: .temporaryPalettes) ?? []
    }
}

enum MoodPalette {
    static let defaultEmojis = ["😢", "😞", "🙁", "😐", "🙂", "😊", "😄", "🤩", "🔥"]
    static let defaultDisplayNumbers = (1...9).map(String.init)
    static let defaultDisplayNames = ["Awful", "Very Bad", "Bad", "Meh", "Okay", "Good", "Great", "Amazing", "On Fire"]
    static let labels = defaultDisplayNames

    private static let cacheKeyPrefix = "ClubMoodPaletteConfiguration."

    static let options: [MoodOption] = makeOptions(
        emojis: defaultEmojis,
        displayNumbers: defaultDisplayNumbers,
        displayNames: defaultDisplayNames
    )

    static func options(for clubId: String?, at date: Date = Date()) -> [MoodOption] {
        guard let clubId else { return options }
        let configuration = cachedConfiguration(for: clubId)
        let dateKey = ClubSchedule.dateKey(for: date)
        let temporary = configuration.temporaryPalettes.last {
            $0.startDateKey <= dateKey && dateKey <= $0.endDateKey
        }

        return makeOptions(
            emojis: temporary?.emojis ?? configuration.regularEmojis,
            displayNumbers: temporary?.displayNumbers ?? configuration.regularDisplayNumbers,
            displayNames: temporary?.displayNames ?? configuration.regularDisplayNames
        )
    }

    static func cachedConfiguration(for clubId: String?) -> ClubMoodPaletteConfiguration {
        guard
            let clubId,
            let data = UserDefaults.standard.data(forKey: cacheKeyPrefix + clubId),
            let configuration = try? JSONDecoder().decode(ClubMoodPaletteConfiguration.self, from: data),
            isValid(configuration.regularEmojis),
            isValidDisplayText(configuration.regularDisplayNumbers),
            isValidDisplayText(configuration.regularDisplayNames),
            configuration.temporaryPalettes.allSatisfy({
                isValid($0.emojis) &&
                isValidDisplayText($0.displayNumbers) &&
                isValidDisplayText($0.displayNames)
            })
        else {
            return .standard
        }

        return configuration
    }

    static func cache(_ configuration: ClubMoodPaletteConfiguration, for clubId: String) {
        guard let data = try? JSONEncoder().encode(configuration) else { return }
        UserDefaults.standard.set(data, forKey: cacheKeyPrefix + clubId)
    }

    static func isValid(_ emojis: [String]) -> Bool {
        emojis.count == 9 && emojis.allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    static func isValidDisplayText(_ values: [String]) -> Bool {
        values.count == 9 && values.allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    static func singleSymbol(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.first.map(String.init) ?? ""
    }

    static func shortDisplayText(from text: String, maximumCharacters: Int) -> String {
        let singleLine = text.replacingOccurrences(of: "\n", with: " ")
        return String(singleLine.prefix(maximumCharacters))
    }

    private static func makeOptions(
        emojis: [String],
        displayNumbers: [String],
        displayNames: [String]
    ) -> [MoodOption] {
        let safeEmojis = isValid(emojis) ? emojis : defaultEmojis
        let safeNumbers = isValidDisplayText(displayNumbers) ? displayNumbers : defaultDisplayNumbers
        let safeNames = isValidDisplayText(displayNames) ? displayNames : defaultDisplayNames

        return (0..<9).map { index in
            MoodOption(
                emoji: safeEmojis[index],
                value: index + 1,
                displayNumber: safeNumbers[index],
                label: safeNames[index]
            )
        }
    }
}
