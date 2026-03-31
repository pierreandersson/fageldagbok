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
    var selectedArea: String? // "takern" or nil

    private let api = APIClient.shared
    private let store = LocalStore.shared

    init() {
        Task {
            // Show cached data immediately
            summary = await store.loadSummary()
            observations = await store.loadObservations()
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

        do {
            async let summaryTask = api.fetchSummary()
            async let observationsTask = api.fetchObservations(
                limit: 500,
                year: selectedYear,
                county: selectedCounty,
                area: selectedArea
            )
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
            observations = o.observations
            species = sp.species
            lifelist = ll.lifelist
            localities = lo.localities
            stats = st
            areas = ar.areas

            // Cache everything
            await store.saveSummary(s)
            await store.saveObservations(o.observations)
            await store.saveSpecies(sp.species)
            await store.saveLifelist(ll.lifelist)
            await store.saveLocalities(lo.localities)
            await store.saveStats(st)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Filtered data

    var filteredObservations: [BirdObservation] {
        guard !searchText.isEmpty else { return observations }
        let query = searchText.lowercased()
        return observations.filter {
            ($0.vernacularName?.lowercased().contains(query) ?? false) ||
            ($0.scientificName?.lowercased().contains(query) ?? false) ||
            ($0.locality?.lowercased().contains(query) ?? false)
        }
    }

    var groupedByDate: [(date: String, displayDate: String, observations: [BirdObservation])] {
        let grouped = Dictionary(grouping: filteredObservations) { $0.eventStartDate }
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
        let counties = Set(observations.compactMap(\.county))
        return counties.sorted()
    }

    // MARK: - Apply filters

    func applyFilters() async {
        do {
            let response = try await api.fetchObservations(
                limit: 500,
                year: selectedYear,
                county: selectedCounty,
                area: selectedArea
            )
            observations = response.observations
            await store.saveObservations(response.observations)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func clearFilters() async {
        selectedYear = nil
        selectedCounty = nil
        selectedArea = nil
        await applyFilters()
    }

    var hasActiveFilters: Bool {
        selectedYear != nil || selectedCounty != nil || selectedArea != nil
    }
}
