import Foundation
import CoreBluetooth
import Combine

enum HubState {
    case idle
    case scanning
    case connecting
    case connected
    case error(String)

    var description: String {
        switch self {
        case .idle: return "READY TO SCAN"
        case .scanning: return "SCANNING..."
        case .connecting: return "CONNECTING..."
        case .connected: return "CONNECTED"
        case .error(let msg): return "ERROR: \(msg)"
        }
    }

    var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }
}

class BLEManager: NSObject, ObservableObject {
    static let targetName = "JX-APP-A"
    static let serviceUUID = CBUUID(string: "FFF0")
    static let writeUUID   = CBUUID(string: "FFF2")
    static let notifyUUID  = CBUUID(string: "FFF1")

    @Published var state: HubState = .idle
    @Published var log: [String] = []

    let protocol_ = JXProtocol()

    private var central: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var writeChr: CBCharacteristic?
    private var notifyChr: CBCharacteristic?

    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: .main)
    }

    func startScan() {
        guard central.state == .poweredOn else {
            addLog("Bluetooth not ready")
            return
        }
        state = .scanning
        central.scanForPeripherals(withServices: nil, options: nil)
        addLog("Scanning for \(Self.targetName)...")
    }

    func disconnect() {
        if let p = peripheral {
            central.cancelPeripheralConnection(p)
        }
        peripheral = nil
        writeChr = nil
        notifyChr = nil
        state = .idle
        addLog("Disconnected")
    }

    func send(_ data: Data) {
        guard let chr = writeChr, let p = peripheral, state.isConnected else { return }
        p.writeValue(data, for: chr, type: .withResponse)
    }

    func sendDrive(driveY: Double, steerX: Double) {
        send(protocol_.buildDrivePacket(driveY: driveY, steerX: steerX))
    }

    func addLog(_ message: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let time = formatter.string(from: Date())
        DispatchQueue.main.async {
            self.log.insert("[\(time)] \(message)", at: 0)
            if self.log.count > 50 { self.log.removeLast() }
        }
    }
}

// MARK: - CBCentralManagerDelegate
extension BLEManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            addLog("Bluetooth ON")
        case .poweredOff:
            addLog("Bluetooth OFF")
            state = .idle
        case .unauthorized:
            addLog("Bluetooth unauthorized")
            state = .error("Unauthorized")
        default:
            break
        }
    }

    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any],
                        rssi RSSI: NSNumber) {
        guard peripheral.name == Self.targetName else { return }
        addLog("Found \(Self.targetName) RSSI:\(RSSI)")
        self.peripheral = peripheral
        central.stopScan()
        state = .connecting
        central.connect(peripheral, options: nil)
    }

    func centralManager(_ central: CBCentralManager,
                        didConnect peripheral: CBPeripheral) {
        addLog("Connected! Discovering services...")
        peripheral.delegate = self
        peripheral.discoverServices([Self.serviceUUID])
    }

    func centralManager(_ central: CBCentralManager,
                        didFailToConnect peripheral: CBPeripheral,
                        error: Error?) {
        addLog("Failed: \(error?.localizedDescription ?? "unknown")")
        state = .error("Connection failed")
    }

    func centralManager(_ central: CBCentralManager,
                        didDisconnectPeripheral peripheral: CBPeripheral,
                        error: Error?) {
        addLog("Disconnected")
        writeChr = nil
        notifyChr = nil
        state = .idle
    }
}

// MARK: - CBPeripheralDelegate
extension BLEManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services where service.uuid == Self.serviceUUID {
            addLog("Found service FFF0")
            peripheral.discoverCharacteristics(
                [Self.writeUUID, Self.notifyUUID], for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverCharacteristicsFor service: CBService,
                    error: Error?) {
        guard let chars = service.characteristics else { return }
        for chr in chars {
            if chr.uuid == Self.writeUUID {
                writeChr = chr
                addLog("Found FFF2 (write)")
            }
            if chr.uuid == Self.notifyUUID {
                notifyChr = chr
                peripheral.setNotifyValue(true, for: chr)
                addLog("Found FFF1 (notify)")
            }
        }
        if writeChr != nil {
            state = .connected
            addLog("Ready!")
            send(protocol_.idlePacket)
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        guard let data = characteristic.value else { return }
        let hex = data.map { String(format: "%02x", $0) }.joined(separator: " ")
        addLog("FFF1: \(hex)")
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didWriteValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        if let error = error {
            addLog("Write error: \(error.localizedDescription)")
        }
    }
}
