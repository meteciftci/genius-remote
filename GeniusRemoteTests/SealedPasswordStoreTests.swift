import Foundation
import SwiftData
import Testing
@testable import GeniusRemote

@MainActor
struct SealedPasswordStoreTests {
    private func makeStore() throws -> (SealedPasswordStore, ModelContainer, URL) {
        let container = try AppSchema.container(inMemory: true)
        let keyURL = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString)/secret.key")
        return (SealedPasswordStore(container: container, keyURL: keyURL), container, keyURL)
    }

    @Test func savesAndReadsBack() throws {
        let (store, _, _) = try makeStore()
        let id = UUID()
        try store.setPassword("p@ss wörd", for: id)
        #expect(store.password(for: id) == "p@ss wörd")
    }

    @Test func storedBytesDoNotContainThePassword() throws {
        let (store, container, _) = try makeStore()
        let id = UUID()
        try store.setPassword("hunter2hunter2", for: id)
        let rows = try ModelContext(container).fetch(FetchDescriptor<StoredPassword>())
        #expect(rows.count == 1)
        #expect(rows[0].sealed.range(of: Data("hunter2".utf8)) == nil)
    }

    @Test func emptyOrNilRemovesIt() throws {
        let (store, _, _) = try makeStore()
        let id = UUID()
        try store.setPassword("x", for: id)
        try store.setPassword("", for: id)
        #expect(store.password(for: id) == nil)
        try store.setPassword("y", for: id)
        try store.setPassword(nil, for: id)
        #expect(store.password(for: id) == nil)
    }

    @Test func overwritesAnExistingPassword() throws {
        let (store, _, _) = try makeStore()
        let id = UUID()
        try store.setPassword("old", for: id)
        try store.setPassword("new", for: id)
        #expect(store.password(for: id) == "new")
    }

    @Test func keyFileIsPrivateAndReused() throws {
        let (store, container, keyURL) = try makeStore()
        let id = UUID()
        try store.setPassword("a", for: id)
        let permissions = try FileManager.default.attributesOfItem(atPath: keyURL.path)[.posixPermissions] as? Int
        #expect(permissions == 0o600)
        // A second store on the same key file reads what the first one wrote.
        let other = SealedPasswordStore(container: container, keyURL: keyURL)
        #expect(other.password(for: id) == "a")
    }

    @Test func aLostKeyMeansNoPassword() throws {
        let (store, container, keyURL) = try makeStore()
        let id = UUID()
        try store.setPassword("a", for: id)
        try FileManager.default.removeItem(at: keyURL)
        #expect(SealedPasswordStore(container: container, keyURL: keyURL).password(for: id) == nil)
    }
}
