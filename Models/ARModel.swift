import Foundation

struct ARModel: Identifiable, Decodable {
    let id: Int
    let name: String
    let latitude: Double
    let longitude: Double
    let filename: String
    let active: Bool
    let visibility: Double
    /// Identificatore della prova a cui appartiene questo modello
    let idProva: Int

    enum CodingKeys: String, CodingKey {
        case id, name, latitude, longitude, filename, active, visibility
        case idProva = "idProva"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Decode id (Int or String)
        if let idInt = try? container.decode(Int.self, forKey: .id) {
            id = idInt
        } else {
            let idStr = try container.decode(String.self, forKey: .id)
            guard let idVal = Int(idStr) else {
                throw DecodingError.dataCorruptedError(
                    forKey: .id,
                    in: container,
                    debugDescription: "Cannot decode id \"\(idStr)\" as Int"
                )
            }
            id = idVal
        }

        // Decode name
        name = try container.decode(String.self, forKey: .name)

        // Decode latitude (Double or String)
        if let lat = try? container.decode(Double.self, forKey: .latitude) {
            latitude = lat
        } else {
            let latStr = try container.decode(String.self, forKey: .latitude)
            guard let latVal = Double(latStr) else {
                throw DecodingError.dataCorruptedError(
                    forKey: .latitude,
                    in: container,
                    debugDescription: "Cannot decode latitude \"\(latStr)\" as Double"
                )
            }
            latitude = latVal
        }

        // Decode longitude (Double or String)
        if let lon = try? container.decode(Double.self, forKey: .longitude) {
            longitude = lon
        } else {
            let lonStr = try container.decode(String.self, forKey: .longitude)
            guard let lonVal = Double(lonStr) else {
                throw DecodingError.dataCorruptedError(
                    forKey: .longitude,
                    in: container,
                    debugDescription: "Cannot decode longitude \"\(lonStr)\" as Double"
                )
            }
            longitude = lonVal
        }

        // Decode filename
        filename = try container.decode(String.self, forKey: .filename)

        // Decode active (Bool from Int or String)
        if let actInt = try? container.decode(Int.self, forKey: .active) {
            active = (actInt != 0)
        } else {
            let actStr = try container.decode(String.self, forKey: .active)
            active = (actStr == "1" || actStr.lowercased() == "true")
        }

        // Decode visibility (Double or String)
        if let vis = try? container.decode(Double.self, forKey: .visibility) {
            visibility = vis
        } else {
            let visStr = try container.decode(String.self, forKey: .visibility)
            guard let visVal = Double(visStr) else {
                throw DecodingError.dataCorruptedError(
                    forKey: .visibility,
                    in: container,
                    debugDescription: "Cannot decode visibility \"\(visStr)\" as Double"
                )
            }
            visibility = visVal
        }

        // Decode idProva (Int or String)
        if let ip = try? container.decode(Int.self, forKey: .idProva) {
            idProva = ip
        } else {
            let ipStr = try container.decode(String.self, forKey: .idProva)
            guard let ipVal = Int(ipStr) else {
                throw DecodingError.dataCorruptedError(
                    forKey: .idProva,
                    in: container,
                    debugDescription: "Cannot decode idProva \"\(ipStr)\" as Int"
                )
            }
            idProva = ipVal
        }
    }
}
