import Foundation

struct Species: Codable, Identifiable, Hashable {
    var id: Int { taxonId }

    let taxonId: Int
    let vernacularName: String?
    let scientificName: String?
    let family: String?
    let observationCount: Int
    let lastSeen: String?

    enum CodingKeys: String, CodingKey {
        case taxonId = "taxon_id"
        case vernacularName = "vernacular_name"
        case scientificName = "scientific_name"
        case family
        case observationCount = "observation_count"
        case lastSeen = "last_seen"
    }

    var displayName: String {
        guard let name = vernacularName, !name.isEmpty else {
            return scientificName ?? "Okänd art"
        }
        return name.prefix(1).uppercased() + name.dropFirst()
    }
}

struct SpeciesResponse: Codable {
    let total: Int
    let species: [Species]
}

struct LifelistEntry: Codable, Identifiable, Hashable {
    var id: Int { taxonId }

    let taxonId: Int
    let vernacularName: String?
    let scientificName: String?
    let family: String?
    let firstDate: String
    let firstLocality: String?
    let firstCounty: String?
    let observationCount: Int

    enum CodingKeys: String, CodingKey {
        case taxonId = "taxon_id"
        case vernacularName = "vernacular_name"
        case scientificName = "scientific_name"
        case family
        case firstDate = "first_date"
        case firstLocality = "first_locality"
        case firstCounty = "first_county"
        case observationCount = "observation_count"
    }

    var displayName: String {
        guard let name = vernacularName, !name.isEmpty else {
            return scientificName ?? "Okänd art"
        }
        return name.prefix(1).uppercased() + name.dropFirst()
    }
}

struct LifelistResponse: Codable {
    let total: Int
    let lifelist: [LifelistEntry]
}
