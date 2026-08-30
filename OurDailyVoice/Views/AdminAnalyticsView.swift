import SwiftUI

enum AnalyticsKind {
    case enterOnly
    case leaveOnly
    case none
}

struct DailyAnalytics: Identifiable {
    let id = UUID()
    let day: Date
    let score: Double
    let kind: AnalyticsKind
    let youthsServed: Int
    let durationText: String
    let roomName: String
    let enterValues: [Int]
    let leaveValues: [Int]

    init(
        day: Date,
        score: Double,
        kind: AnalyticsKind,
        youthsServed: Int,
        durationText: String,
        roomName: String,
        enterValues: [Int] = [],
        leaveValues: [Int] = []
    ) {
        self.day = day
        self.score = score
        self.kind = kind
        self.youthsServed = youthsServed
        self.durationText = durationText
        self.roomName = roomName
        self.enterValues = enterValues
        self.leaveValues = leaveValues
    }
}

extension DailyAnalytics {
    static func from(sessions: [SessionDay]) -> [DailyAnalytics] {
        sessions.map { session in
            let enterAverage = average(of: session.enterValues)
            let leaveAverage = average(of: session.leaveValues)
            let youthsServed = max(session.enterValues.count, session.leaveValues.count)
            let duration = formattedDuration(
                from: averageDate(session.enterTimestamps),
                to: averageDate(session.leaveTimestamps)
            )

            switch (enterAverage, leaveAverage) {
            case let (enter?, leave?):
                return DailyAnalytics(
                    day: session.day,
                    score: leave - enter,
                    kind: .none,
                    youthsServed: youthsServed,
                    durationText: duration,
                    roomName: session.room,
                    enterValues: session.enterValues,
                    leaveValues: session.leaveValues
                )
            case let (enter?, nil):
                return DailyAnalytics(
                    day: session.day,
                    score: enter,
                    kind: .enterOnly,
                    youthsServed: youthsServed,
                    durationText: duration,
                    roomName: session.room,
                    enterValues: session.enterValues,
                    leaveValues: session.leaveValues
                )
            case let (nil, leave?):
                return DailyAnalytics(
                    day: session.day,
                    score: -leave,
                    kind: .leaveOnly,
                    youthsServed: youthsServed,
                    durationText: duration,
                    roomName: session.room,
                    enterValues: session.enterValues,
                    leaveValues: session.leaveValues
                )
            case (nil, nil):
                return DailyAnalytics(
                    day: session.day,
                    score: 0,
                    kind: .none,
                    youthsServed: youthsServed,
                    durationText: duration,
                    roomName: session.room,
                    enterValues: session.enterValues,
                    leaveValues: session.leaveValues
                )
            }
        }
    }

    private static func average(of values: [Int]) -> Double? {
        guard !values.isEmpty else { return nil }
        return Double(values.reduce(0, +)) / Double(values.count)
    }

    private static func averageDate(_ dates: [Date]) -> Date? {
        guard !dates.isEmpty else { return nil }
        let average = dates.map(\.timeIntervalSince1970).reduce(0, +) / Double(dates.count)
        return Date(timeIntervalSince1970: average)
    }

    private static func formattedDuration(from start: Date?, to end: Date?) -> String {
        guard let start, let end else { return "—" }
        let duration = end.timeIntervalSince(start)
        guard duration >= 0 else { return "—" }

        let totalMinutes = Int(duration / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
    }
}

struct RoomSummary: Identifiable {
    let id = UUID()
    let room: String
    let youths: Int
    let avgScore: Double?
    let avgDurationMinutes: Double?
    let days: Int
}

struct AdminAnalyticsView: View {
    let dailyScores: [DailyAnalytics]
    let siteName: String
    let availableRooms: [String]

