import Foundation

public struct IssueCacheSnapshot: Codable, Equatable, Sendable {
  public let issues: [LifeOSIssue]
  public let lastSyncedAt: Date?

  public init(issues: [LifeOSIssue], lastSyncedAt: Date?) {
    self.issues = issues
    self.lastSyncedAt = lastSyncedAt
  }

  public static let empty = IssueCacheSnapshot(issues: [], lastSyncedAt: nil)
}

public protocol IssueCacheStoring: Sendable {
  func load() throws -> IssueCacheSnapshot?
  func save(_ snapshot: IssueCacheSnapshot) throws
}

public struct JSONIssueCacheStore: IssueCacheStoring {
  public let fileURL: URL

  public init(fileURL: URL = JSONIssueCacheStore.defaultFileURL()) {
    self.fileURL = fileURL
  }

  public func load() throws -> IssueCacheSnapshot? {
    guard FileManager.default.fileExists(atPath: fileURL.path) else {
      return nil
    }

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return try decoder.decode(
      IssueCacheSnapshot.self,
      from: Data(contentsOf: fileURL, options: .mappedIfSafe)
    )
  }

  public func save(_ snapshot: IssueCacheSnapshot) throws {
    try FileManager.default.createDirectory(
      at: fileURL.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )

    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try encoder.encode(snapshot).write(to: fileURL, options: .atomic)
  }

  public static func defaultFileURL() -> URL {
    let applicationSupport =
      FileManager.default.urls(
        for: .applicationSupportDirectory,
        in: .userDomainMask
      ).first
      ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(
        "Library/Application Support",
        isDirectory: true
      )

    return
      applicationSupport
      .appendingPathComponent("LifeOSMenubar", isDirectory: true)
      .appendingPathComponent("issues.json", isDirectory: false)
  }
}
