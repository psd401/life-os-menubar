import Foundation
import Testing

@testable import LifeOSMenubarCore

struct IssueCacheStoreTests {
  @Test
  func roundTripsSnapshotAsJSONAtConfiguredURL() throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("life-os-menubar-issue-3", isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let fileURL = directory.appendingPathComponent("issues.json")
    defer {
      try? FileManager.default.removeItem(at: directory)
    }

    let store = JSONIssueCacheStore(fileURL: fileURL)
    let snapshot = IssueCacheSnapshot(
      issues: [
        LifeOSIssue(
          number: 10,
          title: "Cached task",
          body: "Cached body",
          labels: [GitHubLabel(name: "status:active", color: "123456")],
          updatedAt: Date(timeIntervalSince1970: 1_785_200_000)
        )
      ],
      lastSyncedAt: Date(timeIntervalSince1970: 1_785_200_100),
      lastFullSyncedAt: Date(timeIntervalSince1970: 1_785_200_050)
    )

    try store.save(snapshot)

    #expect(FileManager.default.fileExists(atPath: fileURL.path))
    #expect(try store.load() == snapshot)
  }

  @Test
  func missingCacheReturnsNil() throws {
    let fileURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("life-os-menubar-issue-3", isDirectory: true)
      .appendingPathComponent(UUID().uuidString)
      .appendingPathComponent("missing.json")

    #expect(try JSONIssueCacheStore(fileURL: fileURL).load() == nil)
  }

  @Test
  func loadsCacheCreatedBeforeFullSyncMetadataWasAdded() throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("life-os-menubar-issue-3", isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let fileURL = directory.appendingPathComponent("issues.json")
    defer {
      try? FileManager.default.removeItem(at: directory)
    }
    try FileManager.default.createDirectory(
      at: directory,
      withIntermediateDirectories: true
    )
    try Data(
      """
      {
        "issues": [],
        "lastSyncedAt": "2026-07-27T20:00:00Z"
      }
      """.utf8
    ).write(to: fileURL)

    let snapshot = try #require(try JSONIssueCacheStore(fileURL: fileURL).load())

    #expect(snapshot.lastSyncedAt != nil)
    #expect(snapshot.lastFullSyncedAt == nil)
  }

  @Test
  func defaultLocationIsInApplicationSupport() {
    let fileURL = JSONIssueCacheStore.defaultFileURL()

    #expect(fileURL.path.contains("Library/Application Support"))
    #expect(fileURL.lastPathComponent == "issues.json")
  }
}
