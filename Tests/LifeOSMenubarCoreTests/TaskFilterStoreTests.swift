import Foundation
import Testing

@testable import LifeOSMenubarCore

struct TaskFilterStoreTests {
  @Test
  func roundTripsActiveAndSavedFiltersAsJSON() throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("life-os-menubar-issue-4", isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let fileURL = directory.appendingPathComponent("filters.json")
    defer {
      try? FileManager.default.removeItem(at: directory)
    }

    let selection = TaskFilterSelection(
      labelsByFamily: [
        .area: ["area:work"],
        .priority: ["priority:p1", "priority:p2"],
      ]
    )
    let savedFilter = SavedTaskFilter(
      id: UUID(uuidString: "00000000-0000-0000-0000-000000000004")!,
      name: "Work Focus",
      selection: selection
    )
    let snapshot = TaskFilterStoreSnapshot(
      activeSelection: selection,
      savedFilters: [savedFilter]
    )
    let store = JSONTaskFilterStore(fileURL: fileURL)

    try store.save(snapshot)

    #expect(FileManager.default.fileExists(atPath: fileURL.path))
    #expect(try store.load() == snapshot)
  }

  @Test
  func missingStoreReturnsNil() throws {
    let fileURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("life-os-menubar-issue-4", isDirectory: true)
      .appendingPathComponent(UUID().uuidString)
      .appendingPathComponent("missing.json")

    #expect(try JSONTaskFilterStore(fileURL: fileURL).load() == nil)
  }

  @Test
  func defaultLocationIsInApplicationSupport() {
    let fileURL = JSONTaskFilterStore.defaultFileURL()

    #expect(fileURL.path.contains("Library/Application Support"))
    #expect(fileURL.lastPathComponent == "filters.json")
  }
}
