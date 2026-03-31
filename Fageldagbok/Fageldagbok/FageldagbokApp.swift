import SwiftUI

@main
struct FageldagbokApp: App {
    @State private var viewModel = BirdViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel)
        }
    }
}

struct ContentView: View {
    @Bindable var viewModel: BirdViewModel

    var body: some View {
        TabView {
            Tab("Dagbok", systemImage: "book") {
                DagbokView(viewModel: viewModel)
            }
            Tab("Arter", systemImage: "bird") {
                ArterView(viewModel: viewModel)
            }
            Tab("Karta", systemImage: "map") {
                KartaView(viewModel: viewModel)
            }
            Tab("Statistik", systemImage: "chart.bar") {
                StatistikView(viewModel: viewModel)
            }
        }
        .tint(Color("AccentGreen"))
    }
}
