import SwiftUI

struct DagbokView: View {
    @Bindable var viewModel: BirdViewModel
    @State private var navigationPath = NavigationPath()
    @State private var showDatePicker = false
    @State private var pickerDate = Date()
    @State private var scrollTarget: String? = nil

    private let rawDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private func nearestDateId(to date: Date) -> String? {
        let dates = viewModel.groupedByDate.map(\.date)
        return dates.min(by: { a, b in
            let da = rawDateFormatter.date(from: a) ?? .distantPast
            let db = rawDateFormatter.date(from: b) ?? .distantPast
            return abs(da.timeIntervalSince(date)) < abs(db.timeIntervalSince(date))
        })
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollViewReader { proxy in
            List {
                // Summary cards
                if let summary = viewModel.summary {
                    Section {
                        HStack(spacing: 8) {
                            StatCard(title: "Observationer", value: "\(summary.totalObs)", icon: "binoculars")
                            StatCard(title: "Arter", value: "\(summary.totalSpecies)", icon: "bird")
                            StatCard(title: "Lokaler", value: "\(summary.totalLocalities)", icon: "mappin.and.ellipse")
                        }
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                }

                // Filter chips
                if viewModel.hasActiveFilters {
                    Section {
                        HStack {
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
                                Text(obs.first?.shortLocality ?? locality)
                                    .font(.callout)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.primary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 10)
                                    .listRowBackground(Color(.systemGray6))
                                    .listRowSeparator(.hidden)
                                    .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: 0, trailing: 16))
                                ForEach(obs) { observation in
                                    NavigationLink(value: observation) {
                                        ObservationRow(observation: observation)
                                    }
                                }
                            }
                        }
                    } header: {
                        DaySectionHeader(
                            displayDate: group.displayDate,
                            obsCount: group.observations.count,
                            speciesCount: Set(group.observations.compactMap(\.taxonId)).count
                        )
                        .id(group.date)
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
            .listStyle(.plain)
            .onChange(of: scrollTarget) { _, id in
                guard let id else { return }
                withAnimation { proxy.scrollTo(id, anchor: .top) }
                scrollTarget = nil
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
                    Button {
                        pickerDate = Date()
                        showDatePicker = true
                    } label: {
                        Image(systemName: "calendar")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        filterMenu
                    } label: {
                        Image(systemName: viewModel.hasActiveFilters ? "mappin.circle.fill" : "mappin.circle")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if viewModel.isLoading {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
            }
            .sheet(isPresented: $showDatePicker) {
                NavigationStack {
                    DatePicker("", selection: $pickerDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .padding(.horizontal)
                        .navigationTitle("Gå till datum")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Gå dit") {
                                    let target = nearestDateId(to: pickerDate)
                                    showDatePicker = false
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                        scrollTarget = target
                                    }
                                }
                            }
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Avbryt") { showDatePicker = false }
                            }
                        }
                }
                .presentationDetents([.medium])
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

// MARK: - Day section header

struct DaySectionHeader: View {
    let displayDate: String
    let obsCount: Int
    let speciesCount: Int

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "calendar")
                .foregroundStyle(.red.opacity(0.6))
            Text(displayDate)
                .fontWeight(.bold)
                .foregroundStyle(.primary)
            Spacer()
            Text("\(obsCount) obs · \(speciesCount) arter")
                .font(.subheadline)
                .foregroundStyle(.primary.opacity(0.6))
        }
        .font(.callout)
        .padding(.vertical, 15)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .background(Color.red.opacity(0.12))
        .padding(.bottom, 2)
        .listRowInsets(EdgeInsets())
        .textCase(nil)
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
