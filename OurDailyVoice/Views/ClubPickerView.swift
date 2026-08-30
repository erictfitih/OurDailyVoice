import SwiftUI
import Firebase

struct ClubPickerView: View {
    @EnvironmentObject private var appState: AppState
    let service = MoodService()

    @State private var clubs: [MoodService.Club] = []
    @State private var isLoading = true
    @State private var error: String?

    var body: some View {
        ZStack {
            Theme.bgGradient
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Our Daily Voice")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(.white)

                        Text("Select a Site")
                            .font(.title3)
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    .padding(.top, 8)

                    if isLoading {
                        ProgressView("Loading sites...")
                            .tint(.white)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 40)
                    } else if let error {
                        Text(error)
                            .foregroundStyle(.white)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.white.opacity(Theme.cardOpacity))
                            .clipShape(RoundedRectangle(cornerRadius: Theme.corner))
                    } else {
                        VStack(spacing: 14) {
                            ForEach(clubs) { club in
                                Button {
                                    Haptics.tap()
                                    service.setSelectedClubId(club.id)
                                    appState.selectedSite = Site(
                                        id: club.id,
                                        name: club.name,
                                        rooms: club.rooms
                                    )
                                    appState.selectedRoom = nil
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text(club.name)
                                                .font(.title3.weight(.semibold))
                                                .foregroundStyle(.white)

                                            Text("\(club.rooms.count) room\(club.rooms.count == 1 ? "" : "s")")
                                                .font(.subheadline)
                                                .foregroundStyle(.white.opacity(0.8))
                                        }

                                        Spacer()

                                        Image(systemName: "chevron.right")
                                            .foregroundStyle(.white.opacity(0.8))
                                    }
                                    .padding(20)
                                    .frame(maxWidth: .infinity)
                                    .background(.white.opacity(Theme.cardOpacity))
                                    .clipShape(RoundedRectangle(cornerRadius: Theme.corner))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: Theme.corner)
                                            .stroke(.white.opacity(0.12), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    Spacer(minLength: 40)
                }
                .padding(24)
            }
        }
    .task { await load() }
    }

    private func load() async {
        do {
            clubs = try await service.fetchClubs()
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}
