import AudioToolbox
import Foundation

@MainActor
final class StaffAlertSound {
    private var timer: Timer?

    deinit {
        timer?.invalidate()
    }

    func start() {
        guard timer == nil else { return }
        play()

        let timer = Timer(timeInterval: 10, repeats: true) { _ in
            AudioServicesPlayAlertSound(1005)
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func play() {
        AudioServicesPlayAlertSound(1005)
    }
}
