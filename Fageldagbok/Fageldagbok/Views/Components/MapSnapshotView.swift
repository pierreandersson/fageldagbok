import SwiftUI
import MapKit

struct MapSnapshotView: View {
    let coordinate: CLLocationCoordinate2D
    let title: String

    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Rectangle()
                    .fill(Color(.systemGray5))
                    .overlay {
                        ProgressView()
                    }
            }
        }
        .task(id: "\(coordinate.latitude),\(coordinate.longitude)") {
            await generateSnapshot()
        }
    }

    private func generateSnapshot() async {
        let options = MKMapSnapshotter.Options()
        options.region = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
        options.size = CGSize(width: 400, height: 200)
        options.scale = UIScreen.main.scale

        let snapshotter = MKMapSnapshotter(options: options)
        guard let snapshot = try? await snapshotter.start() else { return }

        let renderer = UIGraphicsImageRenderer(size: options.size)
        let finalImage = renderer.image { context in
            snapshot.image.draw(at: .zero)

            // Draw pin
            let point = snapshot.point(for: coordinate)
            let pinSize: CGFloat = 12
            let pinRect = CGRect(
                x: point.x - pinSize / 2,
                y: point.y - pinSize,
                width: pinSize,
                height: pinSize
            )
            UIColor(red: 45/255, green: 106/255, blue: 79/255, alpha: 1).setFill()
            UIBezierPath(ovalIn: pinRect).fill()
            UIColor.white.setStroke()
            let strokePath = UIBezierPath(ovalIn: pinRect)
            strokePath.lineWidth = 2
            strokePath.stroke()
        }

        await MainActor.run {
            self.image = finalImage
        }
    }
}
