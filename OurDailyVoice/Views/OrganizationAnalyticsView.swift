import SwiftUI

struct OrganizationClubData: Identifiable {
    let site: Site
    let sessions: [SessionDay]

    var id: String { site.id }
}

struct OrganizationAnalyticsContainerView: View {
    @State private var clubData: [OrganizationClubData] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var warningMessage: String?

    private let service = MoodService()

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ZStack {
                        Theme.bgGradient.ignoresSafeArea()
                        ProgressView("Loading organization data...")
                            .tint(.white)
                            .foregroundStyle(.white)
                    }
                } else if let errorMessage {
                    ZStack {
                        Theme.bgGradient.ignoresSafeArea()
                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.largeTitle)
                            Text("Organization data could not be loaded")
                                .font(.title2.weight(.bold))
                            Text(errorMessage)
                                .multilineTextAlignment(.center)
                            Button("Try Again") {
                                Task { await load() }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.white.opacity(0.25))
                        }
                        .foregroundStyle(.white)
                        .padding(32)
                    }
                } else {
                    OrganizationAnalyticsView(
                        clubData: clubData,
                        warningMessage: warningMessage
                    )
                }
            }
        }
        .task { await load() }
    }

    @MainActor
    private func load() async {
        isLoading = true
        errorMessage = nil
        warningMessage = nil

        do {
            let clubs = try await service.fetchClubs()
            var loadedData: [OrganizationClubData] = []
            var failedClubNames: [String] = []

            for club in clubs {
                do {
                    let sessions = try await service.fetchAllSessionDays(clubId: club.id)
                    loadedData.append(
                        OrganizationClubData(
                            site: Site(id: club.id, name: club.name, rooms: club.rooms),
                            sessions: sessions
                        )
                    )
                } catch {
                    failedClubNames.append(club.name)
                }
            }

            clubData = loadedData.sorted {
                $0.site.name.localizedCaseInsensitiveCompare($1.site.name) == .orderedAscending
            }

            if !failedClubNames.isEmpty {
                warningMessage = "Some club data could not be loaded: \(failedClubNames.joined(separator: ", "))."
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

struct OrganizationAnalyticsView: View {
    let clubData: [OrganizationClubData]
    let warningMessage: String?

    @State private var selectedStartDate: Date
    @State private var selectedEndDate: Date
    @State private var selectedClubIDs: Set<String> = []

    private let calendar = Calendar.current
    private let cardColumns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 2)

    init(clubData: [OrganizationClubData], warningMessage: String? = nil) {
        self.clubData = clubData
        self.warningMessage = warningMessage

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let monthStart = calendar.dateInterval(of: .month, for: today)?.start ?? today
        _selectedStartDate = State(initialValue: monthStart)
        _selectedEndDate = State(initialValue: today)
    }

    var body: some View {
        ZStack {
            Theme.bgGradient.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    titleSection

                    if let warningMessage {
                        warningCard(warningMessage)
                    }

                    filtersSection
                    overviewSection
                    moodSection
                    distributionSection
                    trendSection
                    clubBreakdownSection
                    dataNote
                }
                .padding(24)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle("Organization Analytics")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Organization-Wide Voice")
                .font(.system(size: 32, weight: .heavy))
                .foregroundStyle(.white)

            Text("Every response is weighted equally across all selected clubs.")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.82))
        }
    }

    private func warningCard(_ message: String) -> some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.orange.opacity(0.35))
            .clipShape(RoundedRectangle(cornerRadius: Theme.corner))
    }

    private var filtersSection: some View {
        section(title: "Filters") {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    DatePicker(
                        "From",
                        selection: Binding(
                            get: { selectedStartDate },
                            set: { newValue in
                                selectedStartDate = calendar.startOfDay(for: newValue)
                                if selectedStartDate > selectedEndDate {
                                    selectedEndDate = selectedStartDate
                                }
                            }
                        ),
                        displayedComponents: .date
                    )

                    DatePicker(
                        "To",
                        selection: Binding(
                            get: { selectedEndDate },
                            set: { newValue in
                                selectedEndDate = calendar.startOfDay(for: newValue)
                                if selectedEndDate < selectedStartDate {
                                    selectedStartDate = selectedEndDate
                                }
                            }
                        ),
                        displayedComponents: .date
                    )
                }
                .tint(.white)
                .font(.subheadline.weight(.semibold))

                VStack(alignment: .leading, spacing: 8) {
                    Text("Clubs")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.82))

                    clubSelector
                }
            }
            .analyticsCard()
        }
    }

    private var clubSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(title: "All Clubs", isSelected: selectedClubIDs.isEmpty) {
                    selectedClubIDs.removeAll()
                }

                ForEach(clubData) { club in
                    filterChip(
                        title: club.site.name,
                        isSelected: selectedClubIDs.contains(club.id)
                    ) {
                        if selectedClubIDs.contains(club.id) {
                            selectedClubIDs.remove(club.id)
                        } else {
                            selectedClubIDs.insert(club.id)
                        }
                    }
                }
            }
        }
    }

    private func filterChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(.white.opacity(isSelected ? 0.34 : 0.16))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(.white.opacity(isSelected ? 0.5 : 0.12), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var overviewSection: some View {
        section(title: "Overview") {
            LazyVGrid(columns: cardColumns, spacing: 12) {
                metricCard(title: "Total Responses", value: "\(totalResponses)")
                metricCard(title: "Estimated Check-ins", value: "\(estimatedCheckIns)")
                metricCard(title: "Active Clubs", value: "\(activeClubCount) of \(includedClubCount)")
                metricCard(title: "Active Days", value: "\(dailySummaries.count)")
            }
        }
    }

    private var moodSection: some View {
        section(title: "How Kids Are Feeling") {
            VStack(spacing: 0) {
                moodRow(label: "Overall Mood", value: average(allValues), detail: "All entry and exit responses")
                Divider().overlay(.white.opacity(0.14))
                moodRow(label: "Entry Average", value: average(enterValues), detail: "\(enterValues.count) responses")
                Divider().overlay(.white.opacity(0.14))
                moodRow(label: "Exit Average", value: average(leaveValues), detail: "\(leaveValues.count) responses")
                Divider().overlay(.white.opacity(0.14))
                moodChangeRow
            }
            .analyticsCard(padding: 0)
        }
    }

    private func moodRow(label: String, value: Double?, detail: String) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.72))
            }

            Spacer()

            Text(value.map { String(format: "%.1f / 9", $0) } ?? "—")
                .font(.title3.weight(.heavy))
                .foregroundStyle(.white)
        }
        .padding(16)
    }

    private var moodChangeRow: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Mood Change")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text("Exit average minus entry average")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.72))
            }

            Spacer()

            Text(moodChange.map(scoreLabel) ?? "—")
                .font(.title3.weight(.heavy))
                .foregroundStyle(moodChange.map(changeColor) ?? .white)
        }
        .padding(16)
    }

    private var distributionSection: some View {
        section(title: "Exact Mood Counts") {
            VStack(spacing: 12) {
                MoodDistributionCard(
                    title: "Combined Responses",
                    subtitle: "Entry and exit together",
                    values: allValues
                )

                MoodDistributionCard(
                    title: "Entry Responses",
                    subtitle: "How kids felt when they arrived",
                    values: enterValues
                )

                MoodDistributionCard(
                    title: "Exit Responses",
                    subtitle: "How kids felt when they left",
                    values: leaveValues
                )
            }
        }
    }

    private var trendSection: some View {
        section(title: "Daily Trend") {
            if dailySummaries.isEmpty {
                emptyCard("No responses were recorded for the selected filters.")
            } else {
                VStack(spacing: 0) {
                    ForEach(dailySummaries) { summary in
                        HStack(spacing: 12) {
                            Text(summary.day.formatted(.dateTime.month(.abbreviated).day()))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                                .frame(width: 70, alignment: .leading)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(summary.average.map { String(format: "Avg %.1f", $0) } ?? "Avg —")
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(.white)
                                Text("\(summary.responses) responses")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.72))
                            }

                            Spacer()

                            Text(summary.change.map(scoreLabel) ?? "—")
                                .font(.subheadline.weight(.heavy))
                                .foregroundStyle(summary.change.map(changeColor) ?? .white)
                        }
                        .padding(14)

                        if summary.id != dailySummaries.last?.id {
                            Divider().overlay(.white.opacity(0.12))
                        }
                    }
                }
                .analyticsCard(padding: 0)
            }
        }
    }

    private var clubBreakdownSection: some View {
        section(title: "Club Breakdown") {
            if clubSummaries.isEmpty {
                emptyCard("No club data is available for the selected filters.")
            } else {
                VStack(spacing: 12) {
                    ForEach(clubSummaries) { summary in
                        NavigationLink {
                            AdminAnalyticsView(
                                dailyScores: DailyAnalytics.from(sessions: summary.filteredSessions),
                                siteName: summary.club.site.name,
                                availableRooms: summary.club.site.rooms
                            )
                        } label: {
                            HStack(spacing: 14) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(summary.club.site.name)
                                        .font(.headline.weight(.bold))
                                        .foregroundStyle(.white)

                                    Text("\(summary.responses) responses • \(summary.estimatedCheckIns) estimated check-ins")
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.74))
                                }

                                Spacer()

                                VStack(alignment: .trailing, spacing: 5) {
                                    Text(summary.overallAverage.map { String(format: "%.1f / 9", $0) } ?? "—")
                                        .font(.subheadline.weight(.heavy))
                                        .foregroundStyle(.white)

                                    Text(summary.change.map(scoreLabel) ?? "—")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(summary.change.map(changeColor) ?? .white.opacity(0.7))
                                }

                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.white.opacity(0.75))
                            }
                            .analyticsCard()
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var dataNote: some View {
        Label(
            "Estimated check-ins use the larger of the entry or exit response count for each club session. Children are not individually identified.",
            systemImage: "info.circle"
        )
        .font(.caption)
        .foregroundStyle(.white.opacity(0.78))
        .padding(.horizontal, 4)
    }

    private func section<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 24, weight: .heavy))
                .foregroundStyle(.white)
            content()
        }
    }

    private func metricCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.82))
            Text(value)
                .font(.system(size: 27, weight: .heavy))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .analyticsCard()
    }

    private func emptyCard(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.82))
            .frame(maxWidth: .infinity, alignment: .leading)
            .analyticsCard()
    }

    // MARK: - Weighted calculations

    private var filteredClubData: [(club: OrganizationClubData, sessions: [SessionDay])] {
        let start = calendar.startOfDay(for: selectedStartDate)
        let end = calendar.startOfDay(for: selectedEndDate)

        return clubData.compactMap { club in
            guard selectedClubIDs.isEmpty || selectedClubIDs.contains(club.id) else { return nil }
            let sessions = club.sessions.filter { session in
                let day = calendar.startOfDay(for: session.day)
                return day >= start && day <= end
            }
            return (club, sessions)
        }
    }

    private var filteredSessions: [SessionDay] {
        filteredClubData.flatMap(\.sessions)
    }

    private var enterValues: [Int] {
        filteredSessions.flatMap(\.enterValues)
    }

    private var leaveValues: [Int] {
        filteredSessions.flatMap(\.leaveValues)
    }

    private var allValues: [Int] {
        enterValues + leaveValues
    }

    private var totalResponses: Int { allValues.count }

    private var estimatedCheckIns: Int {
        filteredSessions.reduce(0) { total, session in
            total + max(session.enterValues.count, session.leaveValues.count)
        }
    }

    private var includedClubCount: Int {
        selectedClubIDs.isEmpty ? clubData.count : selectedClubIDs.count
    }

    private var activeClubCount: Int {
        filteredClubData.filter { !$0.sessions.isEmpty }.count
    }

    private var moodChange: Double? {
        guard let enterAverage = average(enterValues), let leaveAverage = average(leaveValues) else { return nil }
        return leaveAverage - enterAverage
    }

    private var dailySummaries: [OrganizationDaySummary] {
        let grouped = Dictionary(grouping: filteredSessions) { calendar.startOfDay(for: $0.day) }

        return grouped.map { day, sessions in
            let entries = sessions.flatMap(\.enterValues)
            let exits = sessions.flatMap(\.leaveValues)
            let values = entries + exits
            let change: Double? = {
                guard let entryAverage = average(entries), let exitAverage = average(exits) else { return nil }
                return exitAverage - entryAverage
            }()

            return OrganizationDaySummary(
                day: day,
                responses: values.count,
                average: average(values),
                change: change
            )
        }
        .sorted { $0.day > $1.day }
    }

    private var clubSummaries: [OrganizationClubSummary] {
        filteredClubData.compactMap { club, sessions in
            let entries = sessions.flatMap(\.enterValues)
            let exits = sessions.flatMap(\.leaveValues)
            let values = entries + exits
            guard !values.isEmpty else { return nil }

            let estimated = sessions.reduce(0) {
                $0 + max($1.enterValues.count, $1.leaveValues.count)
            }
            let change: Double? = {
                guard let entryAverage = average(entries), let exitAverage = average(exits) else { return nil }
                return exitAverage - entryAverage
            }()

            return OrganizationClubSummary(
                club: club,
                filteredSessions: sessions,
                responses: values.count,
                estimatedCheckIns: estimated,
                overallAverage: average(values),
                change: change
            )
        }
        .sorted {
            if $0.responses == $1.responses {
                return $0.club.site.name.localizedCaseInsensitiveCompare($1.club.site.name) == .orderedAscending
            }
            return $0.responses > $1.responses
        }
    }

    private func average(_ values: [Int]) -> Double? {
        guard !values.isEmpty else { return nil }
        return Double(values.reduce(0, +)) / Double(values.count)
    }

    private func scoreLabel(_ value: Double) -> String {
        let text = String(format: "%.1f", value)
        return value > 0 ? "+\(text)" : text
    }

    private func changeColor(_ value: Double) -> Color {
        if value > 0 { return .green }
        if value < 0 { return .orange }
        return .white
    }
}

private struct OrganizationDaySummary: Identifiable {
    let day: Date
    let responses: Int
    let average: Double?
    let change: Double?

    var id: Date { day }
}

private struct OrganizationClubSummary: Identifiable {
    let club: OrganizationClubData
    let filteredSessions: [SessionDay]
    let responses: Int
    let estimatedCheckIns: Int
    let overallAverage: Double?
    let change: Double?

    var id: String { club.id }
}

private extension View {
    func analyticsCard(padding: CGFloat = 16) -> some View {
        self
            .padding(padding)
            .background(.white.opacity(Theme.cardOpacity))
            .clipShape(RoundedRectangle(cornerRadius: Theme.corner))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.corner)
                    .stroke(.white.opacity(0.14), lineWidth: 1)
            )
    }
}
