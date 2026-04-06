import SwiftUI
import Combine

struct ControllerView: View {
    @EnvironmentObject var ble: BLEManager

    @State private var driveY: Double = 0
    @State private var steerX: Double = 0
    @State private var timer: AnyCancellable?
    
    @State private var lastDriveY: Double = 0
    @State private var lastSteerX: Double = 0

    var body: some View {
        ZStack {
            Color(hex: "050A12").ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                speedBars
                Spacer()
                joysticks
                Spacer()
                bottomBar
            }
        }
        .onAppear { startTimer() }
        .onDisappear { timer?.cancel() }
    }

    // MARK: - Top Bar
    var topBar: some View {
        HStack {
            // Connection dot
            HStack(spacing: 8) {
                Circle()
                    .fill(Color(hex: "00FF88"))
                    .frame(width: 8, height: 8)
                Text("JX-APP-A")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(Color(hex: "00FF88"))
                    .kerning(2)
            }

            Spacer()

            Text("KY BLOCKS K96234")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(Color(hex: "00E5FF"))
                .kerning(3)

            Spacer()

            // Disconnect
            Button(action: { ble.disconnect() }) {
                Text("DISC")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(Color(hex: "FF3366"))
                    .kerning(1)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 2)
                            .stroke(Color(hex: "FF3366").opacity(0.5), lineWidth: 1)
                    )
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .overlay(
            Rectangle()
                .fill(Color(hex: "00E5FF").opacity(0.15))
                .frame(height: 1),
            alignment: .bottom
        )
    }

    // MARK: - Speed Bars
    var speedBars: some View {
        HStack {
            speedBar(label: "L", value: driveY, positive: driveY < 0)
            Spacer()
            speedBar(label: "R", value: steerX, positive: steerX > 0)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    func speedBar(label: String, value: Double, positive: Bool) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(Color(hex: "00E5FF"))

            GeometryReader { geo in
                ZStack(alignment: positive ? .trailing : .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white.opacity(0.05))
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(hex: "00E5FF"))
                        .frame(width: geo.size.width * abs(value))
                }
            }
            .frame(width: 80, height: 4)

            Text("\(Int(abs(value) * 100))%")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(Color(hex: "00E5FF"))
                .frame(width: 32, alignment: .trailing)
        }
    }

    // MARK: - Joysticks
    var joysticks: some View {
        HStack {
            // Left joystick - drive (vertical only)
            JoystickView(
                label: "DRIVE",
                verticalOnly: true,
                onChange: { _, y in driveY = y },
                onRelease: { driveY = 0 }
            )

            Spacer()

            // Center direction label
            VStack(spacing: 8) {
                Text(directionLabel)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(hex: "00E5FF"))
                    .kerning(3)
                    .animation(.none, value: directionLabel)

                Rectangle()
                    .fill(Color(hex: "00E5FF").opacity(0.2))
                    .frame(width: 1, height: 40)
            }

            Spacer()

            // Right joystick - steer (horizontal only)
            JoystickView(
                label: "STEER",
                horizontalOnly: true,
                onChange: { x, _ in steerX = x },
                onRelease: { steerX = 0 }
            )
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Bottom Bar
    var bottomBar: some View {
        HStack {
            Spacer()
            Text("MODULE: \(String(format: "%02X", ble.protocol_.mod1)) \(String(format: "%02X", ble.protocol_.mod2))")
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.white.opacity(0.25))
                .kerning(2)
            Spacer()
        }
        .padding(.vertical, 10)
        .overlay(
            Rectangle()
                .fill(Color(hex: "00E5FF").opacity(0.15))
                .frame(height: 1),
            alignment: .top
        )
    }

    // MARK: - Helpers

    var directionLabel: String {
        var parts: [String] = []
        if driveY < -0.1 { parts.append("FWD") }
        else if driveY > 0.1 { parts.append("REV") }
        if steerX > 0.1 { parts.append("+R") }
        else if steerX < -0.1 { parts.append("+L") }
        return parts.isEmpty ? "IDLE" : parts.joined()
    }

    func startTimer() {
        timer = Timer.publish(every: 0.06, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                // Only send if values changed or non-zero (keep-alive)
                let changed = driveY != lastDriveY || steerX != lastSteerX
                let active = abs(driveY) > 0.01 || abs(steerX) > 0.01
                if changed || active {
                    ble.sendDrive(driveY: driveY, steerX: steerX)
                    lastDriveY = driveY
                    lastSteerX = steerX
                }
            }
    }
}
