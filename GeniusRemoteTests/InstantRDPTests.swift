import Foundation
import Testing
@testable import GeniusRemote

struct InstantRDPTests {
    private func session(host: String = "srv", port: Int? = 3389, username: String = "admin") -> InstantRDP {
        InstantRDP(host: host, port: port, username: username, password: "secret")
    }

    @Test func needsHostAndUsername() {
        #expect(session().isValid)
        #expect(!session(host: "  ").isValid)
        #expect(!session(host: "a b").isValid)
        #expect(!session(username: " ").isValid)
    }

    @Test func rejectsBadPort() {
        #expect(!session(port: nil).isValid)
        #expect(!session(port: 0).isValid)
        #expect(!session(port: 70000).isValid)
    }

    @Test func movesTypedPortOutOfHost() {
        var value = session(host: " srv.example.com:3390 ")
        value.splitPortFromHost()
        #expect(value.host == "srv.example.com")
        #expect(value.port == 3390)
    }

    @Test func leavesIPv6AndPlainHostsAlone() {
        var ipv6 = session(host: "fe80::1")
        ipv6.splitPortFromHost()
        #expect(ipv6.host == "fe80::1")
        #expect(ipv6.port == 3389)

        var plain = session(host: "srv")
        plain.splitPortFromHost()
        #expect(plain.host == "srv")
    }

    @Test func targetIsAnUnsavedRDPConnectionWithoutPassword() {
        let target = session(host: " srv ", port: 3390).target
        #expect(target.type == .rdp)
        #expect(target.host == "srv")
        #expect(target.name == "srv")
        #expect(target.port == 3390)
        #expect(target.username == "admin")
    }
}
