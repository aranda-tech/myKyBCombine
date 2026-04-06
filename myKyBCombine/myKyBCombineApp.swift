import SwiftUI

@main
struct KYBlocksApp: App {
    @StateObject private var ble = BLEManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(ble)
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var ble: BLEManager

    var body: some View {
        Group {
            if ble.state.isConnected {
                ControllerView()
                    .environmentObject(ble)
            } else {
                ScanView()
                    .environmentObject(ble)
            }
        }
        .preferredColorScheme(.dark)
    }
}
