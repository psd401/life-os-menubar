import Foundation

public struct SavedTaskFilter: Codable, Equatable, Identifiable, Sendable {
  public let id: UUID
  public let name: String
  public let selection: TaskFilterSelection

  public init(
    id: UUID = UUID(),
    name: String,
    selection: TaskFilterSelection
  ) {
    self.id = id
    self.name = name
    self.selection = selection
  }
}

public struct TaskFilterStoreSnapshot: Codable, Equatable, Sendable {
  public let activeSelection: TaskFilterSelection
  public let savedFilters: [SavedTaskFilter]

  public init(
    activeSelection: TaskFilterSelection,
    savedFilters: [SavedTaskFilter]
  ) {
    self.activeSelection = activeSelection
    self.savedFilters = savedFilters
  }

  public static let empty = TaskFilterStoreSnapshot(
    activeSelection: .empty,
    savedFilters: []
  )
}

public protocol TaskFilterStoring: Sendable {
  func load() throws -> TaskFilterStoreSnapshot?
  func save(_ snapshot: TaskFilterStoreSnapshot) throws
}

public struct JSONTaskFilterStore: TaskFilterStoring {
  public let fileURL: URL

  public init(fileURL: URL = JSONTaskFilterStore.defaultFileURL()) {
    self.fileURL = fileURL
  }

  public func load() throws -> TaskFilterStoreSnapshot? {
    guard FileManager.default.fileExists(atPath: fileURL.path) else {
      return nil
    }

    return try JSONDecoder().decode(
      TaskFilterStoreSnapshot.self,
      from: Data(contentsOf: fileURL, options: .mappedIfSafe)
    )
  }

  public func save(_ snapshot: TaskFilterStoreSnapshot) throws {
    try FileManager.default.createDirectory(
      at: fileURL.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )

    let encoder = JSONEncoder()
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
      .appendingPathComponent("filters.json", isDirectory: false)
  }
}
