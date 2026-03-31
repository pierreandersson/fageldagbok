import Foundation

struct Summary: Codable {
    let totalObs: Int
    let totalSpecies: Int
    let totalLocalities: Int
    let yearFrom: Int?
    let yearTo: Int?

    enum CodingKeys: String, CodingKey {
        case totalObs = "total_obs"
        case totalSpecies = "total_species"
        case totalLocalities = "total_localities"
        case yearFrom = "year_from"
        case yearTo = "year_to"
    }
}

struct AreaPreset: Codable, Identifiable, Hashable {
    var id: String { areaId }
    let areaId: String
    let name: String
    let latMin: Double?
    let latMax: Double?
    let lngMin: Double?
    let lngMax: Double?

    enum CodingKeys: String, CodingKey {
        case areaId = "id"
        case name
        case latMin = "lat_min"
        case latMax = "lat_max"
        case lngMin = "lng_min"
        case lngMax = "lng_max"
    }

    func contains(latitude: Double, longitude: Double) -> Bool {
        guard let latMin, let latMax, let lngMin, let lngMax else { return false }
        return latitude >= latMin && latitude <= latMax &&
               longitude >= lngMin && longitude <= lngMax
    }
}

struct AreasResponse: Codable {
    let areas: [AreaPreset]
}

struct Locality: Codable, Identifiable, Hashable {
    var id: String { locality }

    let locality: String
    let county: String?
    let municipality: String?
    let latitude: Double
    let longitude: Double
    let observationCount: Int
    let speciesCount: Int
    let lastVisit: String?

    enum CodingKeys: String, CodingKey {
        case locality, county, municipality, latitude, longitude
        case observationCount = "observation_count"
        case speciesCount = "species_count"
        case lastVisit = "last_visit"
    }
}

struct LocalitiesResponse: Codable {
    let total: Int
    let localities: [Locality]
}

struct StatsResponse: Codable {
    let perYear: [YearStats]
    let perMonth: [MonthStats]
    let topSpecies: [TopItem]
    let topLocalities: [TopLocalityItem]

    enum CodingKeys: String, CodingKey {
        case perYear = "per_year"
        case perMonth = "per_month"
        case topSpecies = "top_species"
        case topLocalities = "top_localities"
    }
}

struct YearStats: Codable, Identifiable {
    var id: Int { year }
    let year: Int
    let obsCount: Int
    let speciesCount: Int

    enum CodingKeys: String, CodingKey {
        case year
        case obsCount = "obs_count"
        case speciesCount = "species_count"
    }
}

struct MonthStats: Codable, Identifiable {
    var id: Int { month }
    let month: Int
    let obsCount: Int
    let speciesCount: Int

    enum CodingKeys: String, CodingKey {
        case month
        case obsCount = "obs_count"
        case speciesCount = "species_count"
    }
}

struct TopItem: Codable, Identifiable {
    var id: Int { taxonId }
    let vernacularName: String
    let taxonId: Int
    let count: Int

    enum CodingKeys: String, CodingKey {
        case vernacularName = "vernacular_name"
        case taxonId = "taxon_id"
        case count
    }
}

struct TopLocalityItem: Codable, Identifiable {
    var id: String { locality }
    let locality: String
    let count: Int
    let speciesCount: Int

    enum CodingKeys: String, CodingKey {
        case locality, count
        case speciesCount = "species_count"
    }
}
