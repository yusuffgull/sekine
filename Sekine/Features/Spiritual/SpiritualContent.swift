import Foundation

/// Esmaül Hüsna girişi (isim + anlam).
struct EsmaName: Decodable, Identifiable, Hashable {
    let name: String
    let meaning: String
    var id: String { name }
}

/// Dua girişi (başlık + okunuş + anlam + kaynak).
struct Dua: Decodable, Identifiable, Hashable {
    let title: String
    let reading: String
    let meaning: String
    let source: String
    var id: String { title }
}

/// Bundle'lı dini içerik (ücretsiz). Saf/ağsız.
enum SpiritualContent {
    static let esmaulHusna: [EsmaName] = load("EsmaulHusna")
    static let duas: [Dua] = load("Duas")

    private static func load<T: Decodable>(_ resource: String) -> [T] {
        guard let url = Bundle.main.url(forResource: resource, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([T].self, from: data)
        else { return [] }
        return decoded
    }
}
