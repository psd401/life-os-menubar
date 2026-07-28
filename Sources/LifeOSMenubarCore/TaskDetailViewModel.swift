import Combine
import Foundation

@MainActor
public final class TaskDetailViewModel: ObservableObject {
  @Published public private(set) var issue: LifeOSIssue
  @Published public private(set) var comments: [GitHubComment] = []
  @Published public var commentDraft = ""
  @Published public private(set) var isLoading = false
  @Published public private(set) var isMutating = false
  @Published public private(set) var hasLoadedDetail = false
  @Published public private(set) var errorMessage: String?

  private let detailClient: any GitHubIssueDetailFetching
  private let mutationClient: any GitHubIssueMutating

  public init(
    issue: LifeOSIssue,
    detailClient: any GitHubIssueDetailFetching,
    mutationClient: any GitHubIssueMutating
  ) {
    self.issue = issue
    self.detailClient = detailClient
    self.mutationClient = mutationClient
  }

  public func load(token: String) async {
    guard !isLoading else {
      return
    }
    isLoading = true
    defer {
      isLoading = false
    }

    do {
      let detail = try await detailClient.fetchIssueDetail(token: token, number: issue.number)
      issue = detail.issue.preservingProjectFields(from: issue)
      comments = detail.comments
      hasLoadedDetail = true
      errorMessage = nil
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  @discardableResult
  public func addComment(token: String) async -> Bool {
    let candidate = commentDraft.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !candidate.isEmpty else {
      errorMessage = GitHubIssueMutationClientError.emptyComment.localizedDescription
      return false
    }
    guard hasLoadedDetail else {
      errorMessage = "Wait for the latest task details before posting a comment."
      return false
    }
    guard !isMutating else {
      return false
    }

    isMutating = true
    defer {
      isMutating = false
    }

    do {
      let comment = try await mutationClient.addComment(
        token: token,
        issueNumber: issue.number,
        body: candidate
      )
      comments.append(comment)
      comments.sort {
        if $0.createdAt != $1.createdAt {
          return $0.createdAt < $1.createdAt
        }
        return $0.id < $1.id
      }
      commentDraft = ""
      errorMessage = nil
      return true
    } catch {
      errorMessage = error.localizedDescription
      return false
    }
  }

  public func changeStatus(token: String, to status: String) async -> LifeOSIssue? {
    do {
      let labels = try LabelRules.changingStatus(
        in: issue.labels.map(\.name),
        to: status
      )
      return await updateIssue(token: token, labels: labels, state: nil)
    } catch {
      errorMessage = error.localizedDescription
      return nil
    }
  }

  public func changePriority(token: String, to priority: String) async -> LifeOSIssue? {
    do {
      let labels = try LabelRules.changingPriority(
        in: issue.labels.map(\.name),
        to: priority
      )
      return await updateIssue(token: token, labels: labels, state: nil)
    } catch {
      errorMessage = error.localizedDescription
      return nil
    }
  }

  public func setNonContractLabel(
    token: String,
    label: String,
    isSelected: Bool
  ) async -> LifeOSIssue? {
    do {
      let labels = try LabelRules.editingNonContractLabel(
        in: issue.labels.map(\.name),
        label: label,
        isSelected: isSelected
      )
      return await updateIssue(token: token, labels: labels, state: nil)
    } catch {
      errorMessage = error.localizedDescription
      return nil
    }
  }

  public func close(token: String) async -> LifeOSIssue? {
    do {
      let labels = try LabelRules.changingStatus(
        in: issue.labels.map(\.name),
        to: "status:done"
      )
      return await updateIssue(token: token, labels: labels, state: .closed)
    } catch {
      errorMessage = error.localizedDescription
      return nil
    }
  }

  private func updateIssue(
    token: String,
    labels: [String],
    state: GitHubIssueState?
  ) async -> LifeOSIssue? {
    guard hasLoadedDetail else {
      errorMessage = "Wait for the latest task details before changing this task."
      return nil
    }
    guard !isMutating else {
      return nil
    }
    if state == nil, labels == issue.labels.map(\.name) {
      errorMessage = nil
      return issue
    }

    isMutating = true
    defer {
      isMutating = false
    }

    do {
      let updatedIssue = try await mutationClient.updateIssue(
        token: token,
        issueNumber: issue.number,
        labels: labels,
        state: state
      )
      issue = updatedIssue.preservingProjectFields(from: issue)
      errorMessage = nil
      return issue
    } catch {
      errorMessage = error.localizedDescription
      return nil
    }
  }
}
