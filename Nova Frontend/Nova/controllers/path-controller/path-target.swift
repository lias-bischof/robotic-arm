import Foundation
import simd

struct Target: Codable {
    let id: UUID
    var position: SIMD3<Float>
    var action: Action

    init(position: SIMD3<Float>, action: Action) {
        self.id = UUID()
        self.position = position
        self.action = action
    }

    enum CodingKeys: String, CodingKey {
        case id, identifier, action
        case x, y, z
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self,   forKey: .id)
        action = try container.decode(Action.self, forKey: .action)
        let x = try container.decode(Float.self,  forKey: .x)
        let y = try container.decode(Float.self,  forKey: .y)
        let z = try container.decode(Float.self,  forKey: .z)
        position = SIMD3<Float>(x, y, z)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(action, forKey: .action)
        try container.encode(position.x, forKey: .x)
        try container.encode(position.y, forKey: .y)
        try container.encode(position.z, forKey: .z)
    }
}
