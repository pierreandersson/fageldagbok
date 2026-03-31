import SwiftUI
import MapKit

// MARK: - Locality info page (step 1)

struct LocalityDetailView: View {
    let localityName: String
    let allObservations: [BirdObservation]

    private var localityObs: [BirdObservation] {
        allObservations.filter { $0.locality == localityName }
    }

    private var coordinate: CLLocationCoordinate2D? {
        guard let first = localityObs.first(where: { $0.latitude != nil }) else { return nil }
        return CLLocationCoordinate2D(latitude: first.latitude!, longitude: first.longitude!)
    }

    private var speciesCount: Int {
        Set(localityObs.map(\.taxonId)).count
    }

    private var visitCount: Int {
        Set(localityObs.map(\.eventStartDate)).count
    }

    private var dateRange: String {
        let dates = localityObs.map(\.eventStartDate).sorted()
        guard let first = dates.first, let last = dates.last else { return "" }
        if first == last { return first }
        return "\(first) – \(last)"
    }

    var body: some View {
        List {
            if let coord = coordinate {
                Section {
                    Map(initialPosition: .region(MKCoordinateRegion(
                        center: coord,
                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                    ))) {
                        Marker(localityName, coordinate: coord)
                            .tint(Color("AccentGreen"))
                    }
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }
            }

            Section {
                HStack(spacing: 0) {
                    StatCard(title: "Observationer", value: "\(localityObs.count)", icon: "binoculars")
                    StatCard(title: "Arter", value: "\(speciesCount)", icon: "bird")
                    StatCard(title: "Besök", value: "\(visitCount)", icon: "calendar")
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            Section("Plats") {
                if let county = localityObs.first?.county {
                    LabeledContent("Län", value: county)
                }
                if let municipality = localityObs.first?.municipality {
                    LabeledContent("Kommun", value: municipality)
                }
                if !dateRange.isEmpty {
                    LabeledContent("Period", value: dateRange)
                }
            }

            Section {
                NavigationLink(value: LocalityObsDestination(localityName: localityName)) {
                    Label("Observationer (\(localityObs.count))", systemImage: "list.bullet")
                }
                NavigationLink(value: LocalitySpeciesDestination(localityName: localityName)) {
                    Label("Arter (\(speciesCount))", systemImage: "bird")
                }
            }
        }
        .navigationTitle(localityName.components(separatedBy: ", ").first ?? localityName)
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - Navigation destinations

struct LocalityObsDestination: Hashable {
    let localityName: String
}

struct LocalitySpeciesDestination: Hashable {
    let localityName: String
}

// MARK: - Observations list (step 2a)

struct LocalityObservationsView: View {
    let localityName: String
    let allObservations: [BirdObservation]

    @State private var searchText = ""
    @State private var selectedYear: Int?

    private var localityObs: [BirdObservation] {
        allObservations.filter { $0.locality == localityName }
            .sorted { $0.eventStartDate > $1.eventStartDate }
    }

    private var filteredObs: [BirdObservation] {
        var result = localityObs
        if let year = selectedYear {
            result = result.filter { $0.eventStartDate.hasPrefix(String(year)) }
        }
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter {
                ($0.vernacularName?.lowercased().contains(query) ?? false) ||
                ($0.scientificName?.lowercased().contains(query) ?? false)
            }
        }
        return result
    }

    private var availableYears: [Int] {
        let years = Set(localityObs.compactMap { Int($0.eventStartDate.prefix(4)) })
        return years.sorted(by: >)
    }

    private var groupedByDate: [(date: String, observations: [BirdObservation])] {
        let grouped = Dictionary(grouping: filteredObs) { $0.eventStartDate }
        return grouped.keys.sorted(by: >).map { date in
            (date: date, observations: grouped[date]!)
        }
    }

    var body: some View {
        List {
            Section {
                Text(localityName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Sök art", text: $searchText)
                        .textFieldStyle(.plain)
                    if !searchText.isEmpty {
                        Button { searchText = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            ForEach(groupedByDate, id: \.date) { group in
                Section(group.date) {
                    ForEach(group.observations) { obs in
                        NavigationLink(value: obs) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(obs.displayName)
                                        .font(.body)
                                    if let time = obs.startTime {
                                        Text(time)
                                            .font(.caption)
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                                Spacer()
                                if let count = obs.individualCount, count > 0 {
                                    Text("\(count) ex")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }

            if filteredObs.isEmpty && !searchText.isEmpty {
                Text("Inga träffar för \"\(searchText)\"")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Observationer")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Alla år") { selectedYear = nil }
                    ForEach(availableYears, id: \.self) { year in
                        Button {
                            selectedYear = year
                        } label: {
                            if selectedYear == year {
                                Label(String(year), systemImage: "checkmark")
                            } else {
                                Text(String(year))
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                        if let year = selectedYear {
                            Text(String(year))
                                .font(.subheadline)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Species list (step 2b)

struct LocalitySpeciesView: View {
    let localityName: String
    let allObservations: [BirdObservation]

    @State private var searchText = ""

    private var localityObs: [BirdObservation] {
        allObservations.filter { $0.locality == localityName }
    }

    private var uniqueSpecies: [(name: String, scientificName: String?, count: Int, taxonId: Int, lastSeen: String)] {
        let grouped = Dictionary(grouping: localityObs) { $0.taxonId }
        return grouped.map { (taxonId, obs) in
            let sorted = obs.sorted { $0.eventStartDate > $1.eventStartDate }
            return (
                name: sorted.first?.displayName ?? "Okänd",
                scientificName: sorted.first?.scientificName,
                count: obs.count,
                taxonId: taxonId,
                lastSeen: sorted.first?.eventStartDate ?? ""
            )
        }
        .sorted { $0.count > $1.count }
    }

    private var filteredSpecies: [(name: String, scientificName: String?, count: Int, taxonId: Int, lastSeen: String)] {
        guard !searchText.isEmpty else { return uniqueSpecies }
        let query = searchText.lowercased()
        return uniqueSpecies.filter {
            $0.name.lowercased().contains(query) ||
            ($0.scientificName?.lowercased().contains(query) ?? false)
        }
    }

    var body: some View {
        List {
            Section {
                Text(localityName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Sök art", text: $searchText)
                        .textFieldStyle(.plain)
                    if !searchText.isEmpty {
                        Button { searchText = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Section("\(filteredSpecies.count) arter") {
                ForEach(filteredSpecies, id: \.taxonId) { species in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(species.name)
                                .font(.body)
                            if let sci = species.scientificName {
                                Text(sci)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .italic()
                            }
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(species.count) obs")
                                .font(.caption)
                                .foregroundStyle(Color("AccentGreen"))
                                .fontWeight(.semibold)
                            Text(species.lastSeen)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .navigationTitle("Arter")
        .navigationBarTitleDisplayMode(.inline)
    }
}