    @State private var currentMonth: Date
    @State private var selectedStartDate: Date
    @State private var selectedEndDate: Date
    @State private var selectedRooms: Set<String> = []

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 7)
    private let dashboardColumns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 2)

    private let uiScale: CGFloat = 1.08

    init(
        dailyScores: [DailyAnalytics],
        siteName: String,
        availableRooms: [String]
    ) {
        self.dailyScores = dailyScores
        self.siteName = siteName
        self.availableRooms = availableRooms

        let calendar = Calendar.current
        let defaultEnd = calendar.startOfDay(for: Date())
        let defaultStart = calendar.dateInterval(of: .month, for: defaultEnd)?.start ?? defaultEnd

        _selectedStartDate = State(initialValue: defaultStart)
        _selectedEndDate = State(initialValue: defaultEnd)
        _currentMonth = State(initialValue: defaultStart)
    }

    var body: some View {
        ZStack {
            Theme.bgGradient
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 40) {
                    filtersSection
                    kpiSection
                    moodDistributionSection
                    trendSection
                    calendarSection
                    roomBreakdownSection
                }
                .padding()
            }
        }
        .navigationTitle("Analytics")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var isPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }

    private func scaledFont(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let deviceScale: CGFloat = isPad ? 1.08 : 0.94
        return .system(size: size * uiScale * deviceScale, weight: weight)
    }

    // MARK: - Filters

    private var filtersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Filters")
                .font(scaledFont(28, weight: .heavy))
                .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Site")
                        .font(scaledFont(12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))

                    Text(siteName)
                        .font(scaledFont(17, weight: .bold))
                        .foregroundStyle(.white)
                }

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
                .font(scaledFont(14, weight: .medium))

                VStack(alignment: .leading, spacing: 8) {
                    Text("Rooms")
                        .font(scaledFont(12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))

                    roomSelector
                }
            }
            .padding(16)
            .background(.white.opacity(Theme.cardOpacity))
            .clipShape(RoundedRectangle(cornerRadius: Theme.corner))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.corner)
                    .stroke(.white.opacity(0.14), lineWidth: 1)
            )
        }
    }

    private var roomSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Button {
                    if selectedRooms.count == availableRooms.count {
                        selectedRooms.removeAll()
                    } else {
                        selectedRooms = Set(availableRooms)
                    }
                } label: {
                    Text(selectedRooms.count == availableRooms.count ? "Clear All" : "All Rooms")
                        .font(scaledFont(12, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.white.opacity(selectedRooms.isEmpty ? 0.30 : 0.22))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                ForEach(availableRooms, id: \.self) { room in
                    Button {
                        if selectedRooms.contains(room) {
                            selectedRooms.remove(room)
                        } else {
                            selectedRooms.insert(room)
                        }
                    } label: {
                        Text(room)
                            .font(scaledFont(12, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                selectedRooms.contains(room)
                                    ? .white.opacity(0.34)
                                    : .white.opacity(0.18)
                            )
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(.white.opacity(selectedRooms.contains(room) ? 0.45 : 0.14), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Data

    private var filteredEntries: [DailyAnalytics] {
        let start = calendar.startOfDay(for: selectedStartDate)
        let end = calendar.startOfDay(for: selectedEndDate)

        return dailyScores.filter { entry in
            let day = calendar.startOfDay(for: entry.day)
            let matchesDate = day >= start && day <= end
            let matchesRoom = selectedRooms.isEmpty || selectedRooms.contains(entry.roomName)
            return matchesDate && matchesRoom
        }
    }

    private var totalYouthsServed: Int {
        filteredEntries.reduce(0) { $0 + $1.youthsServed }
    }

    private var filteredEnterValues: [Int] {
        filteredEntries.flatMap(\.enterValues)
    }

    private var filteredLeaveValues: [Int] {
        filteredEntries.flatMap(\.leaveValues)
    }

    private var filteredCombinedValues: [Int] {
        filteredEnterValues + filteredLeaveValues
    }

    private var averageScore: Double? {
        guard !filteredEntries.isEmpty else { return nil }
        let total = filteredEntries.reduce(0.0) { $0 + $1.score }
        return total / Double(filteredEntries.count)
    }

    private var averageDurationMinutes: Double? {
        let durations = filteredEntries.compactMap { parseDurationMinutes($0.durationText) }
        guard !durations.isEmpty else { return nil }
        return durations.reduce(0, +) / Double(durations.count)
    }

    private var activeDaysCount: Int {
        filteredEntries.count
    }

    private var enterOnlyCount: Int {
        filteredEntries.filter { $0.kind == .enterOnly }.count
    }

    private var leaveOnlyCount: Int {
        filteredEntries.filter { $0.kind == .leaveOnly }.count
    }

    private var bestDay: DailyAnalytics? {
        filteredEntries.max { $0.score < $1.score }
    }

    private var lowestDay: DailyAnalytics? {
        filteredEntries.min { $0.score < $1.score }
    }

    private var roomSummaries: [RoomSummary] {
        let grouped = Dictionary(grouping: filteredEntries, by: { $0.roomName })

        return grouped.map { room, entries in
            let totalYouths = entries.reduce(0) { $0 + $1.youthsServed }

            let avgScore: Double? = {
                guard !entries.isEmpty else { return nil }
                let total = entries.reduce(0.0) { $0 + $1.score }
                return total / Double(entries.count)
            }()

            let durations = entries.compactMap { parseDurationMinutes($0.durationText) }
            let avgDuration = durations.isEmpty ? nil : durations.reduce(0, +) / Double(durations.count)

            return RoomSummary(
                room: room,
                youths: totalYouths,
                avgScore: avgScore,
                avgDurationMinutes: avgDuration,
                days: entries.count
            )
        }
        .sorted { $0.room.localizedCaseInsensitiveCompare($1.room) == .orderedAscending }
    }

    // MARK: - Sections

    private var kpiSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Overview")
                .font(scaledFont(28, weight: .heavy))
                .foregroundStyle(.white)

            LazyVGrid(columns: dashboardColumns, spacing: 12) {
                dashboardCard(
                    title: "Youths Served",
                    value: "\(totalYouthsServed)",
                    subtitle: ""
                )

                dashboardCard(
                    title: "Avg Mood Change",
                    value: averageScore.map { scoreLabel($0) } ?? "—",
                    subtitle: ""
                )

                dashboardCard(
                    title: "Avg Duration",
                    value: averageDurationMinutes.map { formatDuration(minutes: $0) } ?? "—",
                    subtitle: ""
                )

                dashboardCard(
                    title: "Active Days",
                    value: "\(activeDaysCount)",
                    subtitle: ""
                )
            }
        }
    }

    private func dashboardCard(title: String, value: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(scaledFont(12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.86))

            Text(value)
                .font(scaledFont(28, weight: .heavy))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(subtitle)
                .font(scaledFont(12))
                .foregroundStyle(.white.opacity(0.72))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.white.opacity(Theme.cardOpacity))
        .clipShape(RoundedRectangle(cornerRadius: Theme.corner))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.corner)
                .stroke(.white.opacity(0.14), lineWidth: 1)
        )
    }

    private var moodDistributionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Exact Mood Counts")
                .font(scaledFont(28, weight: .heavy))
                .foregroundStyle(.white)

            Text("Exact emoji selections for the current date and room filters.")
                .font(scaledFont(13, weight: .medium))
                .foregroundStyle(.white.opacity(0.8))

            MoodDistributionCard(
                title: "Combined Responses",
                subtitle: "Entry and exit together",
                values: filteredCombinedValues
            )

            MoodDistributionCard(
                title: "Entry Responses",
                subtitle: "How kids felt when they arrived",
                values: filteredEnterValues
            )

            MoodDistributionCard(
                title: "Exit Responses",
                subtitle: "How kids felt when they left",
                values: filteredLeaveValues
            )
        }
    }

    private var trendSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Trend Summary")
                .font(scaledFont(20, weight: .heavy))
                .foregroundStyle(.white)

            VStack(spacing: 10) {
                statRow(
                    label: "Best Day",
                    value: bestDay.map { "\(formattedShortDate($0.day)) • \(scoreLabel($0.score))" } ?? "—"
                )

                statRow(
                    label: "Lowest Day",
                    value: lowestDay.map { "\(formattedShortDate($0.day)) • \(scoreLabel($0.score))" } ?? "—"
                )

                statRow(label: "Enter-Only Days", value: "\(enterOnlyCount)")
                statRow(label: "Leave-Only Days", value: "\(leaveOnlyCount)")
            }
            .padding(16)
            .background(.white.opacity(Theme.cardOpacity))
            .clipShape(RoundedRectangle(cornerRadius: Theme.corner))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.corner)
                    .stroke(.white.opacity(0.14), lineWidth: 1)
            )
        }
    }

    private func statRow(label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(label)
                .font(scaledFont(15, weight: .semibold))
                .foregroundStyle(.white.opacity(0.86))

            Spacer()

            Text(value)
                .font(scaledFont(15, weight: .bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.trailing)
        }
    }

    private var calendarSection: some View {
        let metrics = calendarMetrics(for: calendarAvailableWidth)

        return VStack(alignment: .leading, spacing: 26) {
             Text("Calendar")
                 .font(scaledFont(28, weight: .heavy))
                 .foregroundStyle(.white)
                 .padding(.bottom, 22)

            VStack(spacing: metrics.stackSpacing) {
                header
                    .frame(height: isPad ? 42 : 36)

                weekdayHeader
                    .frame(height: 20)

                monthGrid(cellHeight: metrics.cellHeight)

                legend
                    .frame(minHeight: 48)
            }
            .padding(.horizontal, metrics.innerPadding)
            .padding(.top, metrics.topPadding)
            .padding(.bottom, metrics.innerPadding)
            .background(.white.opacity(Theme.cardOpacity))
            .clipShape(RoundedRectangle(cornerRadius: Theme.corner))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.corner)
                    .stroke(.white.opacity(0.14), lineWidth: 1)
            )
            .frame(height: metrics.totalHeight)
        }
        .padding(.bottom, 20)
    }
    
    private var calendarAvailableWidth: CGFloat {
        let screenWidth = UIScreen.main.bounds.width
        let outerPadding: CGFloat = 32
        return max(screenWidth - outerPadding, 0)
    }

    private func calendarMetrics(for availableWidth: CGFloat) -> CalendarMetrics {
        let innerPadding: CGFloat = 16
        let gridSpacing: CGFloat = 12
        let topPadding: CGFloat = 16
        let weeks = max(1, daysForMonthGrid().count / 7)

        let contentWidth = max(availableWidth - (innerPadding * 2), 0)
        let totalGridSpacing = gridSpacing * 6
        let cellWidth = (contentWidth - totalGridSpacing) / 7

        let cellHeight = isPad
            ? max(cellWidth * 1.18, 110)
            : max(cellWidth * 1.06, 76)

        let rowSpacing = CGFloat(max(0, weeks - 1)) * gridSpacing

        let headerHeight: CGFloat = isPad ? 42 : 36
        let weekdayHeight: CGFloat = 20
        let legendHeight: CGFloat = 48
        let stackSpacing: CGFloat = 20

        let totalHeight =
            topPadding +
            headerHeight +
            stackSpacing +
            weekdayHeight +
            stackSpacing +
            (CGFloat(weeks) * cellHeight) +
            rowSpacing +
            stackSpacing +
            legendHeight +
            (innerPadding * 2)

        return CalendarMetrics(
            cellHeight: cellHeight,
            totalHeight: totalHeight,
            stackSpacing: stackSpacing,
            innerPadding: innerPadding,
            topPadding: topPadding
        )
    }

    private struct CalendarMetrics {
        let cellHeight: CGFloat
        let totalHeight: CGFloat
        let stackSpacing: CGFloat
        let innerPadding: CGFloat
        let topPadding: CGFloat
    }
    
    private func monthGrid(cellHeight: CGFloat) -> some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(daysForMonthGrid(), id: \.self) { date in
                dayCell(for: date, cellHeight: cellHeight)
            }
        }
    }

    private var roomBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Room Breakdown")
                .font(scaledFont(28, weight: .heavy))
                .foregroundStyle(.white)
                .padding(.bottom, 8)

            if roomSummaries.isEmpty {
                Text("No room data for the selected filters.")
                    .font(scaledFont(15))
                    .foregroundStyle(.white.opacity(0.84))
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.white.opacity(Theme.cardOpacity))
                    .clipShape(RoundedRectangle(cornerRadius: Theme.corner))
            } else {
                VStack(spacing: 10) {
                    ForEach(roomSummaries) { summary in
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(summary.room)
                                    .font(scaledFont(17, weight: .bold))
                                    .foregroundStyle(.white)

                                Text("\(summary.days) active days")
                                    .font(scaledFont(12))
                                    .foregroundStyle(.white.opacity(0.76))
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 4) {
                                Text("\(summary.youths) youths")
                                    .font(scaledFont(15, weight: .heavy))
                                    .foregroundStyle(.white)

                                Text(summary.avgScore.map { "Avg \(scoreLabel($0))" } ?? "Avg —")
                                    .font(scaledFont(12))
                                    .foregroundStyle(.white.opacity(0.8))

                                Text(summary.avgDurationMinutes.map { formatDuration(minutes: $0) } ?? "—")
                                    .font(scaledFont(12))
                                    .foregroundStyle(.white.opacity(0.8))
                            }
                        }
                        .padding(14)
                        .background(.white.opacity(Theme.cardOpacity))
                        .clipShape(RoundedRectangle(cornerRadius: Theme.corner))
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.corner)
                                .stroke(.white.opacity(0.14), lineWidth: 1)
                        )
                    }
                }
            }
        }
        .padding(.top, 4)
    }

    // MARK: - Calendar Components

    private var header: some View {
        let buttonSide: CGFloat = isPad ? 42 : 36

        return ZStack {
            Text(monthTitle(for: currentMonth))
                .font(scaledFont(22, weight: .heavy))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, alignment: .center)
                .frame(height: buttonSide, alignment: .center)

            HStack {
                Button {
                    changeMonth(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(scaledFont(18, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: buttonSide, height: buttonSide)
                        .background(.white.opacity(0.18))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    changeMonth(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(scaledFont(18, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: buttonSide, height: buttonSide)
                        .background(.white.opacity(0.18))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(height: buttonSide, alignment: .center)
    }

    private var weekdayHeader: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(calendar.shortWeekdaySymbols, id: \.self) { day in
                Text(day)
                    .font(scaledFont(12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.82))
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var legend: some View {
        VStack(spacing: 10) {
            HStack(spacing: 18) {
                legendItem(color: .green, label: "Positive")
                legendItem(color: .red, label: "Negative")
            }

            HStack(spacing: 18) {
                smallSymbolLegend(systemName: "arrow.right.circle.fill", color: .blue, label: "Enter Only")
                smallSymbolLegend(systemName: "arrow.left.circle.fill", color: .orange, label: "Leave Only")
            }
        }
        .padding(.top, 8)
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)

            Text(label)
                .font(scaledFont(12))
                .foregroundStyle(.white.opacity(0.8))
        }
    }

    private func smallSymbolLegend(systemName: String, color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemName)
                .foregroundStyle(color)

            Text(label)
                .font(scaledFont(12))
                .foregroundStyle(.white.opacity(0.8))
        }
    }

    @ViewBuilder
    private func indicator(for kind: AnalyticsKind) -> some View {
        switch kind {
        case .enterOnly:
            Image(systemName: "arrow.right.circle.fill")
                .font(scaledFont(10))
                .foregroundStyle(.blue)
        case .leaveOnly:
            Image(systemName: "arrow.left.circle.fill")
                .font(scaledFont(10))
                .foregroundStyle(.orange)
        case .none:
            EmptyView()
        }
    }

    @ViewBuilder
    private func dayCell(for date: Date, cellHeight: CGFloat) -> some View {
        let isInCurrentMonth = calendar.isDate(date, equalTo: currentMonth, toGranularity: .month)
        let dayNumber = calendar.component(.day, from: date)
        let analytics = analyticsForDate(date)

        let compact = cellHeight < 95
        let dayFont: CGFloat = compact ? 12 : 15
        let badgeFont: CGFloat = compact ? 9 : 12
        let metaFont: CGFloat = compact ? 8 : 10
        let innerPadding: CGFloat = compact ? 6 : 10
        let verticalSpacing: CGFloat = compact ? 4 : 8

        VStack(spacing: verticalSpacing) {
            HStack(spacing: 4) {
                Text("\(dayNumber)")
                    .font(scaledFont(dayFont, weight: .bold))
                    .foregroundStyle(.white)

                if let analytics {
                    indicator(for: analytics.kind)
                }
            }

            if let analytics {
                Text(scoreLabel(analytics.score))
                    .font(scaledFont(badgeFont, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, compact ? 6 : 8)
                    .padding(.vertical, compact ? 3 : 4)
                    .background(
                        Capsule().fill(scoreColor(analytics.score))
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                VStack(spacing: 2) {
                    Text("\(analytics.youthsServed) youths")
                        .font(scaledFont(metaFont, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)

                    Text(analytics.durationText)
                        .font(scaledFont(metaFont, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .lineLimit(compact ? 1 : 2)
                        .minimumScaleFactor(0.65)
                }
            } else {
                Text("—")
                    .font(scaledFont(compact ? 10 : 12))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity, minHeight: cellHeight)
        .padding(innerPadding)
        .background(
            RoundedRectangle(cornerRadius: compact ? 12 : 16)
                .fill(cardFill(for: analytics?.score, isInCurrentMonth: isInCurrentMonth))
        )
        .overlay(
            RoundedRectangle(cornerRadius: compact ? 12 : 16)
                .stroke(borderColor(for: analytics?.kind), lineWidth: 2)
        )
        .opacity(isInCurrentMonth ? 1.0 : 0.35)
    }

    // MARK: - Helpers

    private func analyticsForDate(_ date: Date) -> DailyAnalytics? {
        let normalized = calendar.startOfDay(for: date)

        let matches = filteredEntries.filter {
            calendar.isDate($0.day, inSameDayAs: normalized)
        }

        guard !matches.isEmpty else { return nil }

        if matches.count == 1 {
            return matches[0]
        }

        let totalYouths = matches.reduce(0) { $0 + $1.youthsServed }
        let avgScore = matches.map(\.score).reduce(0, +) / Double(matches.count)

        return DailyAnalytics(
            day: normalized,
            score: avgScore,
            kind: .none,
            youthsServed: totalYouths,
            durationText: "Multiple",
            roomName: "All Rooms"
        )
    }

    private func scoreColor(_ score: Double) -> Color {
        if score > 0 { return .green }
        if score < 0 { return .red }
        return .gray
    }

    private func borderColor(for kind: AnalyticsKind?) -> Color {
        guard let kind else { return .white.opacity(0.08) }

        switch kind {
        case .enterOnly:
            return .blue.opacity(0.75)
        case .leaveOnly:
            return .orange.opacity(0.75)
        case .none:
            return .white.opacity(0.08)
        }
    }

    private func cardFill(for score: Double?, isInCurrentMonth: Bool) -> Color {
        guard isInCurrentMonth else {
            return .white.opacity(0.08)
        }

        guard let score else {
            return .white.opacity(0.15)
        }

        if score > 0 {
            return .green.opacity(0.28)
        } else if score < 0 {
            return .red.opacity(0.28)
        } else {
            return .white.opacity(0.20)
        }
    }

    private func scoreLabel(_ score: Double) -> String {
        let rounded = String(format: "%.1f", score)
        return score > 0 ? "+\(rounded)" : rounded
    }

    private func monthTitle(for date: Date) -> String {
        date.formatted(.dateTime.month(.wide).year())
    }

    private func formattedShortDate(_ date: Date) -> String {
        date.formatted(.dateTime.month(.abbreviated).day())
    }

    private func changeMonth(by value: Int) {
        guard let newMonth = calendar.date(byAdding: .month, value: value, to: currentMonth) else { return }
        currentMonth = newMonth
    }

    private func daysForMonthGrid() -> [Date] {
        guard
            let monthInterval = calendar.dateInterval(of: .month, for: currentMonth),
            let firstWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.start),
            let lastDay = calendar.date(byAdding: .day, value: -1, to: monthInterval.end),
            let lastWeek = calendar.dateInterval(of: .weekOfMonth, for: lastDay)
        else {
            return []
        }

        var dates: [Date] = []
        var current = firstWeek.start

        while current < lastWeek.end {
            dates.append(current)
            guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }

        return dates
    }

    private func parseDurationMinutes(_ text: String) -> Double? {
        guard text != "—" else { return nil }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: " ")

        if parts.count == 2,
           let hours = Int(parts[0].replacingOccurrences(of: "h", with: "")),
           let minutes = Int(parts[1].replacingOccurrences(of: "m", with: "")) {
            return Double(hours * 60 + minutes)
        }

        if parts.count == 1,
           let minutes = Int(parts[0].replacingOccurrences(of: "m", with: "")) {
            return Double(minutes)
        }

        return nil
    }

    private func formatDuration(minutes: Double) -> String {
        let totalMinutes = Int(minutes.rounded())
        let hours = totalMinutes / 60
        let remainingMinutes = totalMinutes % 60

        if hours > 0 {
            return "\(hours)h \(remainingMinutes)m"
        } else {
            return "\(remainingMinutes)m"
        }
    }
}

#Preview {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())

    let sampleScores: [DailyAnalytics] = [
        DailyAnalytics(
            day: today,
            score: 5.6,
            kind: .enterOnly,
            youthsServed: 24,
            durationText: "2h 10m",
            roomName: "Dreamerville"
        ),
        DailyAnalytics(
            day: calendar.date(byAdding: .day, value: -1, to: today)!,
            score: 6.0,
            kind: .enterOnly,
            youthsServed: 19,
            durationText: "1h 45m",
            roomName: "Dreamerville"
        ),
        DailyAnalytics(
            day: calendar.date(byAdding: .day, value: -2, to: today)!,
            score: 7.0,
            kind: .enterOnly,
            youthsServed: 21,
            durationText: "2h 00m",
            roomName: "Teen Tech Center"
        ),
        DailyAnalytics(
            day: calendar.date(byAdding: .day, value: -3, to: today)!,
            score: -8.5,
            kind: .leaveOnly,
            youthsServed: 17,
            durationText: "1h 20m",
            roomName: "Music Studio"
        ),
        DailyAnalytics(
            day: calendar.date(byAdding: .day, value: -7, to: today)!,
            score: -2.1,
            kind: .none,
            youthsServed: 15,
            durationText: "—",
            roomName: "Dreamerville"
        )
    ]

    NavigationStack {
        AdminAnalyticsView(
            dailyScores: sampleScores,
            siteName: "Andrew Jackson",
            availableRooms: [
                "Dreamerville",
                "Teen Tech Center",
                "Music Studio",
                "Art Room"
            ]
        )
    }
}
