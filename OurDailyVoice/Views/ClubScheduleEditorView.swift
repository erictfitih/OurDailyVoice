import SwiftUI

struct ClubScheduleEditorView: View {
    let site: Site

    @State private var configuration: ClubScheduleConfiguration
    @State private var paletteConfiguration: ClubMoodPaletteConfiguration
    @State private var isUnlocked = false
    @State private var pin = ""
    @State private var pinError: String?
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var message: String?
    @State private var responseDate: Date

    @State private var exceptionDate = Date()
    @State private var exceptionEntryMinutes = 6 * 60 + 45
    @State private var exceptionExitMinutes = 12 * 60

    @State private var temporaryPaletteName = ""
    @State private var temporaryStartDate = Date()
    @State private var temporaryEndDate = Date()
    @State private var temporaryEmojis = MoodPalette.defaultEmojis
    @State private var temporaryDisplayNumbers = MoodPalette.defaultDisplayNumbers
    @State private var temporaryDisplayNames = MoodPalette.defaultDisplayNames

    private let service = MoodService()

    init(site: Site) {
        self.site = site
        _configuration = State(initialValue: ClubSchedule.cachedConfiguration(for: site.id))
        _paletteConfiguration = State(initialValue: MoodPalette.cachedConfiguration(for: site.id))
        _responseDate = State(initialValue: ResponseDatePreference.date(for: site.id))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bgGradient.ignoresSafeArea()

                if !isUnlocked {
                    pinScreen
                } else if isLoading {
                    ProgressView("Loading \(site.name) settings...")
                        .tint(.white)
                        .foregroundStyle(.white)
                } else {
                    editor
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
        }
        .task(id: site.id) { await load() }
        .alert(
            "Settings",
            isPresented: Binding(
                get: { message != nil },
                set: { if !$0 { message = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(message ?? "")
        }
    }

    private var pinScreen: some View {
        VStack(spacing: 22) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 58))

            VStack(spacing: 7) {
                Text("Staff PIN Required")
                    .font(.largeTitle.weight(.heavy))
                Text("Enter the staff PIN to change \(site.name)'s schedule and emojis.")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.82))
            }

            SecureField("Staff PIN", text: $pin)
                .keyboardType(.numberPad)
                .textContentType(.password)
                .font(.title2.weight(.bold))
                .multilineTextAlignment(.center)
                .padding(16)
                .background(.white.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .frame(maxWidth: 380)

            if let pinError {
                Text(pinError)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.yellow)
            }

