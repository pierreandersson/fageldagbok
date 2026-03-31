import SwiftUI
import Charts

struct StatistikView: View {
    @Bindable var viewModel: BirdViewModel

    private let monthNames = ["jan", "feb", "mar", "apr", "maj", "jun",
                              "jul", "aug", "sep", "okt", "nov", "dec"]

    var body: some View {
        NavigationStack {
            List {
                if let stats = viewModel.stats {
                    // Per year chart
                    Section("Arter per år") {
                        Chart(stats.perYear) { year in
                            BarMark(
                                x: .value("År", String(year.year)),
                                y: .value("Arter", year.speciesCount)
                            )
                            .foregroundStyle(Color("AccentGreen"))
                        }
                        .frame(height: 200)
                        .padding(.vertical, 8)
                    }

                    // Per month chart
                    Section("Observationer per månad") {
                        Chart(stats.perMonth) { month in
                            BarMark(
                                x: .value("Månad", monthNames[safe: month.month - 1] ?? ""),
                                y: .value("Obs", month.obsCount)
                            )
                            .foregroundStyle(Color("AccentGreen").opacity(0.8))
                        }
                        .frame(height: 200)
                        .padding(.vertical, 8)
                    }

                    // Top species
                    Section("Mest observerade arter") {
                        ForEach(stats.topSpecies) { item in
                            HStack {
                                Text(item.vernacularName.prefix(1).uppercased() + item.vernacularName.dropFirst())
                                    .font(.body)
                                Spacer()
                                Text("\(item.count) obs")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    // Top localities
                    Section("Mest besökta lokaler") {
                        ForEach(stats.topLocalities) { item in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(item.locality)
                                        .font(.body)
                                    Text("\(item.speciesCount) arter")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                                Spacer()
                                Text("\(item.count) obs")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } else if viewModel.isLoading {
                    ProgressView("Laddar statistik...")
                }
            }
            .navigationTitle("Statistik")
            .refreshable { await viewModel.refresh() }
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
