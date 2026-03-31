import SwiftUI
import MapKit

struct InteractiveMapSheet: View {
    let coordinate: CLLocationCoordinate2D
    let title: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Map(initialPosition: .region(MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            ))) {
                Marker(title, coordinate: coordinate)
                    .tint(Color("AccentGreen"))
            }
            .mapStyle(.standard(elevation: .realistic))
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Klar") { dismiss() }
                }
            }
        }
    }
}
