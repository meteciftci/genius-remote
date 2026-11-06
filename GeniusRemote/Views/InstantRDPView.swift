import SwiftUI

enum InstantRDPWindow {
    static let id = "instant-rdp"
}

/// A small window to open an RDP session without saving anything: address, user name and
/// password, then Connect.
struct InstantRDPView: View {
    @Environment(ConnectionLauncher.self) private var launcher
    @Environment(\.dismiss) private var dismiss
    @State private var session = InstantRDP()
    @State private var errorMessage: String?
    @State private var isConnecting = false
    @FocusState private var focusedField: Field?

    private enum Field { case host, port, username, password }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Form {
                TextField("Host", text: $session.host, prompt: Text("192.168.1.10 or server.example.com"))
                    .focused($focusedField, equals: .host)
                    .onSubmit { session.splitPortFromHost(); focusedField = .username }
                TextField("Port", value: $session.port, format: .number.grouping(.never), prompt: Text(verbatim: "\(ConnectionType.rdp.defaultPort)"))
                    .focused($focusedField, equals: .port)
                TextField("Username", text: $session.username, prompt: Text("Required"))
                    .focused($focusedField, equals: .username)
                    .onSubmit { focusedField = .password }
                SecureField("Password", text: $session.password)
                    .focused($focusedField, equals: .password)
                    .onSubmit(connect)
                Toggle("Ignore certificate warnings", isOn: $session.ignoreCertificateErrors)
            }
            .formStyle(.columns)

            if let errorMessage {
                Text(errorMessage)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text("Nothing is saved. The address and password are forgotten once the connection opens.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { close() }
                    .keyboardShortcut(.cancelAction)
                Button("Connect", action: connect)
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(!session.isValid || isConnecting)
            }
        }
        .padding(20)
        .frame(width: 420)
        .onAppear {
            session = InstantRDP()
            errorMessage = nil
            focusedField = .host
            #if DEBUG
            if DemoData.opensInstantRDP {
                session.host = "fs-01.example.com"
                session.username = "EXAMPLE\\admin"
            }
            #endif
        }
        .onDisappear { session = InstantRDP() }
    }

    private func connect() {
        session.splitPortFromHost()
        guard session.isValid, !isConnecting else { return }
        isConnecting = true
        errorMessage = nil
        Task {
            defer { isConnecting = false }
            do {
                try await launcher.connectInstant(session)
                close()
            } catch LaunchError.clientMissing(let client) {
                errorMessage = String(localized: "\(client.title) is not installed")
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func close() {
        session = InstantRDP()
        dismiss()
    }
}
