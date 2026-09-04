import Darwin
import Foundation

/// ICMP echo via unprivileged `SOCK_DGRAM`/`IPPROTO_ICMP`. One request every 2 s, 1 s timeout.
/// Results are delivered on the main queue. If the socket cannot be created, `latency` stays nil forever.
final class PingService {
    var latencyMilliseconds: ((Double?) -> Void)?

    private let queue = DispatchQueue(label: "com.local.xeneon.ping", qos: .utility)
    private var host: String
    private var timer: DispatchSourceTimer?
    private var socketFD: Int32 = -1
    private var socketFailed = false
    private let identifier: UInt16
    private var sequence: UInt16 = 0

    init(host: String) {
        self.host = host.trimmingCharacters(in: .whitespacesAndNewlines)
        self.identifier = UInt16(truncatingIfNeeded: getpid())
    }

    deinit {
        stop()
    }

    func start() {
        queue.async { [weak self] in
            self?.openAndSchedule()
        }
    }

    func stop() {
        queue.sync {
            timer?.cancel()
            timer = nil
            closeSocket()
        }
    }

    func setHost(_ host: String) {
        let trimmed = host.trimmingCharacters(in: .whitespacesAndNewlines)
        queue.async { [weak self] in
            self?.host = trimmed
        }
    }

    private func openAndSchedule() {
        guard !socketFailed else { return }
        if socketFD < 0 {
            let fd = socket(AF_INET, SOCK_DGRAM, IPPROTO_ICMP)
            if fd < 0 {
                socketFailed = true
                return
            }
            socketFD = fd
            var timeout = timeval(tv_sec: 1, tv_usec: 0)
            setsockopt(
                fd,
                SOL_SOCKET,
                SO_RCVTIMEO,
                &timeout,
                socklen_t(MemoryLayout<timeval>.size)
            )
        }
        guard timer == nil else { return }

        let source = DispatchSource.makeTimerSource(queue: queue)
        source.schedule(deadline: .now(), repeating: 2.0, leeway: .milliseconds(100))
        source.setEventHandler { [weak self] in
            self?.sendPing()
        }
        source.resume()
        timer = source
    }

    private func closeSocket() {
        if socketFD >= 0 {
            close(socketFD)
            socketFD = -1
        }
    }

    private func sendPing() {
        guard !socketFailed, socketFD >= 0 else { return }
        guard let dest = resolveIPv4(host) else {
            deliver(nil)
            return
        }

        sequence &+= 1
        let packet = makeEchoRequest(identifier: identifier, sequence: sequence)
        let sentAt = Date()
        guard sendPacket(packet, to: dest) else {
            deliver(nil)
            return
        }

        if let elapsed = receiveEchoReply(identifier: identifier, sequence: sequence, sentAt: sentAt) {
            deliver(elapsed)
        } else {
            deliver(nil)
        }
    }

    private func deliver(_ value: Double?) {
        DispatchQueue.main.async { [weak self] in
            self?.latencyMilliseconds?(value)
        }
    }

    private func resolveIPv4(_ host: String) -> sockaddr_in? {
        guard !host.isEmpty else { return nil }
        var hints = addrinfo()
        hints.ai_family = AF_INET
        hints.ai_socktype = SOCK_DGRAM
        hints.ai_protocol = IPPROTO_ICMP
        var result: UnsafeMutablePointer<addrinfo>?
        let status = host.withCString { cHost in
            getaddrinfo(cHost, nil, &hints, &result)
        }
        guard status == 0, let info = result else { return nil }
        defer { freeaddrinfo(result) }
        guard let addr = info.pointee.ai_addr else { return nil }
        return addr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee }
    }

    private func makeEchoRequest(identifier: UInt16, sequence: UInt16) -> [UInt8] {
        var packet = [UInt8](repeating: 0, count: 16)
        packet[0] = UInt8(ICMP_ECHO)
        packet[1] = 0
        packet[4] = UInt8(identifier >> 8)
        packet[5] = UInt8(identifier & 0xFF)
        packet[6] = UInt8(sequence >> 8)
        packet[7] = UInt8(sequence & 0xFF)
        let checksum = icmpChecksum(packet)
        packet[2] = UInt8(checksum >> 8)
        packet[3] = UInt8(checksum & 0xFF)
        return packet
    }

    private func sendPacket(_ packet: [UInt8], to dest: sockaddr_in) -> Bool {
        var destCopy = dest
        let sent = packet.withUnsafeBytes { buf -> ssize_t in
            guard let base = buf.baseAddress else { return -1 }
            return withUnsafePointer(to: &destCopy) { ptr in
                ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                    sendto(socketFD, base, buf.count, 0, sa, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
        }
        return sent == ssize_t(packet.count)
    }

    private func receiveEchoReply(identifier: UInt16, sequence: UInt16, sentAt: Date) -> Double? {
        var buffer = [UInt8](repeating: 0, count: 64)
        var from = sockaddr_in()
        var fromLen = socklen_t(MemoryLayout<sockaddr_in>.size)
        let n = buffer.withUnsafeMutableBytes { buf -> ssize_t in
            guard let base = buf.baseAddress else { return -1 }
            return withUnsafeMutablePointer(to: &from) { ptr in
                ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                    recvfrom(socketFD, base, buf.count, 0, sa, &fromLen)
                }
            }
        }
        guard n >= 8 else { return nil }
        let offset = icmpOffset(in: buffer, count: Int(n))
        guard offset + 8 <= Int(n) else { return nil }
        let type = buffer[offset]
        let id = UInt16(buffer[offset + 4]) << 8 | UInt16(buffer[offset + 5])
        let seq = UInt16(buffer[offset + 6]) << 8 | UInt16(buffer[offset + 7])
        guard type == UInt8(ICMP_ECHOREPLY), id == identifier, seq == sequence else { return nil }
        return Date().timeIntervalSince(sentAt) * 1_000
    }
}

/// SOCK_DGRAM replies start at the ICMP header; some stacks still prefix the IP header.
private func icmpOffset(in buffer: [UInt8], count: Int) -> Int {
    if buffer[0] == UInt8(ICMP_ECHOREPLY) {
        return 0
    }
    if count >= 20, (buffer[0] >> 4) == 4 {
        let ihl = Int(buffer[0] & 0x0F) * 4
        if ihl >= 20, ihl + 8 <= count, buffer[ihl] == UInt8(ICMP_ECHOREPLY) {
            return ihl
        }
    }
    return 0
}

private func icmpChecksum(_ bytes: [UInt8]) -> UInt16 {
    var sum: UInt32 = 0
    var index = 0
    while index + 1 < bytes.count {
        sum += UInt32(bytes[index]) << 8 | UInt32(bytes[index + 1])
        index += 2
    }
    if index < bytes.count {
        sum += UInt32(bytes[index]) << 8
    }
    while sum >> 16 != 0 {
        sum = (sum & 0xFFFF) + (sum >> 16)
    }
    return ~UInt16(truncatingIfNeeded: sum)
}
