import SwiftUI

struct DagbokView: View {
    @Bindable var viewModel: BirdViewModel
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            List {
                // Summary cards
                if let summary = viewModel.summary {
                    Section {
                        HStack(spacing: 0) {
                            StatCard(title: "Observationer", value: "\(summary.totalObs)", icon: "binoculars")
                            StatCard(title: "Arter", value: "\(summary.totalSpecies)", icon: "bird")
                            StatCard(title: "Lokaler", value: "\(summary.totalLocalities)", icon: "mappin.and.ellipse")
                        }
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                    }
                }

                // Filter chips
                if viewModel.hasActiveFilters {
                    Section {
                        HStack {
                            if let year = viewModel.selectedYear {
                                filterChip("\(year)") { viewModel.selectedYear = nil; viewModel.applyFilters() }
                            }
                            if let county = viewModel.selectedCounty {
                                filterChip(county) { viewModel.selectedCounty = nil; viewModel.applyFilters() }
                            }
                            if let areaId = viewModel.selectedArea,
                               let areaName = viewModel.areas.first(where: { $0.areaId == areaId })?.name {
                                filterChip(areaName) { viewModel.selectedArea = nil; viewModel.applyFilters() }
                            }
                            Spacer()
                            Button("Rensa") { viewModel.clearFilters() }
                                .font(.caption)
                        }
                        .listRowBackground(Color.clear)
                    }
                }

                // Observations grouped by date
                ForEach(viewModel.groupedByDate, id: \.date) { group in
                    Section {
                        let byLocality = Dictionary(grouping: group.observations) { $0.locality ?? "Okänd plats" }
                        let sortedLocalities = byLocality.keys.sorted()

                        ForEach(sortedLocalities, id: \.self) { locality in
                            if let obs = byLocality[locality] {
                                if sortedLocalities.count > 1 {
                                    Text(obs.first?.shortLocality ?? locality)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.secondary)
                                        .listRowBackground(Color.clear)
                                }
                                ForEach(obs) { observation in
                                    NavigationLink(value: observation) {
                                        ObservationRow(observation: observation)
                                    }
                                }
                            }
                        }
                    } header: {
                        HStack {
                            Text(group.displayDate)
                            Spacer()
                            Text("\(group.observations.count) obs")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }

                if viewModel.observations.isEmpty && !viewModel.isLoading {
                    ContentUnavailableView(
                        "Inga observationer",
                        systemImage: "binoculars",
                        description: Text("Dina fågelobservationer visas här")
                    )
                }
            }
            .navigationTitle("Fågeldagbok")
            .navigationDestination(for: BirdObservation.self) { [observations = viewModel.observations] observation in
                ObservationDetailView(
                    observation: observation,
                    allObservations: observations
                )
            }
            .navigationDestination(for: String.self) { [observations = viewModel.observations] localityName in
                LocalityDetailView(
                    localityName: localityName,
                    allObservations: observations
                )
            }
            .navigationDestination(for: SpeciesDestination.self) { [observations = viewModel.observations] dest in
                SpeciesObservationsView(
                    species: dest.species,
                    observations: observations.filter { $0.taxonId == dest.species.taxonId }
                )
            }
            .navigationDestination(for: LocalityObsDestination.self) { [observations = viewModel.observations] dest in
                LocalityObservationsView(
                    localityName: dest.localityName,
                    allObservations: observations
                )
            }
            .navigationDestination(for: LocalitySpeciesDestination.self) { [observations = viewModel.observations] dest in
                LocalitySpeciesView(
                    localityName: dest.localityName,
                    allObservations: observations
                )
            }
            .searchable(text: $viewModel.searchText, prompt: "Sök art eller lokal")
            .searchSuggestions {
                if !viewModel.searchText.isEmpty {
                    SearchResultsView(viewModel: viewModel, navigationPath: $navigationPath)
                }
            }
            .refreshable { await viewModel.refresh() }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        filterMenu
                    } label: {
                        Image(systemName: viewModel.hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if viewModel.isLoading {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
            }
            .alert("Fel", isPresented: .init(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    @ViewBuilder
    private var filterMenu: some View {
        Menu("År") {
            Button("Alla år") {
                viewModel.selectedYear = nil
                viewModel.applyFilters()
            }
            ForEach(viewModel.availableYears, id: \.self) { year in
                Button(String(year)) {
                    viewModel.selectedYear = year
                    viewModel.applyFilters()
                }
            }
        }

        if !viewModel.availableCounties.isEmpty {
            Menu("Län") {
                Button("Alla län") {
                    viewModel.selectedCounty = nil
                    viewModel.applyFilters()
                }
                ForEach(viewModel.availableCounties, id: \.self) { county in
                    Button(county) {
                        viewModel.selectedCounty = county
                        viewModel.applyFilters()
                    }
                }
            }
        }

        if !viewModel.areas.isEmpty {
            Divider()
            Menu("Område") {
                Button("Alla") {
                    viewModel.selectedArea = nil
                    viewModel.applyFilters()
                }
                ForEach(viewModel.areas) { area in
                    Button(area.name) {
                        viewModel.selectedArea = area.areaId
                        viewModel.applyFilters()
                    }
                }
            }
        }
    }

    private func filterChip(_ text: String, onRemove: @escaping () -> Void) -> some View {
        HStack(spacing: 4) {
            Text(text)
                .font(.caption)
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption2)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color("AccentGreen").opacity(0.15))
        .foregroundStyle(Color("AccentGreen"))
        .clipShape(Capsule())
    }
}

// MARK: - Search results overlay

struct SearchResultsView: View {
    let viewModel: BirdViewModel
    @Binding var navigationPath: NavigationPath

    var body: some View {
        ForEach(viewModel.matchedSpecies) { species in
            Button {
                viewModel.searchText = ""
                navigationPath.append(SpeciesDestination(species: species))
            } label: {
                HStack {
                    Image(systemName: "bird")
                        .foregroundStyle(Color("AccentGreen"))
                        .frame(width: 24)
                    VStack(alignment: .leading) {
                        Text(species.displayName)
                            .foregroundStyle(.primary)
                        Text("\(species.scientificName ?? "") · \(species.observationCount) obs")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }

        ForEach(viewModel.matchedLocalities) { locality in
            Button {
                viewModel.searchText = ""
                navigationPath.append(locality.locality as String)
            } label: {
                HStack {
                    Image(systemName: "mappin.and.ellipse")
                        .foregroundStyle(.red)
                        .frame(width: 24)
                    VStack(alignment: .leading) {
                        Text(locality.locality)
                            .foregroundStyle(.primary)
                        Text("\(locality.observationCount) obs · \(locality.speciesCount) arter")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }

        if !viewModel.searchText.isEmpty && !viewModel.hasSearchResults {
            Text("Inga träffar")
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Species observations view (from search)

struct SpeciesDestination: Hashable {
    let species: Species
}

struct SpeciesObservationsView: View {
    let species: Species
    let observations: [BirdObservation]

    var body: some View {
        List {
            Section {
                Text("\(observations.count) observationer")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
            }

            ForEach(observations) { observation in
                NavigationLink(value: observation) {
                    ObservationRow(observation: observation)
                }
            }
        }
        .navigationTitle(species.displayName)
    }
}
