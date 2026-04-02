import Foundation

actor APIClient {
    static let shared = APIClient()

    private let baseURL = "https://pierrea.se/krysslista/api.php"

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        return d
    }()

    enum APIError: LocalizedError {
        case invalidURL
        case invalidResponse
        case httpError(Int)
        case noData

        var errorDescription: String? {
            switch self {
            case .invalidURL: "Ogiltig URL"
            case .invalidResponse: "Ogiltigt svar från servern"
            case .httpError(let code): "Serverfel (\(code))"
            case .noData: "Ingen data"
            }
        }
    }

    func fetchSummary() async throws -> Summary {
        try await get("summary")
    }

    func fetchObservations(limit: Int = 50, offset: Int = 0, year: Int? = nil, county: String? = nil, species: Int? = nil, area: String? = nil) async throws -> ObservationsResponse {
        var params = ["limit=\(limit)", "offset=\(offset)"]
        if let year { params.append("year=\(year)") }
        if let county { params.append("county=\(county.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? county)") }
        if let species { params.append("species=\(species)") }
        if let area { params.append("area=\(area)") }
        return try await get("observations", extraParams: params)
    }

    func fetchSpecies() async throws -> SpeciesResponse {
        try await get("species")
    }

    func fetchLifelist() async throws -> LifelistResponse {
        try await get("lifelist")
    }

    func fetchLocalities() async throws -> LocalitiesResponse {
        try await get("localities")
    }

    func fetchStats() async throws -> StatsResponse {
        try await get("stats")
    }

    func fetchAreas() async throws -> AreasResponse {
        try await get("areas")
    }

    func triggerSync() async throws -> SyncResponse {
        try await get("sync", extraParams: ["key=\(Secrets.syncKey)"])
    }

    func fetchLive(date: String? = nil) async throws -> LiveResponse {
        var params: [String] = []
        if let date { params.append("date=\(date)") }
        return try await get("live", extraParams: params)
    }

    // MARK: - Private

    private func get<T: Decodable>(_ endpoint: String, extraParams: [String] = []) async throws -> T {
        var urlString = "\(baseURL)?q=\(endpoint)"
        if !extraParams.isEmpty {
            urlString += "&" + extraParams.joined(separator: "&")
        }

        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        try checkResponse(response)
        return try decoder.decode(T.self, from: data)
    }

    private func checkResponse(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            throw APIError.httpError(http.statusCode)
        }
    }
}
