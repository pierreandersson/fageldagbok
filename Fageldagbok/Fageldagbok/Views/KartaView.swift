import SwiftUI
import MapKit

struct KartaView: View {
    @Bindable var viewModel: BirdViewModel
    @State private var selectedLocality: Locality?
    @State private var navigationPath = NavigationPath()
    @State private var position: MapCameraPosition = .automatic

    var body: some View {
        NavigationStack(path: $navigationPath) {
            Map(position: $position) {
                ForEach(viewModel.localities) { locality in
                    Annotation(locality.locality, coordinate: CLLocationCoordinate2D(
                        latitude: locality.latitude,
                        longitude: locality.longitude
                    )) {
                        Button {
                            selectedLocality = locality
                        } label: {
                            Circle()
                                .fill(Color("AccentGreen"))
                                .frame(width: markerSize(for: locality), height: markerSize(for: locality))
                                .overlay {
                                    Circle()
                                        .strokeBorder(.white, lineWidth: 1.5)
                                }
                                .shadow(radius: 2)
                        }
                    }
                }
            }
            .mapStyle(.standard(elevation: .realistic))
            .navigationTitle("Karta")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $selectedLocality) { locality in
                localityDetail(locality)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        position = .automatic
                    } label: {
                        Image(systemName: "arrow.trianglehead.counterclockwise")
                    }
                }
            }
            .navigationDestination(for: String.self) { localityName in
                LocalityDetailView(
                    localityName: localityName,
                    allObservations: viewModel.observations
                )
            }
            .navigationDestination(for: LocalityObsDestination.self) { dest in
                LocalityObservationsView(
                    localityName: dest.localityName,
                    allObservations: viewModel.observations
                )
            }
            .navigationDestination(for: LocalitySpeciesDestination.self) { dest in
                LocalitySpeciesView(
                    localityName: dest.localityName,
                    allObservations: viewModel.observations
                )
            }
            .navigationDestination(for: BirdObservation.self) { observation in
                ObservationDetailView(
                    observation: observation,
                    allObservations: viewModel.observations
                )
            }
        }
    }

    private func markerSize(for locality: Locality) -> CGFloat {
        let minSize: CGFloat = 24
        let maxSize: CGFloat = 48
        let maxObs = viewModel.localities.map(\.observationCount).max() ?? 1
        let ratio = CGFloat(locality.observationCount) / CGFloat(max(maxObs, 1))
        return max(minSize, minSize + (maxSize - minSize) * ratio)
    }

    private func localityDetail(_ locality: Locality) -> some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent("Observationer", value: "\(locality.observationCount)")
                    LabeledContent("Arter", value: "\(locality.speciesCount)")
                    if let county = locality.county {
                        LabeledContent("Län", value: county)
                    }
                    if let municipality = locality.municipality {
                        LabeledContent("Kommun", value: municipality)
                    }
                    if let lastVisit = locality.lastVisit {
                        LabeledContent("Senaste besök", value: lastVisit)
                    }
                }

                Section {
                    Button {
                        let name = locality.locality
                        selectedLocality = nil
                        navigationPath.append(name)
                    } label: {
                        Label("Gå till lokal", systemImage: "arrow.right.circle")
                    }
                }
            }
            .navigationTitle(locality.locality)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
