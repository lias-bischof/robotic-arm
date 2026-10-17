import Foundation
import simd
import Observation

@Observable
class Joint: Codable {
    
    var id: String
    var foot: SIMD3<Float> = SIMD3<Float>.zero
    var length: Float
    var speed: Float
    var azimuth: Float
    var elevation: Float
    
    private var store: Persistent<Joint> {
        Persistent(id: id)
    }

    func save() throws {
        try store.save(self)
    }

    static func load(_ fallback: Joint) -> Joint {
        Persistent<Joint>(id: fallback.id).load(fallback)
    }
    
    init(id: String, length: Float, speed: Float = 1.0, azimuth: Float, elevation: Float) {
        self.id = id
        self.length = length
        self.speed = speed
        self.azimuth = azimuth
        self.elevation = elevation
    }
    
    func move(foot: SIMD3<Float>){
        self.foot = foot
    }
    
    func head() -> SIMD3<Float> {
        let x = length * cos(elevation) * cos(azimuth)
        let y = length * sin(elevation)
        let z = length * cos(elevation) * sin(azimuth)
        return foot + SIMD3<Float>(x, y, z)
    }
    
    func uvhead() -> SIMD2<Float> {
        let headproj = uvproj(
            azimuth: azimuth,
            vector: self.head()
        )
        return xyproj(headproj)
    }
    
    func uvfoot() -> SIMD2<Float> {
        let footproj = uvproj(
            azimuth: azimuth,
            vector: self.foot
        )
        return xyproj(footproj)
    }
    
    func direction() -> SIMD3<Float> {
        return head() - foot
    }
    
    func rotate(azimuth: Float){
        self.azimuth = azimuth
    }
    
    func rotate(elevation: Float){
        self.elevation = elevation
    }
    
    enum CodingKeys: String, CodingKey {
        case id, length, speed, azimuth, elevation
        case x, y, z
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        length = try container.decode(Float.self, forKey: .length)
        speed = try container.decode(Float.self, forKey: .speed)
        azimuth = try container.decode(Float.self, forKey: .azimuth)
        elevation = try container.decode(Float.self, forKey: .elevation)
        foot = SIMD3<Float>(
            try container.decode(Float.self, forKey: .x),
            try container.decode(Float.self, forKey: .y),
            try container.decode(Float.self, forKey: .z)
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(length, forKey: .length)
        try container.encode(speed, forKey: .speed)
        try container.encode(azimuth, forKey: .azimuth)
        try container.encode(elevation, forKey: .elevation)
        try container.encode(foot.x, forKey: .x)
        try container.encode(foot.y, forKey: .y)
        try container.encode(foot.z, forKey: .z)
    }
}
