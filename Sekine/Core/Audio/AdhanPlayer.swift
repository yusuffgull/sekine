import Foundation
import AVFoundation

/// Uygulama-içi tam ezan çalar. iOS bildirim sesi 30 sn ile sınırlı olduğundan, tam ezan
/// (birkaç dakika) burada AVAudioPlayer ile çalınır — bildirime dokununca / "Ezanı Çal"
/// butonuyla / vakit girince app önplandayken.
///
/// NOT: Ezan ses dosyası (ör. ezan-full.m4a) telif nedeniyle repoya konmadı; lisanslı/
/// orijinal kayıt Resources/Audio altına eklenince otomatik çalışır. Dosya yoksa güvenli
/// şekilde no-op olur.
@MainActor
final class AdhanPlayer: NSObject, ObservableObject {
    @Published private(set) var isPlaying = false

    private var player: AVAudioPlayer?

    /// Bundle'daki tam ezan dosyasını çalar. Varsayılan aday adlar sırayla denenir.
    func play(resource: String = "ezan-full", extensions: [String] = ["m4a", "mp3", "caf"]) {
        guard let url = Self.url(resource: resource, extensions: extensions) else {
            // Ses dosyası henüz eklenmemiş → sessizce yok say.
            return
        }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            let player = try AVAudioPlayer(contentsOf: url)
            player.delegate = self
            player.prepareToPlay()
            player.play()
            self.player = player
            isPlaying = true
        } catch {
            isPlaying = false
        }
    }

    func stop() {
        player?.stop()
        player = nil
        isPlaying = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// Ezan ses dosyası bundle'da mevcut mu? (UI'da "Ezanı Çal" göstermek için.)
    static var isAvailable: Bool {
        url(resource: "ezan-full", extensions: ["m4a", "mp3", "caf"]) != nil
    }

    private static func url(resource: String, extensions: [String]) -> URL? {
        for ext in extensions {
            if let url = Bundle.main.url(forResource: resource, withExtension: ext) {
                return url
            }
        }
        return nil
    }
}

extension AdhanPlayer: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.isPlaying = false
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }
}
