import SwiftUI
import WatchKit

/// Dijital tesbih (zikir sayacı) — watchOS portu. TesbihView.swift'in sadeleştirilmiş
/// hâli; UIImpactFeedbackGenerator yerine WKInterfaceDevice haptic kullanır.
struct WatchTesbihView: View {
    @AppStorage("tesbih.count") private var count = 0
    @AppStorage("tesbih.target") private var target = 33
    @AppStorage("tesbih.zikirIndex") private var zikirIndex = 0
    @AppStorage("tesbih.rounds") private var rounds = 0

    private static let zikirler = ["Sübhânallah", "Elhamdülillah", "Allâhu Ekber"]

    var body: some View {
        VStack(spacing: 8) {
            Text(Self.zikirler[zikirIndex % Self.zikirler.count])
                .font(.headline)
                .foregroundStyle(.tint)

            counter

            Text("Tur: \(rounds)")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Button {
                reset()
            } label: {
                Label("Sıfırla", systemImage: "arrow.counterclockwise")
            }
            .font(.caption2)
        }
        .padding()
    }

    private var counter: some View {
        ZStack {
            Circle().stroke(.secondary.opacity(0.3), lineWidth: 10)
            Circle()
                .trim(from: 0, to: min(1, Double(count) / Double(max(1, target))))
                .stroke(.tint, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.2), value: count)
            VStack(spacing: 0) {
                Text("\(count)")
                    .font(.system(size: 36, weight: .bold, design: .rounded).monospacedDigit())
                Text("/ \(target)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 120, height: 120)
        .contentShape(Circle())
        .onTapGesture { increment() }
    }

    private func increment() {
        count += 1
        if count >= target {
            count = 0
            rounds += 1
            zikirIndex += 1
            WKInterfaceDevice.current().play(.success)
        } else {
            WKInterfaceDevice.current().play(.click)
        }
    }

    private func reset() {
        count = 0
        WKInterfaceDevice.current().play(.notification)
    }
}
