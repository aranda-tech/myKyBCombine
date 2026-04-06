import SwiftUI

struct ScanView: View {
    @EnvironmentObject var ble: BLEManager
    @State private var pulse = false

    var body: some View {
        ZStack {
            Color(hex: "050A12").ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Logo
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .stroke(Color(hex: "00E5FF").opacity(pulse ? 0.8 : 0.3), lineWidth: 2)
                            .frame(width: 80, height: 80)
                            .scaleEffect(pulse ? 1.1 : 1.0)
                            .animation(.easeInOut(duration: 1.5).repeatForever(), value: pulse)

                        Image(systemName: "dot.radiowaves.left.and.right")
                            .font(.system(size: 32))
                            .foregroundColor(Color(hex: "00E5FF"))
                    }

                    Text("KY BLOCKS")
                        .font(.system(size: 28, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(hex: "00E5FF"))
                        .kerning(8)

                    Text("K96234 CONTROLLER")
                        .font(.system(size: 12, weight: .light, design: .monospaced))
                        .foregroundColor(Color(hex: "00E5FF").opacity(0.7))
                        .kerning(4)
                }
                .onAppear { pulse = true }

                Spacer().frame(height: 48)

                // Status
                HStack(spacing: 12) {
                    if isScanning {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "00E5FF")))
                            .scaleEffect(0.8)
                    } else {
                        Circle()
                            .fill(stateColor)
                            .frame(width: 8, height: 8)
                    }
                    Text(ble.state.description)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(stateColor)
                        .kerning(2)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(stateColor.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(stateColor.opacity(0.3), lineWidth: 1)
                )

                Spacer().frame(height: 32)

                // Scan button
                if !isScanning {
                    Button(action: { ble.startScan() }) {
                        Text("SCAN FOR HUB")
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundColor(Color(hex: "00E5FF"))
                            .kerning(3)
                            .padding(.horizontal, 48)
                            .padding(.vertical, 16)
                            .background(Color(hex: "00E5FF").opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color(hex: "00E5FF"), lineWidth: 1.5)
                            )
                    }
                }

                Spacer().frame(height: 32)

                // Log
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(ble.log, id: \.self) { line in
                            Text(line)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.white.opacity(0.4))
                        }
                    }
                    .padding(12)
                }
                .frame(height: 160)
                .background(Color.white.opacity(0.02))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
                .padding(.horizontal, 24)

                Spacer()
            }
        }
    }

    private var isScanning: Bool {
        if case .scanning = ble.state { return true }
        if case .connecting = ble.state { return true }
        return false
    }

    private var stateColor: Color {
        switch ble.state {
        case .connected: return Color(hex: "00FF88")
        case .error: return Color(hex: "FF3366")
        case .scanning, .connecting: return Color(hex: "00E5FF")
        case .idle: return .white.opacity(0.4)
        }
    }
}
