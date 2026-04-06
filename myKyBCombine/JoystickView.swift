import SwiftUI

struct JoystickView: View {
    let label: String
    var verticalOnly: Bool = false
    var horizontalOnly: Bool = false
    let onChange: (Double, Double) -> Void
    let onRelease: () -> Void

    @State private var offset: CGSize = .zero
    @State private var isDragging = false

    private let size: CGFloat = 140
    private let stickSize: CGFloat = 48
    private var maxDist: CGFloat { (size / 2) - (stickSize / 2) }

    var body: some View {
        VStack(spacing: 8) {
            Text(label)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(Color(hex: "00E5FF"))
                .kerning(2)

            ZStack {
                // Outer ring
                Circle()
                    .fill(Color(hex: "00E5FF").opacity(0.1))
                    .overlay(
                        Circle()
                            .stroke(Color(hex: "00E5FF").opacity(0.4), lineWidth: 1.5)
                    )

                // Cross lines
                Rectangle()
                    .fill(Color(hex: "00E5FF").opacity(0.2))
                    .frame(width: 1, height: size - 16)
                Rectangle()
                    .fill(Color(hex: "00E5FF").opacity(0.2))
                    .frame(width: size - 16, height: 1)

                // Stick
                Circle()
                    .fill(
                        RadialGradient(
                            colors: isDragging
                                ? [Color(hex: "00E5FF"), Color(hex: "0088AA")]
                                : [Color(hex: "0088CC"), Color(hex: "004466")],
                            center: .center,
                            startRadius: 0,
                            endRadius: 24
                        )
                    )
                    .frame(width: stickSize, height: stickSize)
                    .overlay(
                        Circle()
                            .stroke(
                                Color(hex: "00E5FF").opacity(isDragging ? 1.0 : 0.6),
                                lineWidth: 2
                            )
                    )
                    .overlay(
                        Circle()
                            .fill(Color(hex: "00E5FF").opacity(0.8))
                            .frame(width: 8, height: 8)
                    )
                    .shadow(color: Color(hex: "00E5FF").opacity(0.3), radius: 12)
                    .offset(offset)
            }
            .frame(width: size, height: size)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isDragging = true
                        var delta = value.translation
                        if verticalOnly { delta.width = 0 }
                        if horizontalOnly { delta.height = 0 }

                        let dist = sqrt(delta.width * delta.width + delta.height * delta.height)
                        if dist > maxDist {
                            let scale = maxDist / dist
                            delta = CGSize(width: delta.width * scale, height: delta.height * scale)
                        }
                        offset = delta
                        onChange(Double(delta.width / maxDist), Double(delta.height / maxDist))
                    }
                    .onEnded { _ in
                        isDragging = false
                        offset = .zero
                        onRelease()
                    }
            )
        }
    }
}

// MARK: - Color extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int & 0xFF0000) >> 16) / 255
        let g = Double((int & 0x00FF00) >> 8) / 255
        let b = Double(int & 0x0000FF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
