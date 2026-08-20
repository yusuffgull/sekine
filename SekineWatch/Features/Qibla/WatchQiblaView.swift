import SwiftUI

struct WatchQiblaView: View {
    @EnvironmentObject private var settings: AppSettings
    @StateObject private var qibla = QiblaManager()

    var body: some View {
        VStack(spacing: 8) {
            Text("Kıble")
                .font(.headline)
            if qibla.headingAvailable {
                ZStack {
                    Circle().stroke(.secondary.opacity(0.3), lineWidth: 4)
                    Image(systemName: "location.north.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.tint)
                        .rotationEffect(.degrees(qibla.qiblaBearing - qibla.heading))
                }
                .frame(width: 120, height: 120)
                .animation(.easeOut(duration: 0.2), value: qibla.heading)
            } else {
                Text("Bu Watch'ta pusula bulunmuyor.")
                    .font(.caption2)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .onAppear { qibla.start(from: settings.location) }
        .onDisappear { qibla.stop() }
    }
}
