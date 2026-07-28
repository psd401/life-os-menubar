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
          updatedAt: Date(timeIntervalSince1970: 1_785_200_000),
          dueDate: ProjectDate(githubDate: "2026-07-28"),
          deferUntil: ProjectDate(githubDate: "2026-07-27")
        )
      ],
      lastSyncedAt: Date(timeIntervalSince1970: 1_785_200_100),
      lastFullSyncedAt: Date(timeIntervalSince1970: 1_785_200_050),
      projectFieldAccess: .available
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
        "issues": [{
          "number": 7,
          "title": "Legacy cached task",
          "body": "",
          "labels": [],
          "updatedAt": "2026-07-27T19:00:00Z",
          "state": "OPEN"
        }],
        "lastSyncedAt": "2026-07-27T20:00:00Z"
      }
      """.utf8
    ).write(to: fileURL)

    let snapshot = try #require(try JSONIssueCacheStore(fileURL: fileURL).load())

    #expect(snapshot.lastSyncedAt != nil)
    #expect(snapshot.lastFullSyncedAt == nil)
    #expect(snapshot.projectFieldAccess == .unknown)
    #expect(snapshot.issues.first?.dueDate == nil)
    #expect(snapshot.issues.first?.deferUntil == nil)
  }

  @Test
  func defaultLocationIsInApplicationSupport() {
    let fileURL = JSONIssueCacheStore.defaultFileURL()

    #expect(fileURL.path.contains("Library/Application Support"))
    #expect(fileURL.lastPathComponent == "issues.json")
  }
}