            Button {
                verifyPIN()
            } label: {
                Text("Unlock Settings")
                    .font(.headline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
            }
            .buttonStyle(.borderedProminent)
            .tint(.white.opacity(0.28))
            .frame(maxWidth: 380)
            .disabled(pin.isEmpty)
        }
        .foregroundStyle(.white)
        .padding(32)
    }

    private var editor: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(site.name)
                        .font(.system(size: 32, weight: .heavy))
                        .foregroundStyle(.white)
                    Text("Entry mode begins at the entry time and automatically changes to exit mode at the exit time.")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.82))
                }

                responseDateSection
                roomPromptTimingSection
                regularScheduleSection
                exceptionEditorSection
                savedExceptionsSection

                Divider()
                    .overlay(.white.opacity(0.24))
                    .padding(.vertical, 4)

                regularEmojiSection
                temporaryEmojiSection
                savedTemporaryPalettesSection

                Label(
                    "A one-day exception overrides the regular schedule only on that date. The regular schedule resumes automatically the next day.",
                    systemImage: "info.circle"
                )
                .font(.caption)
                .foregroundStyle(.white.opacity(0.8))
            }
            .padding(24)
            .padding(.bottom, 36)
        }
    }

    private var responseDateSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Emoji Response Date")
                .font(.title2.weight(.heavy))
                .foregroundStyle(.white)

            Text("This controls the date used when new emoji responses are recorded on this iPad.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.82))

            DatePicker("Response date", selection: $responseDate, displayedComponents: .date)
                .tint(.white)

            HStack(spacing: 12) {
                Button("Use Today") {
                    responseDate = ClubSchedule.startOfDay(for: Date())
                }
                .buttonStyle(.bordered)

                Button("Save Response Date") {
                    saveResponseDate()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .foregroundStyle(.white)
        .scheduleCard()
    }

    private var roomPromptTimingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Room Prompt Timing")
                .font(.title2.weight(.heavy))
                .foregroundStyle(.white)

            Text("Choose how often children in non-Front Rooms are asked whether they just came in or are heading out.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.82))

            Stepper(
                "Every \(configuration.roomPromptIntervalMinutes) minute\(configuration.roomPromptIntervalMinutes == 1 ? "" : "s")",
                value: $configuration.roomPromptIntervalMinutes,
                in: 1...120
            )
            .font(.headline)

            Button {
                Task { await saveRoomPromptTiming() }
            } label: {
                Label(isSaving ? "Saving..." : "Save Prompt Timing", systemImage: "timer")
                    .font(.headline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(.white.opacity(0.28))
            .disabled(isSaving)
        }
        .foregroundStyle(.white)
        .scheduleCard()
    }

    private var regularScheduleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Regular Schedule")
                .font(.title2.weight(.heavy))
                .foregroundStyle(.white)

            VStack(spacing: 18) {
                schedulePair(
                    title: "Summer Club",
                    subtitle: "May 26 – August 16",
                    entry: timeBinding(\.summerEntryStartMinutes),
                    exit: timeBinding(\.summerExitStartMinutes)
                )

                Divider().overlay(.white.opacity(0.15))

                schedulePair(
                    title: "School-Year Club",
                    subtitle: "August 17 – May 25",
                    entry: timeBinding(\.schoolYearEntryStartMinutes),
                    exit: timeBinding(\.schoolYearExitStartMinutes)
                )

                Button {
                    Task { await saveRegularSchedule() }
                } label: {
                    Label(isSaving ? "Saving..." : "Save Regular Schedule", systemImage: "checkmark.circle.fill")
                        .font(.headline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .tint(.white.opacity(0.28))
                .disabled(isSaving)
            }
            .scheduleCard()
        }
    }

    private func schedulePair(
        title: String,
        subtitle: String,
        entry: Binding<Date>,
        exit: Binding<Date>
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.72))
            }

            DatePicker("Entry begins", selection: entry, displayedComponents: .hourAndMinute)
            DatePicker("Exit begins", selection: exit, displayedComponents: .hourAndMinute)
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.white)
        .tint(.white)
    }

    private var exceptionEditorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("One-Day Exception")
                .font(.title2.weight(.heavy))
                .foregroundStyle(.white)

            VStack(spacing: 14) {
                DatePicker("Date", selection: $exceptionDate, displayedComponents: .date)
                DatePicker(
                    "Entry begins",
                    selection: exceptionTimeBinding($exceptionEntryMinutes),
                    displayedComponents: .hourAndMinute
                )
                DatePicker(
                    "Exit begins",
                    selection: exceptionTimeBinding($exceptionExitMinutes),
                    displayedComponents: .hourAndMinute
                )

                Button {
                    Task { await saveException() }
                } label: {
                    Label("Save One-Day Exception", systemImage: "calendar.badge.plus")
                        .font(.headline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .tint(.white.opacity(0.28))
                .disabled(isSaving)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .tint(.white)
            .scheduleCard()
        }
    }

    private var savedExceptionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Saved Exceptions")
                .font(.title2.weight(.heavy))
                .foregroundStyle(.white)

            if sortedExceptions.isEmpty {
                Text("No one-day exceptions have been saved.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .scheduleCard()
            } else {
                VStack(spacing: 10) {
                    ForEach(sortedExceptions) { exception in
                        HStack(spacing: 14) {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(exceptionDateText(exception.dateKey))
                                    .font(.headline.weight(.bold))
                                    .foregroundStyle(.white)
                                Text(
                                    "Entry \(ClubSchedule.timeText(minutes: exception.entryStartMinutes))  •  Exit \(ClubSchedule.timeText(minutes: exception.exitStartMinutes))"
                                )
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.76))
                            }

                            Spacer()

                            Button(role: .destructive) {
                                Task { await deleteException(exception) }
                            } label: {
                                Image(systemName: "trash.fill")
                                    .font(.headline)
                                    .frame(width: 42, height: 42)
                            }
                            .buttonStyle(.bordered)
                            .tint(.red)
                            .disabled(isSaving)
                        }
                        .scheduleCard()
                    }
                }
            }
        }
    }

    private var sortedExceptions: [ClubScheduleException] {
        configuration.exceptions.sorted { $0.dateKey < $1.dateKey }
    }

    private var regularEmojiSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Regular Emojis")
                .font(.title2.weight(.heavy))
                .foregroundStyle(.white)

            Text("Customize what children see. The protected internal 1–9 analytics values stay the same.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))

            VStack(spacing: 16) {
                emojiEditorGrid(
                    emojis: regularEmojiBindings,
                    displayNumbers: regularDisplayNumberBindings,
                    displayNames: regularDisplayNameBindings
                )

                HStack(spacing: 12) {
                    Button {
                        Task { await restoreDefaultEmojis() }
                    } label: {
                        Label("Restore Defaults", systemImage: "arrow.counterclockwise")
                            .font(.subheadline.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.bordered)
                    .tint(.white)

                    Button {
                        Task { await saveRegularEmojis() }
                    } label: {
                        Label("Save Emojis", systemImage: "checkmark.circle.fill")
                            .font(.subheadline.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.white.opacity(0.28))
                }
                .disabled(isSaving)
            }
            .scheduleCard()
        }
    }

    private var temporaryEmojiSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Temporary Emoji Theme")
                .font(.title2.weight(.heavy))
                .foregroundStyle(.white)

            Text("Use a special palette for a holiday, event, or selected date range.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))

            VStack(spacing: 16) {
                TextField("Theme name, such as Halloween", text: $temporaryPaletteName)
                    .textInputAutocapitalization(.words)
                    .padding(12)
                    .background(.white.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                DatePicker("Starts", selection: $temporaryStartDate, displayedComponents: .date)
                DatePicker("Ends", selection: $temporaryEndDate, displayedComponents: .date)

                HStack(spacing: 10) {
                    Button("Copy Regular Emojis") {
                        temporaryEmojis = paletteConfiguration.regularEmojis
                        temporaryDisplayNumbers = paletteConfiguration.regularDisplayNumbers
                        temporaryDisplayNames = paletteConfiguration.regularDisplayNames
                    }
                    .buttonStyle(.bordered)

                    Button("Use Defaults") {
                        temporaryEmojis = MoodPalette.defaultEmojis
                        temporaryDisplayNumbers = MoodPalette.defaultDisplayNumbers
                        temporaryDisplayNames = MoodPalette.defaultDisplayNames
                    }
                    .buttonStyle(.bordered)
                }
                .font(.caption.weight(.bold))
                .tint(.white)

                emojiEditorGrid(
                    emojis: temporaryEmojiBindings,
                    displayNumbers: temporaryDisplayNumberBindings,
                    displayNames: temporaryDisplayNameBindings
                )

                Button {
                    Task { await saveTemporaryPalette() }
                } label: {
                    Label("Save Temporary Theme", systemImage: "calendar.badge.plus")
                        .font(.headline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .tint(.white.opacity(0.28))
                .disabled(isSaving)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .tint(.white)
            .scheduleCard()
        }
    }

    private var savedTemporaryPalettesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Saved Temporary Themes")
                .font(.title2.weight(.heavy))
                .foregroundStyle(.white)

            if paletteConfiguration.temporaryPalettes.isEmpty {
                Text("No temporary emoji themes have been saved.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .scheduleCard()
            } else {
                VStack(spacing: 10) {
                    ForEach(paletteConfiguration.temporaryPalettes.reversed()) { palette in
                        HStack(spacing: 14) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(palette.name)
                                    .font(.headline.weight(.bold))
                                    .foregroundStyle(.white)
                                Text(temporaryPaletteDateText(palette))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.white.opacity(0.72))
                                Text(palette.emojis.joined(separator: " "))
                                    .font(.title3)
                                Text(zip(palette.displayNumbers, palette.displayNames).map { "\($0.0) • \($0.1)" }.joined(separator: "   "))
                                    .font(.caption2)
                                    .foregroundStyle(.white.opacity(0.72))
                                    .lineLimit(2)
                            }

                            Spacer()

                            Button(role: .destructive) {
                                Task { await deleteTemporaryPalette(palette) }
                            } label: {
                                Image(systemName: "trash.fill")
                                    .font(.headline)
                                    .frame(width: 42, height: 42)
                            }
                            .buttonStyle(.bordered)
                            .tint(.red)
                            .disabled(isSaving)
                        }
                        .scheduleCard()
                    }
                }
            }

            Label(
                "If temporary themes overlap, the most recently saved matching theme is used.",
                systemImage: "info.circle"
            )
            .font(.caption)
            .foregroundStyle(.white.opacity(0.76))
        }
    }

    private var regularEmojiBindings: [Binding<String>] {
        (0..<9).map { index in
            Binding(
                get: { paletteConfiguration.regularEmojis[index] },
                set: { paletteConfiguration.regularEmojis[index] = MoodPalette.singleSymbol(from: $0) }
            )
        }
    }

    private var temporaryEmojiBindings: [Binding<String>] {
        (0..<9).map { index in
            Binding(
                get: { temporaryEmojis[index] },
                set: { temporaryEmojis[index] = MoodPalette.singleSymbol(from: $0) }
            )
        }
    }

    private var regularDisplayNumberBindings: [Binding<String>] {
        (0..<9).map { index in
            Binding(
                get: { paletteConfiguration.regularDisplayNumbers[index] },
                set: {
                    paletteConfiguration.regularDisplayNumbers[index] = MoodPalette.shortDisplayText(
                        from: $0,
                        maximumCharacters: 8
                    )
                }
            )
        }
    }

    private var regularDisplayNameBindings: [Binding<String>] {
        (0..<9).map { index in
            Binding(
                get: { paletteConfiguration.regularDisplayNames[index] },
                set: {
                    paletteConfiguration.regularDisplayNames[index] = MoodPalette.shortDisplayText(
                        from: $0,
                        maximumCharacters: 24
                    )
                }
            )
        }
    }

    private var temporaryDisplayNumberBindings: [Binding<String>] {
        (0..<9).map { index in
            Binding(
                get: { temporaryDisplayNumbers[index] },
                set: {
                    temporaryDisplayNumbers[index] = MoodPalette.shortDisplayText(
                        from: $0,
                        maximumCharacters: 8
                    )
                }
            )
        }
    }

    private var temporaryDisplayNameBindings: [Binding<String>] {
        (0..<9).map { index in
            Binding(
                get: { temporaryDisplayNames[index] },
                set: {
                    temporaryDisplayNames[index] = MoodPalette.shortDisplayText(
                        from: $0,
                        maximumCharacters: 24
                    )
                }
            )
        }
    }

    private func emojiEditorGrid(
        emojis: [Binding<String>],
        displayNumbers: [Binding<String>],
        displayNames: [Binding<String>]
    ) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
            ForEach(0..<9, id: \.self) { index in
                VStack(spacing: 5) {
                    TextField("Emoji", text: emojis[index])
                        .font(.system(size: 42))
                        .multilineTextAlignment(.center)
                        .frame(height: 58)
                        .background(.white.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    HStack(spacing: 5) {
                        TextField("Number", text: displayNumbers[index])
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 62)

                        Text("•")
                            .foregroundStyle(.white.opacity(0.7))

                        TextField("Name", text: displayNames[index])
                            .multilineTextAlignment(.center)
                    }
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 7)
                    .background(.white.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 9))
                }
            }
        }
    }

    private func verifyPIN() {
        guard pin == Constants.adminPin else {
            pinError = "Incorrect staff PIN."
            Haptics.error()
            return
        }

        pinError = nil
        pin = ""
        isUnlocked = true
        Haptics.success()
    }

    private func saveResponseDate() {
        ResponseDatePreference.set(responseDate, for: site.id)
        responseDate = ResponseDatePreference.date(for: site.id)
        message = "New emoji responses for \(site.name) will use \(exceptionDateText(ClubSchedule.dateKey(for: responseDate)))."
        Haptics.success()
    }

    @MainActor
    private func saveRoomPromptTiming() async {
        await persist(
            successMessage: "The non-Front Room prompt will repeat every \(configuration.roomPromptIntervalMinutes) minute\(configuration.roomPromptIntervalMinutes == 1 ? "" : "s")."
        )
    }

    @MainActor
    private func load() async {
        isLoading = true
        var warnings: [String] = []
        do {
            configuration = try await service.fetchScheduleConfiguration(clubId: site.id)
        } catch {
            configuration = ClubSchedule.cachedConfiguration(for: site.id)
            warnings.append("schedule")
        }
        do {
            paletteConfiguration = try await service.fetchMoodPaletteConfiguration(clubId: site.id)
            temporaryEmojis = paletteConfiguration.regularEmojis
            temporaryDisplayNumbers = paletteConfiguration.regularDisplayNumbers
            temporaryDisplayNames = paletteConfiguration.regularDisplayNames
        } catch {
            paletteConfiguration = MoodPalette.cachedConfiguration(for: site.id)
            temporaryEmojis = paletteConfiguration.regularEmojis
            temporaryDisplayNumbers = paletteConfiguration.regularDisplayNumbers
            temporaryDisplayNames = paletteConfiguration.regularDisplayNames
            warnings.append("emoji")
        }
        if !warnings.isEmpty {
            message = "Some online settings could not be loaded. The most recently saved settings on this iPad are shown."
        }
        isLoading = false
    }

    @MainActor
    private func saveRegularSchedule() async {
        guard regularTimesAreValid else {
            message = "Each entry time must be earlier than its exit time."
            Haptics.error()
            return
        }
        await persist(successMessage: "The regular schedule for \(site.name) was saved.")
    }

    @MainActor
    private func saveException() async {
        guard exceptionEntryMinutes < exceptionExitMinutes else {
            message = "The exception entry time must be earlier than its exit time."
            Haptics.error()
            return
        }

        let exception = ClubScheduleException(
            dateKey: ClubSchedule.dateKey(for: exceptionDate),
            entryStartMinutes: exceptionEntryMinutes,
            exitStartMinutes: exceptionExitMinutes
        )
        configuration.exceptions.removeAll { $0.dateKey == exception.dateKey }
        configuration.exceptions.append(exception)
        configuration.exceptions.sort { $0.dateKey < $1.dateKey }
        await persist(successMessage: "The one-day exception was saved.")
    }

    @MainActor
    private func deleteException(_ exception: ClubScheduleException) async {
        let previousConfiguration = configuration
        configuration.exceptions.removeAll { $0.id == exception.id }
        let didSave = await persist(successMessage: "The one-day exception was removed.")
        if !didSave { configuration = previousConfiguration }
    }

    @MainActor
    @discardableResult
    private func persist(successMessage: String) async -> Bool {
        isSaving = true
        defer { isSaving = false }

        do {
            try await service.saveScheduleConfiguration(configuration, clubId: site.id)
            message = successMessage
            Haptics.success()
            return true
        } catch {
            message = error.localizedDescription
            Haptics.error()
            return false
        }
    }

    @MainActor
    private func saveRegularEmojis() async {
        guard MoodPalette.isValid(paletteConfiguration.regularEmojis),
              MoodPalette.isValidDisplayText(paletteConfiguration.regularDisplayNumbers),
              MoodPalette.isValidDisplayText(paletteConfiguration.regularDisplayNames)
        else {
            message = "Please enter an emoji, display number, and display name in all nine positions."
            Haptics.error()
            return
        }
        _ = await persistPalette(successMessage: "The regular emojis for \(site.name) were saved.")
    }

    @MainActor
    private func restoreDefaultEmojis() async {
        let previous = paletteConfiguration
        paletteConfiguration.regularEmojis = MoodPalette.defaultEmojis
        paletteConfiguration.regularDisplayNumbers = MoodPalette.defaultDisplayNumbers
        paletteConfiguration.regularDisplayNames = MoodPalette.defaultDisplayNames
        let didSave = await persistPalette(successMessage: "The default emojis were restored.")
        if !didSave { paletteConfiguration = previous }
    }

    @MainActor
    private func saveTemporaryPalette() async {
        let name = temporaryPaletteName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            message = "Please give the temporary theme a name."
            Haptics.error()
            return
        }
        guard MoodPalette.isValid(temporaryEmojis),
              MoodPalette.isValidDisplayText(temporaryDisplayNumbers),
              MoodPalette.isValidDisplayText(temporaryDisplayNames)
        else {
            message = "Please enter an emoji, display number, and display name in all nine positions."
            Haptics.error()
            return
        }

        let startKey = ClubSchedule.dateKey(for: temporaryStartDate)
        let endKey = ClubSchedule.dateKey(for: temporaryEndDate)
        guard startKey <= endKey else {
            message = "The temporary theme's end date must be on or after its start date."
            Haptics.error()
            return
        }

        let previous = paletteConfiguration
        paletteConfiguration.temporaryPalettes.append(
            TemporaryMoodPalette(
                id: UUID().uuidString,
                name: name,
                startDateKey: startKey,
                endDateKey: endKey,
                emojis: temporaryEmojis,
                displayNumbers: temporaryDisplayNumbers,
                displayNames: temporaryDisplayNames
            )
        )
        let didSave = await persistPalette(successMessage: "The temporary emoji theme was saved.")
        if didSave {
            temporaryPaletteName = ""
            temporaryEmojis = paletteConfiguration.regularEmojis
            temporaryDisplayNumbers = paletteConfiguration.regularDisplayNumbers
            temporaryDisplayNames = paletteConfiguration.regularDisplayNames
        } else {
            paletteConfiguration = previous
        }
    }

    @MainActor
    private func deleteTemporaryPalette(_ palette: TemporaryMoodPalette) async {
        let previous = paletteConfiguration
        paletteConfiguration.temporaryPalettes.removeAll { $0.id == palette.id }
        let didSave = await persistPalette(successMessage: "The temporary emoji theme was removed.")
        if !didSave { paletteConfiguration = previous }
    }

    @MainActor
    @discardableResult
    private func persistPalette(successMessage: String) async -> Bool {
        isSaving = true
        defer { isSaving = false }

        do {
            try await service.saveMoodPaletteConfiguration(paletteConfiguration, clubId: site.id)
            message = successMessage
            Haptics.success()
            return true
        } catch {
            message = error.localizedDescription
            Haptics.error()
            return false
        }
    }

    private var regularTimesAreValid: Bool {
        configuration.summerEntryStartMinutes < configuration.summerExitStartMinutes &&
        configuration.schoolYearEntryStartMinutes < configuration.schoolYearExitStartMinutes
    }

    private func timeBinding(
        _ keyPath: WritableKeyPath<ClubScheduleConfiguration, Int>
    ) -> Binding<Date> {
        Binding(
            get: { timeDate(minutes: configuration[keyPath: keyPath]) },
            set: { configuration[keyPath: keyPath] = minutes(from: $0) }
        )
    }

    private func exceptionTimeBinding(_ minutesBinding: Binding<Int>) -> Binding<Date> {
        Binding(
            get: { timeDate(minutes: minutesBinding.wrappedValue) },
            set: { minutesBinding.wrappedValue = minutes(from: $0) }
        )
    }

    private func timeDate(minutes: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = ClubSchedule.timeZone
        let start = calendar.startOfDay(for: Date(timeIntervalSince1970: 0))
        return calendar.date(byAdding: .minute, value: minutes, to: start) ?? start
    }

    private func minutes(from date: Date) -> Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = ClubSchedule.timeZone
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }

    private func exceptionDateText(_ key: String) -> String {
        guard let date = ClubSchedule.date(from: key) else { return key }
        return date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().year())
    }

    private func temporaryPaletteDateText(_ palette: TemporaryMoodPalette) -> String {
        let start = exceptionDateText(palette.startDateKey)
        let end = exceptionDateText(palette.endDateKey)
        return palette.startDateKey == palette.endDateKey ? start : "\(start) – \(end)"
    }
}

private extension View {
    func scheduleCard() -> some View {
        self
            .padding(16)
            .background(.white.opacity(Theme.cardOpacity))
            .clipShape(RoundedRectangle(cornerRadius: Theme.corner))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.corner)
                    .stroke(.white.opacity(0.14), lineWidth: 1)
            )
    }
}
