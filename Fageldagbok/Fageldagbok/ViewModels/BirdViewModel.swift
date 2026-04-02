import Foundation

@Observable
@MainActor
class BirdViewModel {
    var summary: Summary?
    var observations: [BirdObservation] = []
    var species: [Species] = []
    var lifelist: [LifelistEntry] = []
    var localities: [Locality] = []
    var stats: StatsResponse?
    var areas: [AreaPreset] = []

    var isLoading = false
    var errorMessage: String?
    var searchText = ""

    // Filters
    var selectedYear: Int?
    var selectedCounty: String?
    var selectedArea: String?

    // All observations (unfiltered, from server)
    private var allObservations: [BirdObservation] = []

    private let api = APIClient.shared
    private let store = LocalStore.shared

    init() {
        Task {
            // Show cached data immediately
            summary = await store.loadSummary()
            allObservations = await store.loadObservations()
            applyLocalFilters()
            species = await store.loadSpecies()
            lifelist = await store.loadLifelist()
            localities = await store.loadLocalities()
            stats = await store.loadStats()

            // Then refresh from server
            await refresh()
        }
    }

    // MARK: - Refresh from server

    func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil

        // Sync database with SOS API first (non-blocking on failure)
        _ = try? await api.triggerSync()

        do {
            async let summaryTask = api.fetchSummary()
            async let observationsTask = api.fetchObservations(limit: 500)
            async let speciesTask = api.fetchSpecies()
            async let lifelistTask = api.fetchLifelist()
            async let localitiesTask = api.fetchLocalities()
            async let statsTask = api.fetchStats()
            async let areasTask = api.fetchAreas()

            let (s, o, sp, ll, lo, st, ar) = try await (
                summaryTask, observationsTask, speciesTask,
                lifelistTask, localitiesTask, statsTask, areasTask
            )

            summary = s
            allObservations = o.observations
            species = sp.species
            lifelist = ll.lifelist
            localities = lo.localities
            stats = st
            areas = ar.areas

            // Merge today's live observations from SOS API
            await mergeLiveObservations()
            applyLocalFilters()

            // Cache everything
            await store.saveSummary(s)
            await store.saveObservations(allObservations)
            await store.saveSpecies(sp.species)
            await store.saveLifelist(ll.lifelist)
            await store.saveLocalities(lo.localities)
            await store.saveStats(st)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Live observations

    private func mergeLiveObservations() async {
        do {
            let live = try await api.fetchLive()
            guard !live.observations.isEmpty else { return }

            let existingIds = Set(allObservations.map(\.occurrenceId))
            let newObs = live.observations.filter { !existingIds.contains($0.occurrenceId) }
            if !newObs.isEmpty {
                allObservations.append(contentsOf: newObs)
                allObservations.sort { $0.eventStartDate > $1.eventStartDate }
            }
        } catch {
            // Live data is optional — don't show error if it fails
        }
    }

    // MARK: - Filtered data

    // MARK: - Search results (matched entities)

    var matchedSpecies: [Species] {
        guard !searchText.isEmpty else { return [] }
        let query = searchText.lowercased()
        return species.filter {
            ($0.vernacularName?.lowercased().contains(query) ?? false) ||
            ($0.scientificName?.lowercased().contains(query) ?? false)
        }
    }

    var matchedLocalities: [Locality] {
        guard !searchText.isEmpty else { return [] }
        let query = searchText.lowercased()
        return localities.filter {
            $0.locality.lowercased().contains(query)
        }
    }

    var hasSearchResults: Bool {
        !matchedSpecies.isEmpty || !matchedLocalities.isEmpty
    }

    func observations(forTaxonId taxonId: Int) -> [BirdObservation] {
        allObservations.filter { $0.taxonId == taxonId }
            .sorted { $0.eventStartDate > $1.eventStartDate }
    }

    // MARK: - Grouped observations (no search filtering — search uses overlay)

    var groupedByDate: [(date: String, displayDate: String, observations: [BirdObservation])] {
        let grouped = Dictionary(grouping: observations) { $0.eventStartDate }
        return grouped.keys.sorted(by: >).map { date in
            let obs = grouped[date]!.sorted { a, b in
                (a.locality ?? "") < (b.locality ?? "")
            }
            let displayDate = obs.first?.displayDate ?? date
            return (date: date, displayDate: displayDate, observations: obs)
        }
    }

    var filteredSpecies: [Species] {
        guard !searchText.isEmpty else { return species }
        let query = searchText.lowercased()
        return species.filter {
            ($0.vernacularName?.lowercased().contains(query) ?? false) ||
            ($0.scientificName?.lowercased().contains(query) ?? false)
        }
    }

    var filteredLifelist: [LifelistEntry] {
        guard !searchText.isEmpty else { return lifelist }
        let query = searchText.lowercased()
        return lifelist.filter {
            ($0.vernacularName?.lowercased().contains(query) ?? false) ||
            ($0.scientificName?.lowercased().contains(query) ?? false)
        }
    }

    // MARK: - Available filter values

    var availableYears: [Int] {
        guard let from = summary?.yearFrom, let to = summary?.yearTo else { return [] }
        return Array(from...to).reversed()
    }

    var availableCounties: [String] {
        let counties = Set(allObservations.compactMap(\.county))
        return counties.sorted()
    }

    // MARK: - Apply filters

    func applyFilters() {
        applyLocalFilters()
    }

    func clearFilters() {
        selectedYear = nil
        selectedCounty = nil
        selectedArea = nil
        applyLocalFilters()
    }

    private func applyLocalFilters() {
        var result = allObservations

        if let year = selectedYear {
            result = result.filter { $0.eventStartDate.hasPrefix(String(year)) }
        }
        if let county = selectedCounty {
            result = result.filter { $0.county == county }
        }
        if let areaId = selectedArea, let area = areas.first(where: { $0.areaId == areaId }) {
            result = result.filter {
                guard let lat = $0.latitude, let lng = $0.longitude else { return false }
                return area.contains(latitude: lat, longitude: lng)
            }
        }

        observations = result
    }

    var hasActiveFilters: Bool {
        selectedYear != nil || selectedCounty != nil || selectedArea != nil
    }
}
