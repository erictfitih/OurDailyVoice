import SwiftUI

struct ClubDataContainerView: View {
    let site: Site

    @State private var sessions: [SessionDay] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    private let service = MoodService()

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ZStack {
                        Theme.bgGradient.ignoresSafeArea()
                        ProgressView("Loading club data...")
                            .tint(.white)
                            .foregroundStyle(.white)
                    }
                } else if let errorMessage {
                    ZStack {
                        Theme.bgGradient.ignoresSafeArea()
                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.largeTitle)
                            Text("Club data could not be loaded")
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
                    AdminAnalyticsView(
                        dailyScores: DailyAnalytics.from(sessions: sessions),
                        siteName: site.name,
                        availableRooms: site.rooms
                    )
                }
            }
        }
        .task(id: site.id) {
            await load()
        }
    }

    @MainActor
    private func load() async {
        isLoading = true
        errorMessage = nil

        do {
            service.setSelectedClubId(site.id)
            sessions = try await service.fetchAllSessionDays(clubId: site.id)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
