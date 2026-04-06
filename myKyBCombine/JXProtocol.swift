import Foundation

/// JX-APP-A BLE Protocol for KY Blocks K96234
///
/// Packet structure (14 bytes):
/// [0]    0xAC        - fixed header
/// [1]    mod1        - module ID byte 1 (auto-detected)
/// [2]    mod2        - module ID byte 2 (auto-detected)
/// [3]    0x01        - fixed
/// [4]    ch1         - left wheel  (0x01=fwd, 0x80=stop, 0xFF=rev)
/// [5]    ch2         - right wheel (0x01=fwd, 0x80=stop, 0xFF=rev)
/// [6-11] 0x80        - unused channels
/// [12]   checksum    - sum(bytes[0..11]) & 0xFF
/// [13]   0x35        - fixed footer

class JXProtocol {
    var mod1: UInt8 = 0xBC
    var mod2: UInt8 = 0xB5

    /// Update module bytes from a received/captured packet
    func updateModule(from packet: Data) {
        guard packet.count >= 3, packet[0] == 0xAC else { return }
        mod1 = packet[1]
        mod2 = packet[2]
    }

    /// Convert joystick axis (-1.0 to +1.0) to protocol byte
    /// -1.0 → 0x01 (forward), 0.0 → 0x80 (stop), +1.0 → 0xFF (reverse)
    static func axisToByte(_ value: Double) -> UInt8 {
        let clamped = max(-1.0, min(1.0, value))
        let result = Int(0x80) + Int(clamped * 127)
        return UInt8(max(1, min(255, result)))
    }

    /// Build a drive command packet
    /// - Parameters:
    ///   - driveY: -1.0=forward, +1.0=reverse (left joystick vertical)
    ///   - steerX: -1.0=left, +1.0=right (right joystick horizontal)
    func buildDrivePacket(driveY: Double, steerX: Double) -> Data {
        if abs(driveY) < 0.05 && abs(steerX) > 0.05 {
            // Pure steering — spin wheels in opposite directions
            let ch1 = Self.axisToByte(-steerX)  // left wheel
            let ch2 = Self.axisToByte(steerX)   // right wheel
            return buildPacket(ch1: ch1, ch2: ch2)
        } else {
            // Driving with optional steering mix
            var left = driveY
            var right = driveY
            if steerX > 0 {
                right = max(-1.0, min(1.0, right + steerX))
            } else if steerX < 0 {
                left = max(-1.0, min(1.0, left - abs(steerX)))
            }
            return buildPacket(ch1: Self.axisToByte(left), ch2: Self.axisToByte(right))
        }
    }

    /// Build raw packet with explicit channel bytes
    func buildPacket(ch1: UInt8, ch2: UInt8) -> Data {
        var packet: [UInt8] = [
            0xAC, mod1, mod2, 0x01,
            ch1, ch2,
            0x80, 0x80, 0x80, 0x80, 0x80, 0x80,
            0x00, // checksum
            0x35
        ]
        packet[12] = checksum(packet)
        return Data(packet)
    }

    private func checksum(_ packet: [UInt8]) -> UInt8 {
        let sum = packet[0..<12].reduce(0) { (acc: Int, b: UInt8) in acc + Int(b) }
        return UInt8(sum & 0xFF)
    }

    var idlePacket: Data { buildPacket(ch1: 0x80, ch2: 0x80) }
    var forwardPacket: Data { buildPacket(ch1: 0x01, ch2: 0x01) }
    var reversePacket: Data { buildPacket(ch1: 0xFF, ch2: 0xFF) }
    var spinRightPacket: Data { buildPacket(ch1: 0x01, ch2: 0xFF) }
    var spinLeftPacket: Data { buildPacket(ch1: 0xFF, ch2: 0x01) }
}
