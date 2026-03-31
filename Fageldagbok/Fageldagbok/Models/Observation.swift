import Foundation

struct BirdObservation: Codable, Identifiable, Hashable {
    var id: String { occurrenceId }

    let occurrenceId: String
    let taxonId: Int
    let scientificName: String?
    let vernacularName: String?
    let individualCount: Int?
    let eventStartDate: String
    let eventEndDate: String?
    let startTime: String?
    let latitude: Double?
    let longitude: Double?
    let locality: String?
    let county: String?
    let municipality: String?
    let recordedBy: String?
    let remarks: String?
    let activity: String?
    let family: String?
    let isRedlisted: Int?
    let redlistCategory: String?
    let url: String?

    enum CodingKeys: String, CodingKey {
        case occurrenceId = "occurrence_id"
        case taxonId = "taxon_id"
        case scientificName = "scientific_name"
        case vernacularName = "vernacular_name"
        case individualCount = "individual_count"
        case eventStartDate = "event_start_date"
        case eventEndDate = "event_end_date"
        case startTime = "start_time"
        case latitude, longitude, locality, county, municipality
        case recordedBy = "recorded_by"
        case remarks, activity, family
        case isRedlisted = "is_redlisted"
        case redlistCategory = "redlist_category"
        case url
    }

    var displayName: String {
        guard let name = vernacularName, !name.isEmpty else {
            return scientificName ?? "Okänd art"
        }
        return name.prefix(1).uppercased() + name.dropFirst()
    }

    var parsedDate: Date? {
        Self.dateFormatter.date(from: eventStartDate)
    }

    var displayDate: String {
        guard let date = parsedDate else { return eventStartDate }
        return Self.displayFormatter.string(from: date)
    }

    var shortLocality: String {
        guard let loc = locality else { return "Okänd plats" }
        // Remove county suffix like ", Ög" or ", Tåkern, Ög"
        return loc.components(separatedBy: ", ").first ?? loc
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static let displayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "sv_SE")
        f.dateStyle = .long
        return f
    }()
}

struct ObservationsResponse: Codable {
    let total: Int
    let limit: Int
    let offset: Int
    let observations: [BirdObservation]
}

struct LiveResponse: Codable {
    let date: String
    let total: Int
    let observations: [BirdObservation]
}
