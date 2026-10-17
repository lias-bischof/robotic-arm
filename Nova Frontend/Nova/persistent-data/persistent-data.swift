import Foundation

final class Persistent<Value: Codable> {

    let id: String
    let url: URL

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    convenience init(id: String) {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        self.init(id: id, url: directory.appendingPathComponent("\(id).json"))
    }

    init(id: String, url: URL) {
        self.id = id
        self.url = url
    }

    func save(_ value: Value) throws {
        let data = try encoder.encode(value)
        try data.write(to: url, options: .atomic)
    }

    func load(_ fallback: Value) -> Value {
        guard let data = try? Data(contentsOf: url) else {
            return fallback
        }
        do {
            return try decoder.decode(Value.self, from: data)
        } catch {
            return fallback
        }
    }
}
