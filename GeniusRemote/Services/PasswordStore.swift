import CryptoKit
import Foundation
import SwiftData

/// Stores connection passwords, keyed by connection ID.
protocol PasswordStore {
    func password(for id: UUID) -> String?
    func setPassword(_ password: String?, for id: UUID) throws
}

/// Keeps passwords in the connection store, each sealed with AES-GCM. The key is a random 256-bit
/// value in a file only the current user can read, so the database alone (a copy, a backup, a file
/// shared by mistake) doesn't reveal passwords. It doesn't protect against a program running as
/// the same user, which can read the key file too.
final class SealedPasswordStore: PasswordStore {
    /// Set once by the app when its container exists.
    nonisolated(unsafe) static var shared: SealedPasswordStore!

    private let context: ModelContext
    private let keyURL: URL
    private var key: SymmetricKey?

    init(container: ModelContainer, keyURL: URL = SealedPasswordStore.defaultKeyURL) {
        self.context = ModelContext(container)
        self.context.autosaveEnabled = false
        self.keyURL = keyURL
    }

    static var defaultKeyURL: URL {
        URL.applicationSupportDirectory.appending(path: "GeniusRemote/secret.key")
    }

    func password(for id: UUID) -> String? {
        guard let stored = stored(id), let key = try? loadKey(create: false),
              let box = try? AES.GCM.SealedBox(combined: stored.sealed),
              let data = try? AES.GCM.open(box, using: key, authenticating: Data(id.uuidString.utf8))
        else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Saves the password; `nil` or an empty string removes it.
    func setPassword(_ password: String?, for id: UUID) throws {
        let existing = stored(id)
        guard let password, !password.isEmpty else {
            if let existing { context.delete(existing) }
            try context.save()
            return
        }
        let box = try AES.GCM.seal(Data(password.utf8), using: loadKey(create: true), authenticating: Data(id.uuidString.utf8))
        guard let sealed = box.combined else { throw CocoaError(.coderInvalidValue) }
        if let existing {
            existing.sealed = sealed
        } else {
            context.insert(StoredPassword(id: id, sealed: sealed))
        }
        try context.save()
    }

    private func stored(_ id: UUID) -> StoredPassword? {
        var descriptor = FetchDescriptor<StoredPassword>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    /// Reads the key file; with `create`, makes a new key when there is none (or it is unusable).
    private func loadKey(create: Bool) throws -> SymmetricKey {
        if let key { return key }
        if let data = try? Data(contentsOf: keyURL), data.count == 32 {
            let loaded = SymmetricKey(data: data)
            key = loaded
            return loaded
        }
        guard create else { throw CocoaError(.fileReadNoSuchFile) }
        let fresh = SymmetricKey(size: .bits256)
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: keyURL.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        try? fileManager.removeItem(at: keyURL)
        let bytes = fresh.withUnsafeBytes { Data($0) }
        guard fileManager.createFile(atPath: keyURL.path, contents: bytes, attributes: [.posixPermissions: 0o600]) else {
            throw CocoaError(.fileWriteUnknown, userInfo: [NSFilePathErrorKey: keyURL.path])
        }
        key = fresh
        return fresh
    }
}

@Model
final class StoredPassword {
    @Attribute(.unique) var id: UUID
    var sealed: Data

    init(id: UUID, sealed: Data) {
        self.id = id
        self.sealed = sealed
    }
}

/// In-memory store for tests and previews.
final class InMemoryPasswordStore: PasswordStore {
    private(set) var passwords: [UUID: String] = [:]

    func password(for id: UUID) -> String? { passwords[id] }

    func setPassword(_ password: String?, for id: UUID) throws {
        passwords[id] = (password?.isEmpty ?? true) ? nil : password
    }
}
