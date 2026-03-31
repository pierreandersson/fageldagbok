import SwiftUI

struct ObservationRow: View {
    let observation: BirdObservation

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(observation.displayName)
                        .font(.body)
                        .fontWeight(.medium)
                    if observation.isRedlisted == 1, let cat = observation.redlistCategory {
                        Text(cat)
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(redlistColor(cat).opacity(0.15))
                            .foregroundStyle(redlistColor(cat))
                            .clipShape(Capsule())
                    }
                }
                if let sci = observation.scientificName {
                    Text(sci)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .italic()
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                if let count = observation.individualCount, count > 0 {
                    Text("\(count) ex")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if let time = observation.startTime {
                    Text(time)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private func redlistColor(_ category: String) -> Color {
        switch category {
        case "CR": .red
        case "EN": .orange
        case "VU": .yellow
        case "NT": .blue
        default: .gray
        }
    }
}
