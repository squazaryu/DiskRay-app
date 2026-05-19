import Foundation
import Darwin

enum WakeOnLANServiceError: LocalizedError {
    case invalidMACAddress
    case invalidBroadcastAddress
    case socketCreationFailed(String)
    case socketOptionFailed(String)
    case sendFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidMACAddress:
            return "MAC address format is invalid."
        case .invalidBroadcastAddress:
            return "Broadcast IPv4 address is invalid."
        case let .socketCreationFailed(reason):
            return "Failed to create UDP socket: \(reason)"
        case let .socketOptionFailed(reason):
            return "Failed to configure UDP broadcast: \(reason)"
        case let .sendFailed(reason):
            return "Failed to send magic packet: \(reason)"
        }
    }
}

actor WakeOnLANService {
    func sendMagicPacket(
        macAddress: String,
        broadcastAddress: String,
        port: UInt16
    ) throws -> Int {
        let mac = try parseMACAddress(macAddress)
        let packet = buildMagicPacket(mac: mac)

        let socketFD = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard socketFD >= 0 else {
            throw WakeOnLANServiceError.socketCreationFailed(lastErrnoMessage())
        }
        defer {
            _ = close(socketFD)
        }

        var allowBroadcast: Int32 = 1
        let socketOptionResult = withUnsafePointer(to: &allowBroadcast) { ptr in
            setsockopt(socketFD, SOL_SOCKET, SO_BROADCAST, ptr, socklen_t(MemoryLayout<Int32>.size))
        }
        guard socketOptionResult == 0 else {
            throw WakeOnLANServiceError.socketOptionFailed(lastErrnoMessage())
        }

        var targetAddress = sockaddr_in()
        targetAddress.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        targetAddress.sin_family = sa_family_t(AF_INET)
        targetAddress.sin_port = in_port_t(port).bigEndian

        let conversionResult = broadcastAddress.withCString { cString in
            inet_pton(AF_INET, cString, &targetAddress.sin_addr)
        }
        guard conversionResult == 1 else {
            throw WakeOnLANServiceError.invalidBroadcastAddress
        }

        let sendResult = withUnsafePointer(to: &targetAddress) { pointer -> Int in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { rebound in
                packet.withUnsafeBytes { bytes -> Int in
                    guard let baseAddress = bytes.baseAddress else { return -1 }
                    return sendto(
                        socketFD,
                        baseAddress,
                        bytes.count,
                        0,
                        rebound,
                        socklen_t(MemoryLayout<sockaddr_in>.size)
                    )
                }
            }
        }

        guard sendResult == packet.count else {
            throw WakeOnLANServiceError.sendFailed(lastErrnoMessage())
        }

        return sendResult
    }

    private func parseMACAddress(_ value: String) throws -> [UInt8] {
        let hex = value.lowercased().filter { $0.isHexDigit }
        guard hex.count == 12 else {
            throw WakeOnLANServiceError.invalidMACAddress
        }

        var bytes: [UInt8] = []
        bytes.reserveCapacity(6)

        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            let chunk = hex[index..<next]
            guard let byte = UInt8(chunk, radix: 16) else {
                throw WakeOnLANServiceError.invalidMACAddress
            }
            bytes.append(byte)
            index = next
        }
        return bytes
    }

    private func buildMagicPacket(mac: [UInt8]) -> [UInt8] {
        var bytes = Array(repeating: UInt8(0xFF), count: 6)
        for _ in 0..<16 {
            bytes.append(contentsOf: mac)
        }
        return bytes
    }

    private func lastErrnoMessage() -> String {
        if let cString = strerror(errno) {
            return String(cString: cString)
        }
        return "unknown error"
    }
}
