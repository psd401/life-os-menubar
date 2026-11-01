import Foundation

public struct IssueCacheSnapshot: Codable, Equatable, Sendable {
  public let issues: [LifeOSIssue]
  public let lastSyncedAt: Date?
  public let lastFullSyncedAt: Date?
  public let projectFieldAccess: ProjectFieldAccess

  public init(
    issues: [LifeOSIssue],
    lastSyncedAt: Date?,
    lastFullSyncedAt: Date? = nil,
    projectFieldAccess: ProjectFieldAccess = .unknown
  ) {
    self.issues = issues
    self.lastSyncedAt = lastSyncedAt
    self.lastFullSyncedAt = lastFullSyncedAt
    self.projectFieldAccess = projectFieldAccess
  }

  public static let empty = IssueCacheSnapshot(
    issues: [],
    lastSyncedAt: nil,
    lastFullSyncedAt: nil,
    projectFieldAccess: .unknown
  )

  private enum CodingKeys: String, CodingKey {
    case issues
    case lastSyncedAt
    case lastFullSyncedAt
    case projectFieldAccess
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.issues = try container.decode([LifeOSIssue].self, forKey: .issues)
    self.lastSyncedAt = try container.decodeIfPresent(Date.self, forKey: .lastSyncedAt)
    self.lastFullSyncedAt = try container.decodeIfPresent(Date.self, forKey: .lastFullSyncedAt)
    self.projectFieldAccess =
      try container.decodeIfPresent(ProjectFieldAccess.self, forKey: .projectFieldAccess)
      ?? .unknown
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(issues, forKey: .issues)
    try container.encodeIfPresent(lastSyncedAt, forKey: .lastSyncedAt)
    try container.encodeIfPresent(lastFullSyncedAt, forKey: .lastFullSyncedAt)
    try container.encode(projectFieldAccess, forKey: .projectFieldAccess)
  }
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
