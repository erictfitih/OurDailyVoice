import SwiftUI

struct GlobalPancakeMenu: View {
    @EnvironmentObject private var appState: AppState
    @Binding var isShowingClubData: Bool
    @Binding var isShowingOrganizationAnalytics: Bool
    @Binding var isShowingScheduleEditor: Bool

    var body: some View {
        GeometryReader { geometry in
            Menu {
                if isShowingClubData || isShowingOrganizationAnalytics || isShowingScheduleEditor {
                    Button {
                        Haptics.tap()
                        isShowingClubData = false
                        isShowingOrganizationAnalytics = false
                        isShowingScheduleEditor = false
                    } label: {
                        Label("Return to Check-In", systemImage: "face.smiling")
                    }
                }

                Button {
                    Haptics.tap()
                    isShowingOrganizationAnalytics = false
                    isShowingScheduleEditor = false
                    isShowingClubData = true
                } label: {
                    Label("Club Data", systemImage: "chart.bar.xaxis")
                }
                .disabled(appState.selectedSite == nil || isShowingClubData)

                Button {
                    Haptics.tap()
                    isShowingClubData = false
                    isShowingScheduleEditor = false
                    isShowingOrganizationAnalytics = true
                } label: {
                    Label("Organization Analytics", systemImage: "building.2.crop.circle")
                }
                .disabled(isShowingOrganizationAnalytics)

                Button {
                    Haptics.tap()
                    isShowingClubData = false
                    isShowingOrganizationAnalytics = false
                    isShowingScheduleEditor = true
                } label: {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .disabled(appState.selectedSite == nil || isShowingScheduleEditor)

                Button {
                    Haptics.tap()
                    isShowingClubData = false
                    isShowingOrganizationAnalytics = false
                    isShowingScheduleEditor = false
                    appState.selectedRoom = nil
                } label: {
                    Label("Change Room", systemImage: "door.left.hand.open")
                }
                .disabled(appState.selectedSite == nil)

                Button {
                    Haptics.tap()
                    isShowingClubData = false
                    isShowingOrganizationAnalytics = false
                    isShowingScheduleEditor = false
                    appState.selectedRoom = nil
                    appState.selectedSite = nil
                    MoodService().setSelectedClubId(nil)
                } label: {
                    Label("Change Site", systemImage: "building.2")
                }
                .disabled(appState.selectedSite == nil)

                if appState.selectedSite == nil {
                    Label("Select a site to view club data", systemImage: "info.circle")
                }
            } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(appState.isStaffVerificationRequired)
            .opacity(appState.isStaffVerificationRequired ? 0 : 1)
            .position(
                x: geometry.size.width - 42,
                y: geometry.safeAreaInsets.top + 78
            )
        }
        .ignoresSafeArea()
        .allowsHitTesting(!appState.isStaffVerificationRequired)
        .zIndex(50)
    }
}
