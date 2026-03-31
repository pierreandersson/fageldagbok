import Foundation

actor LocalStore {
    static let shared = LocalStore()

    private let fileManager = FileManager.default

    private var documentsDir: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()

    private let decoder = JSONDecoder()

    // MARK: - Observations cache

    func loadObservations() -> [BirdObservation] {
        load(from: "observations.json") ?? []
    }

    func saveObservations(_ observations: [BirdObservation]) {
        save(observations, to: "observations.json")
    }

    // MARK: - Species cache

    func loadSpecies() -> [Species] {
        load(from: "species.json") ?? []
    }

    func saveSpecies(_ species: [Species]) {
        save(species, to: "species.json")
    }

    // MARK: - Lifelist cache

    func loadLifelist() -> [LifelistEntry] {
        load(from: "lifelist.json") ?? []
    }

    func saveLifelist(_ lifelist: [LifelistEntry]) {
        save(lifelist, to: "lifelist.json")
    }

    // MARK: - Summary cache

    func loadSummary() -> Summary? {
        load(from: "summary.json")
    }

    func saveSummary(_ summary: Summary) {
        save(summary, to: "summary.json")
    }

    // MARK: - Localities cache

    func loadLocalities() -> [Locality] {
        load(from: "localities.json") ?? []
    }

    func saveLocalities(_ localities: [Locality]) {
        save(localities, to: "localities.json")
    }

    // MARK: - Stats cache

    func loadStats() -> StatsResponse? {
        load(from: "stats.json")
    }

    func saveStats(_ stats: StatsResponse) {
        save(stats, to: "stats.json")
    }

    // MARK: - Generic I/O

    private func load<T: Decodable>(from filename: String) -> T? {
        let url = documentsDir.appending(path: filename)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(T.self, from: data)
    }

    private func save<T: Encodable>(_ value: T, to filename: String) {
        let url = documentsDir.appending(path: filename)
        guard let data = try? encoder.encode(value) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
