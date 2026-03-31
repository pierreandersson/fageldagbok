import SwiftUI
import MapKit

struct ObservationDetailView: View {
    let observation: BirdObservation
    let allObservations: [BirdObservation]

    private var otherObsOfSameSpecies: [BirdObservation] {
        allObservations.filter {
            $0.taxonId == observation.taxonId && $0.id != observation.id
        }
        .sorted { $0.eventStartDate > $1.eventStartDate }
    }

    private var coordinate: CLLocationCoordinate2D? {
        guard let lat = observation.latitude, let lng = observation.longitude else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }

    var body: some View {
        List {
            // Map
            if let coord = coordinate {
                Section {
                    Map(initialPosition: .region(MKCoordinateRegion(
                        center: coord,
                        span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                    ))) {
                        Marker(observation.displayName, coordinate: coord)
                            .tint(Color("AccentGreen"))
                    }
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }
            }

            // Details
            Section("Observation") {
                LabeledContent("Art", value: observation.displayName)
                if let sci = observation.scientificName {
                    LabeledContent("Vetenskapligt namn") {
                        Text(sci).italic()
                    }
                }
                if let family = observation.family {
                    LabeledContent("Familj", value: family)
                }
                LabeledContent("Datum", value: observation.displayDate)
                if let time = observation.startTime {
                    LabeledContent("Tid", value: time)
                }
                if let count = observation.individualCount, count > 0 {
                    LabeledContent("Antal", value: "\(count)")
                }
                if let activity = observation.activity {
                    LabeledContent("Aktivitet", value: activity)
                }
            }

            Section("Plats") {
                if let locality = observation.locality {
                    NavigationLink(value: locality) {
                        LabeledContent("Lokal", value: locality)
                    }
                }
                if let municipality = observation.municipality {
                    LabeledContent("Kommun", value: municipality)
                }
                if let county = observation.county {
                    LabeledContent("Län", value: county)
                }
            }

            if let remarks = observation.remarks, !remarks.isEmpty {
                Section("Anteckningar") {
                    Text(remarks)
                }
            }

            if observation.isRedlisted == 1, let cat = observation.redlistCategory {
                Section("Rödlistestatus") {
                    LabeledContent("Kategori", value: cat)
                }
            }

            // Other observations of same species
            if !otherObsOfSameSpecies.isEmpty {
                Section("Andra observationer av \(observation.displayName.lowercased()) (\(otherObsOfSameSpecies.count))") {
                    ForEach(otherObsOfSameSpecies) { obs in
                        NavigationLink(value: obs) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(obs.eventStartDate)
                                        .font(.subheadline)
                                    Text(obs.shortLocality)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if let count = obs.individualCount, count > 0 {
                                    Text("\(count) ex")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }

            // Link to Artportalen
            if let urlString = observation.url, let url = URL(string: urlString) {
                Section {
                    Link(destination: url) {
                        Label("Visa på Artportalen", systemImage: "safari")
                    }
                }
            }
        }
        .navigationTitle(observation.displayName)
        .navigationBarTitleDisplayMode(.large)
    }
}
