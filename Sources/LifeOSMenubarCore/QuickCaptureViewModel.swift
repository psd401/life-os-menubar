import Combine
import Foundation

public enum QuickCapturePriority: String, CaseIterable, Identifiable, Sendable {
  case p0
  case p1
  case p2
  case p3

  public var id: String {
    rawValue
  }

  public var title: String {
    rawValue.uppercased()
  }

  public var labelName: String {
    "priority:\(rawValue)"
  }
}

@MainActor
public final class QuickCaptureViewModel: ObservableObject {
  public static let defaultLabels = [
    LabelRules.defaultStatus,
    "type:task",
    "source:manual",
  ]

  @Published public var title = ""
  @Published public var body = ""
  @Published public var priority: QuickCapturePriority = .p2
  @Published public private(set) var isSubmitting = false
  @Published public private(set) var errorMessage: String?
  @Published public private(set) var titleFocusRequest = 0

  public var canSubmit: Bool {
    !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      && !isSubmitting
  }

  private let client: any GitHubIssueCreating

  public init(client: any GitHubIssueCreating) {
    self.client = client
  }

  public func prepareForNewCapture() {
    resetDraft()
    errorMessage = nil
  }

  public func requestTitleFocus() {
    titleFocusRequest &+= 1
  }

  public func cancel() {
    guard !isSubmitting else {
      return
    }
    resetDraft()
    errorMessage = nil
  }

  @discardableResult
  public func submit(token: String) async -> LifeOSIssue? {
    guard !isSubmitting else {
      return nil
    }
    let candidateTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !candidateTitle.isEmpty else {
      errorMessage = GitHubIssueMutationClientError.emptyTitle.localizedDescription
      return nil
    }

    isSubmitting = true
    defer {
      isSubmitting = false
    }

    do {
      let createdIssue = try await client.createIssue(
        token: token,
        title: candidateTitle,
        body: body,
        labels: Self.defaultLabels + [priority.labelName]
      )
      resetDraft()
      errorMessage = nil
      return createdIssue
    } catch {
      errorMessage = error.localizedDescription
      return nil
    }
  }

  private func resetDraft() {
    title = ""
    body = ""
    priority = .p2
  }
}
