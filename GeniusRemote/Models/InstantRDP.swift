import Foundation

/// What the Instant RDP window collects. Nothing here is saved: it becomes a one-off
/// `ConnectionTarget` and the password goes straight to the RDP client.
nonisolated struct InstantRDP: Equatable, Sendable {
    var host = ""
    var port: Int? = ConnectionType.rdp.defaultPort
    var username = ""
    var password = ""
    var ignoreCertificateErrors = false

    var trimmedHost: String { host.trimmingCharacters(in: .whitespacesAndNewlines) }
    var trimmedUsername: String { username.trimmingCharacters(in: .whitespacesAndNewlines) }

    var isPortValid: Bool {
        guard let port else { return false }
        return (1...65535).contains(port)
    }

    var isValid: Bool {
        !trimmedHost.isEmpty && !trimmedHost.contains(where: \.isWhitespace) && !trimmedUsername.isEmpty && isPortValid
    }

    /// Moves a `host:port` typed into the address field to the port field. IPv6 addresses
    /// (more than one colon) and bracketed ones are left alone.
    mutating func splitPortFromHost() {
        let value = trimmedHost
        guard value.filter({ $0 == ":" }).count == 1,
              let colon = value.firstIndex(of: ":"),
              let typedPort = Int(value[value.index(after: colon)...]) else { return }
        host = String(value[..<colon])
        port = typedPort
    }

    var target: ConnectionTarget {
        ConnectionTarget(
            id: UUID(),
            name: trimmedHost,
            host: trimmedHost,
            type: .rdp,
            port: port ?? ConnectionType.rdp.defaultPort,
            username: trimmedUsername,
            ignoreCertificateErrors: ignoreCertificateErrors,
            rdp: RDPDefaults.load()
        )
    }
}
