//
//  ContentView.swift
//  OurDailyVoice
//

import SwiftUI
import Combine

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var vm = MoodViewModel()
    @State private var pendingManualMode: SessionMode?
    @State private var manualModePIN = ""
    @State private var manualModeError: String?
    @State private var isShowingManualModePIN = false
    @State private var isEmojiCooldownActive = false
    @State private var emojiCooldownProgress: CGFloat = 0
    @State private var isShowingRoomDirectionPrompt = false

    private let cols = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bgGradient
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        currentSelectionSection
                        dayPickerSection
                        if isFrontRoom {
                            automaticModeSection
                        } else {
                            roomDirectionStatusSection
                        }
                        Text("Tap your vibe ✨")
                            .font(.title3)
                            .foregroundStyle(.white)
                        moodGridSection
                        statsRow
                        logsList

                        Spacer(minLength: 24)
                    }
                    .padding()
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .onAppear {
            vm.appState = appState
            appState.isStaffVerificationRequired = false
            if isFrontRoom {
                vm.clearRoomPromptMode()
            } else {
                isShowingRoomDirectionPrompt = true
            }
        }
        .task { await vm.start() }
        .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { date in
            vm.updateSchedule(at: date)
        }
        .onReceive(
            Timer.publish(
                every: TimeInterval(vm.roomPromptIntervalMinutes * 60),
                on: .main,
                in: .common
            ).autoconnect()
        ) { _ in
            if !isFrontRoom {
                isShowingRoomDirectionPrompt = true
            }
        }
        .onDisappear {
            appState.isStaffVerificationRequired = false
        }
        .sheet(isPresented: $isShowingManualModePIN) {
            manualModePINSheet
        }
        .fullScreenCover(isPresented: $isShowingRoomDirectionPrompt) {
            roomDirectionPrompt
        }
        .alert(
            "Error",
            isPresented: Binding(
                get: { vm.errorMessage != nil },
                set: { if !$0 { vm.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(vm.errorMessage ?? "")
        }
    }

    // MARK: - TOP INFO

    private var currentSelectionSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(appState.selectedSite?.name ?? "No Site Selected")
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)

            Text(appState.selectedRoom ?? "No Room Selected")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.9))
        }
    }

    private var isFrontRoom: Bool {
        appState.selectedRoom?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .localizedCaseInsensitiveCompare("Front Room") == .orderedSame
    }

    // MARK: - SECTIONS

    private var dayPickerSection: some View {
        HStack {
            Text("Today's Date")
                .font(.headline)

            Spacer()

            Text(vm.selectedDay.formatted(.dateTime.month(.abbreviated).day().year()))
                .font(.headline.weight(.bold))
        }
        .foregroundStyle(.white)
        .padding(12)
        .background(.white.opacity(Theme.cardOpacity))
        .clipShape(RoundedRectangle(cornerRadius: Theme.corner))
    }

    private var automaticModeSection: some View {
        VStack(spacing: 14) {
            Picker("Response mode", selection: manualModeSelection) {
                Text("Enter").tag(SessionMode.enter)
                Text("Leave").tag(SessionMode.leave)
            }
            .pickerStyle(.segmented)

            HStack(spacing: 14) {
                Image(systemName: modeIcon)
                    .font(.system(size: 28, weight: .bold))

                VStack(alignment: .leading, spacing: 4) {
                    Text(modeHeadline)
                        .font(.headline.weight(.bold))

                    Text(modeDetail)
                        .font(.subheadline)
                        .opacity(0.9)
                }

                Spacer()
            }
        }
        .foregroundStyle(.white)
        .padding(16)
        .background(.white.opacity(Theme.cardOpacity))
        .clipShape(RoundedRectangle(cornerRadius: Theme.corner))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.corner)
                .stroke(.white.opacity(0.2), lineWidth: 1)
        )
    }

    private var roomDirectionStatusSection: some View {
        HStack(spacing: 14) {
            Image(systemName: vm.roomPromptMode == .leave ? "figure.walk.departure" : "figure.walk.arrival")
                .font(.system(size: 28, weight: .bold))

            VStack(alignment: .leading, spacing: 4) {
                Text(vm.roomPromptMode == .leave ? "Recording Kids Heading Out" : "Recording Kids Coming In")
                    .font(.headline.weight(.bold))

                Text(
                    "We'll ask again every \(vm.roomPromptIntervalMinutes) minute\(vm.roomPromptIntervalMinutes == 1 ? "" : "s") so responses stay accurate for this room."
                )
                    .font(.subheadline)
                    .opacity(0.9)
            }

            Spacer()

            Button("Change") {
                isShowingRoomDirectionPrompt = true
            }
            .buttonStyle(.bordered)
        }
        .foregroundStyle(.white)
        .padding(16)
        .background(.white.opacity(Theme.cardOpacity))
        .clipShape(RoundedRectangle(cornerRadius: Theme.corner))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.corner)
                .stroke(.white.opacity(0.2), lineWidth: 1)
        )
    }

    private var modeIcon: String {
        vm.displayMode == .enter ? "arrow.right.circle.fill" : "arrow.left.circle.fill"
    }

    private var modeHeadline: String {
        vm.displayMode == .enter ? "Recording Entry Responses" : "Recording Exit Responses"
    }

    private var modeDetail: String {
        if vm.isUsingManualMode {
            return "Manually selected by staff • automatic mode resumes at the next scheduled change"
        }

        switch vm.scheduleStatus.period {
        case .inactive:
            return "Entry begins at \(vm.scheduleStatus.entryStartText)"
        case .entry:
            return "Automatic entry period until \(vm.scheduleStatus.exitStartText)"
        case .exit:
            return "Automatic exit period"
        }
    }

    private var manualModeSelection: Binding<SessionMode> {
        Binding(
            get: { vm.displayMode },
            set: { requestedMode in
                guard requestedMode != vm.displayMode else { return }
                pendingManualMode = requestedMode
                manualModePIN = ""
                manualModeError = nil
                isShowingManualModePIN = true
            }
        )
    }

    private var moodGridSection: some View {
        LazyVGrid(columns: cols, spacing: 15) {
            ForEach(vm.moodOptions) { option in
                Button {
                    startEmojiCooldown()
                    vm.beginResponse(option: option)
                } label: {
                    VStack(spacing: 6) {
                        Text(option.emoji)
                            .font(.system(size: 60))

                        Text("\(option.displayNumber) • \(option.label)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white.opacity(0.9))
                            .lineLimit(1)
                            .minimumScaleFactor(0.65)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 170)
                    .background(.white.opacity(Theme.cardOpacity))
                    .clipShape(RoundedRectangle(cornerRadius: Theme.corner))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.corner)
                            .stroke(.white.opacity(0.18), lineWidth: 1)
                    )
                    .overlay(alignment: .bottom) {
                        GeometryReader { geometry in
                            VStack(spacing: 0) {
                                Spacer(minLength: 0)
                                Rectangle()
                                    .fill(.white.opacity(0.5))
                                    .frame(
                                        height: geometry.size.height * emojiCooldownProgress
                                    )
                            }
                            .clipShape(RoundedRectangle(cornerRadius: Theme.corner))
                        }
                        .allowsHitTesting(false)
                    }
                }
                .buttonStyle(.plain)
                .disabled(
                    vm.isLoading ||
                    isEmojiCooldownActive ||
                    (!isFrontRoom && vm.roomPromptMode == nil)
                )
            }
        }
    }

    // MARK: - ROOM DIRECTION PROMPT

    private var roomDirectionPrompt: some View {
        ZStack {
            Theme.bgGradient.ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                Image(systemName: "door.left.hand.open")
                    .font(.system(size: 72, weight: .semibold))
                    .foregroundStyle(.white)

                VStack(spacing: 10) {
                    Text("What are you doing in this room?")
                        .font(.largeTitle.weight(.heavy))
                        .multilineTextAlignment(.center)

                    Text("Pick one so we save the next feelings in the right place.")
                        .font(.title3)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white.opacity(0.86))
                }

                HStack(spacing: 18) {
                    roomDirectionButton(
                        mode: .enter,
                        title: "I Just Came In",
                        icon: "figure.walk.arrival"
                    )
                    roomDirectionButton(
                        mode: .leave,
                        title: "I'm Heading Out",
                        icon: "figure.walk.departure"
                    )
                }
                .frame(maxWidth: 760)

                Spacer()
            }
            .foregroundStyle(.white)
            .padding(36)
        }
        .interactiveDismissDisabled()
    }

    private func roomDirectionButton(
        mode: SessionMode,
        title: String,
        icon: String
    ) -> some View {
        Button {
            vm.setRoomPromptMode(mode)
            isShowingRoomDirectionPrompt = false
        } label: {
            VStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 46, weight: .semibold))

                Text(title)
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 160)
            .background(.white.opacity(0.22))
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(.white.opacity(0.35), lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - STAFF MODE CHANGE

    private var manualModePINSheet: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 46))
                    .foregroundStyle(.blue)

                Text("Change to \(pendingManualMode?.title ?? "Selected") Mode")
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)

                Text("Enter the staff PIN to change the response mode manually.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)

                SecureField("Staff PIN", text: $manualModePIN)
                    .keyboardType(.numberPad)
                    .textContentType(.password)
                    .font(.title3)
                    .padding(14)
                    .background(.secondary.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: Theme.corner))

                if let manualModeError {
                    Text(manualModeError)
                        .font(.headline)
                        .foregroundStyle(.red)
                }

                Button("Confirm Mode Change") {
                    confirmManualModeChange()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(manualModePIN.isEmpty || pendingManualMode == nil)

                Spacer(minLength: 0)
            }
            .padding(28)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isShowingManualModePIN = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
        .interactiveDismissDisabled()
    }

    private func confirmManualModeChange() {
        guard let pendingManualMode else { return }

        if vm.setManualMode(pendingManualMode, pin: manualModePIN) {
            self.pendingManualMode = nil
            manualModePIN = ""
            manualModeError = nil
            isShowingManualModePIN = false
        } else {
            manualModePIN = ""
            manualModeError = "Incorrect staff PIN. The mode was not changed."
        }
    }

    private func startEmojiCooldown() {
        guard !isEmojiCooldownActive else { return }

        isEmojiCooldownActive = true
        emojiCooldownProgress = 0
        withAnimation(.linear(duration: 0.4)) {
            emojiCooldownProgress = 1
        }

        Task {
            try? await Task.sleep(for: .milliseconds(400))
            var transaction = Transaction(animation: nil)
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                emojiCooldownProgress = 0
                isEmojiCooldownActive = false
            }
        }
    }

    // MARK: - HELPERS

    private var statsRow: some View {
        HStack(spacing: 15) {
            statPill("Avg", vm.average.map { String(format: "%.1f", $0) } ?? "—")
            statPill("Top", vm.topEmoji ?? "—")
            statPill("Youths", "\(vm.youthsServed)")
            statPill("Duration", vm.formattedProgramDuration)
        }
    }
    private func statPill(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.85))

            Text(value)
                .font(.system(size: 16, weight: .heavy))
                .foregroundStyle(.white)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(.white.opacity(Theme.cardOpacity))
        .clipShape(RoundedRectangle(cornerRadius: Theme.corner))
    }

    private func emojiForValue(_ value: Int) -> String {
        vm.moodOptions.first(where: { $0.value == value })?.emoji ?? "🙂"
    }

    private var logsList: some View {
        let values = vm.displayMode == .enter
            ? (vm.session?.enterValues ?? [])
            : (vm.session?.leaveValues ?? [])

        let displayedValues = Array(values.reversed())

        return VStack(alignment: .leading, spacing: 8) {
            Text("Logs")
                .font(.headline)
                .foregroundStyle(.white)

            if displayedValues.isEmpty {
                Text("No logs yet — tap an emoji.")
                    .foregroundStyle(.white.opacity(0.85))
            } else {
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(Array(displayedValues.enumerated()), id: \.offset) { index, value in
                            HStack(spacing: 15) {
                                Text(emojiForValue(value))
                                    .font(.system(size: 30))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Value: \(value)")
                                        .foregroundStyle(.white)
                                        .font(.subheadline.weight(.semibold))

                                    Text("Log \(displayedValues.count - index)")
                                        .foregroundStyle(.white.opacity(0.85))
                                        .font(.caption)
                                }

                                Spacer()
                            }
                            .padding(12)
                            .background(.white.opacity(Theme.cardOpacity))
                            .clipShape(RoundedRectangle(cornerRadius: Theme.corner))
                        }
                    }
                }
                .frame(maxHeight: 360)
            }
        }
    }
}
