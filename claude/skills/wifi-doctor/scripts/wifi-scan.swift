import CoreWLAN
import Foundation

// MARK: - JSON Output Helpers

struct ScanResult: Codable {
    let current: CurrentConnection?
    let networks: [NetworkInfo]
    let interfaceInfo: InterfaceInfo?
    let ssidInferred: Bool
    let error: String?
}

struct CurrentConnection: Codable {
    let ssid: String?
    let rssi: Int
    let noise: Int
    let snr: Int
    let channel: ChannelInfo?
    let phyMode: String
    let txRate: Double
    let security: String
    let ipAddress: String?
}

struct NetworkInfo: Codable {
    let ssid: String?
    let rssi: Int
    let noise: Int
    let channel: ChannelInfo?
}

struct ChannelInfo: Codable {
    let number: Int
    let band: String
    let width: String
}

struct InterfaceInfo: Codable {
    let supportedPHYModes: [String]
    let countryCode: String?
}

// MARK: - Helpers

func bandString(_ band: CWChannelBand) -> String {
    switch band {
    case .band2GHz: return "2.4GHz"
    case .band5GHz: return "5GHz"
    case .band6GHz: return "6GHz"
    default: return "unknown"
    }
}

func widthString(_ width: CWChannelWidth) -> String {
    switch width {
    case .width20MHz: return "20MHz"
    case .width40MHz: return "40MHz"
    case .width80MHz: return "80MHz"
    case .width160MHz: return "160MHz"
    default: return "unknown"
    }
}

func phyModeString(_ mode: CWPHYMode) -> String {
    switch mode {
    case .mode11a: return "802.11a"
    case .mode11b: return "802.11b"
    case .mode11g: return "802.11g"
    case .mode11n: return "802.11n"
    case .mode11ac: return "802.11ac"
    case .mode11ax: return "802.11ax"
    default: return "unknown"
    }
}

func securityString(_ security: CWSecurity) -> String {
    switch security {
    case .none: return "Open"
    case .WEP: return "WEP"
    case .wpaPersonal: return "WPA-Personal"
    case .wpaEnterprise: return "WPA-Enterprise"
    case .wpa2Personal: return "WPA2-Personal"
    case .wpa2Enterprise: return "WPA2-Enterprise"
    case .wpa3Personal: return "WPA3-Personal"
    case .wpa3Enterprise: return "WPA3-Enterprise"
    default: return "unknown"
    }
}

func channelInfo(_ channel: CWChannel?) -> ChannelInfo? {
    guard let ch = channel else { return nil }
    return ChannelInfo(
        number: ch.channelNumber,
        band: bandString(ch.channelBand),
        width: widthString(ch.channelWidth)
    )
}

// MARK: - Main

func main() {
    let client = CWWiFiClient.shared()
    guard let iface = client.interface() else {
        let result = ScanResult(current: nil, networks: [], interfaceInfo: nil, ssidInferred: false, error: "Wi-Fi interface not found")
        outputJSON(result)
        exit(1)
    }

    // Use dynamic interface name instead of hardcoded "en0"
    let ifName = iface.interfaceName ?? "en0"

    func getIPAddress() -> String? {
        let task = Process()
        task.launchPath = "/usr/sbin/ipconfig"
        task.arguments = ["getifaddr", ifName]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            return output?.isEmpty == true ? nil : output
        } catch {
            return nil
        }
    }

    func getCurrentSSID() -> String? {
        if let ssid = iface.ssid() { return ssid }
        let task = Process()
        task.launchPath = "/usr/sbin/networksetup"
        task.arguments = ["-getairportnetwork", ifName]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8),
               let range = output.range(of: "Current Wi-Fi Network: ") {
                return String(output[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        } catch {}
        return nil
    }

    // Guard: detect disconnected state (RSSI=0 and noise=0 means no connection)
    let rssi = iface.rssiValue()
    let noise = iface.noiseMeasurement()
    let isDisconnected = (rssi == 0 && noise == 0) || iface.wlanChannel() == nil

    // Scan nearby networks first (works even when disconnected)
    var networks: [NetworkInfo] = []
    do {
        let scanResults = try iface.scanForNetworks(withSSID: nil)
        for net in scanResults {
            let info = NetworkInfo(
                ssid: net.ssid,
                rssi: net.rssiValue,
                noise: net.noiseMeasurement,
                channel: channelInfo(net.wlanChannel)
            )
            networks.append(info)
        }
        networks.sort { $0.rssi > $1.rssi }
    } catch {
        let result = ScanResult(
            current: nil,
            networks: [],
            interfaceInfo: nil,
            ssidInferred: false,
            error: "Scan failed: \(error.localizedDescription). Grant Location Services access: System Settings > Privacy & Security > Location Services > Enable for Terminal/Claude Code"
        )
        outputJSON(result)
        exit(1)
    }

    // Interface info
    func getSupportedPHYModes() -> [String] {
        let task = Process()
        task.launchPath = "/usr/sbin/system_profiler"
        task.arguments = ["SPAirPortDataType"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8),
               let range = output.range(of: "Supported PHY Modes: ") {
                let line = output[range.upperBound...]
                if let endOfLine = line.firstIndex(of: "\n") {
                    return String(line[..<endOfLine])
                        .components(separatedBy: "/")
                        .map { part in
                            let trimmed = part.trimmingCharacters(in: .whitespaces)
                            return trimmed.hasPrefix("802.") ? trimmed : "802.11" + trimmed
                        }
                }
            }
        } catch {}
        return []
    }

    let ifaceInfo = InterfaceInfo(
        supportedPHYModes: getSupportedPHYModes(),
        countryCode: iface.countryCode()
    )

    // If disconnected, return networks only with null current
    if isDisconnected {
        let result = ScanResult(current: nil, networks: networks, interfaceInfo: ifaceInfo, ssidInferred: false, error: nil)
        outputJSON(result)
        return
    }

    // Build current connection
    var ssidInferred = false
    var resolvedSSID = getCurrentSSID()

    // If SSID still nil, infer from scan results (strongest AP on current channel)
    if resolvedSSID == nil, let currentCh = channelInfo(iface.wlanChannel()) {
        let candidates = networks.filter {
            $0.channel?.number == currentCh.number && $0.channel?.band == currentCh.band
        }
        if let best = candidates.max(by: { $0.rssi < $1.rssi }), best.ssid != nil {
            resolvedSSID = best.ssid
            ssidInferred = true
        }
    }

    let current = CurrentConnection(
        ssid: resolvedSSID,
        rssi: rssi,
        noise: noise,
        snr: rssi - noise,
        channel: channelInfo(iface.wlanChannel()),
        phyMode: phyModeString(iface.activePHYMode()),
        txRate: iface.transmitRate(),
        security: securityString(iface.security()),
        ipAddress: getIPAddress()
    )

    let result = ScanResult(current: current, networks: networks, interfaceInfo: ifaceInfo, ssidInferred: ssidInferred, error: nil)
    outputJSON(result)
}

func outputJSON(_ result: ScanResult) {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    if let data = try? encoder.encode(result), let json = String(data: data, encoding: .utf8) {
        print(json)
    } else {
        fputs("{\"error\": \"JSON encoding failed\"}\n", stderr)
        exit(1)
    }
}

main()
