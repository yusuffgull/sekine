import SwiftUI

/// Şehir/ilçe arama sayfası. Onboarding ve Ayarlar'dan kullanılır.
struct LocationSearchSheet: View {
    @EnvironmentObject private var location: LocationManager
    @Environment(\.dismiss) private var dismiss

    let onSelect: (SavedLocation) -> Void

    @State private var query = ""
    @State private var results: [SavedLocation] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            List {
                if isSearching {
                    HStack { ProgressView(); Text("Aranıyor…").foregroundStyle(Palette.textSecondary) }
                } else if results.isEmpty, !query.isEmpty {
                    Text("Sonuç bulunamadı. Şehir veya ilçe adını kontrol edin.")
                        .foregroundStyle(Palette.textSecondary)
                }
                ForEach(results, id: \.name) { place in
                    Button {
                        onSelect(place)
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: "mappin.circle.fill").foregroundStyle(Palette.accent)
                            Text(place.name).foregroundStyle(Palette.textPrimary)
                        }
                    }
                }
            }
            .navigationTitle("Konum Ara")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, prompt: "Şehir veya ilçe")
            .onChange(of: query) { _, newValue in
                searchTask?.cancel()
                searchTask = Task {
                    try? await Task.sleep(for: .milliseconds(400))
                    guard !Task.isCancelled else { return }
                    isSearching = true
                    let found = await location.search(newValue)
                    guard !Task.isCancelled else { return }
                    results = found
                    isSearching = false
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat") { dismiss() }
                }
            }
        }
    }
}
