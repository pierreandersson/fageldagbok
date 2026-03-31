import SwiftUI

struct ArterView: View {
    @Bindable var viewModel: BirdViewModel
    @State private var showLifelist = false

    var body: some View {
        NavigationStack {
            List {
                if showLifelist {
                    lifelistContent
                } else {
                    speciesContent
                }
            }
            .navigationTitle(showLifelist ? "Livslista" : "Arter")
            .searchable(text: $viewModel.searchText, prompt: "Sök art")
            .refreshable { await viewModel.refresh() }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Picker("Vy", selection: $showLifelist) {
                        Text("Arter").tag(false)
                        Text("Livslista").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 180)
                }
            }
        }
    }

    @ViewBuilder
    private var speciesContent: some View {
        Section {
            HStack {
                StatCard(title: "Arter", value: "\(viewModel.species.count)", icon: "bird")
                StatCard(title: "Observationer", value: "\(viewModel.summary?.totalObs ?? 0)", icon: "binoculars")
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }

        Section {
            ForEach(viewModel.filteredSpecies) { species in
                SpeciesRow(
                    name: species.displayName,
                    scientificName: species.scientificName,
                    count: species.observationCount,
                    detail: species.lastSeen
                )
            }
        } header: {
            Text("\(viewModel.filteredSpecies.count) arter")
        }
    }

    @ViewBuilder
    private var lifelistContent: some View {
        Section {
            HStack {
                StatCard(title: "Livslista", value: "\(viewModel.lifelist.count)", icon: "checkmark.circle")
                if let first = viewModel.lifelist.last {
                    StatCard(title: "Första obs", value: String(first.firstDate.prefix(4)), icon: "calendar")
                }
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }

        Section {
            ForEach(viewModel.filteredLifelist) { entry in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(entry.displayName)
                            .font(.body)
                            .fontWeight(.medium)
                        Spacer()
                        Text("\(entry.observationCount) obs")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        if let sci = entry.scientificName {
                            Text(sci)
                                .font(.caption)
                                .italic()
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(entry.firstDate) · \(entry.firstLocality ?? "")")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.vertical, 2)
            }
        } header: {
            Text("Sorterat efter senast tillagd")
        }
    }
}
