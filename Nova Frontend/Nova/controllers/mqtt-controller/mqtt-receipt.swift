nonisolated struct MQTTReceipt: Decodable, Sendable {
    let id: String
    let ok: Bool
    let state: String?
    let error: String?
}
