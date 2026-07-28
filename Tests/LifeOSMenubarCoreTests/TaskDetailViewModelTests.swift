import Foundation
import Testing

@testable import LifeOSMenubarCore

@MainActor
struct TaskDetailViewModelTests {
  @Test
  func mutationFailureLeavesIssueUnchangedAndSurfacesError() async {
    let original = detailViewModelIssue()
    let mutationClient = DetailMutationStub(updateResult: .failure(.network))
    let viewModel = makeViewModel(issue: original, mutationClient: mutationClient)
    await viewModel.load(token: "token")

    let result = await viewModel.changePriority(token: "token", to: "priority:p0")

    #expect(result == nil)
    #expect(viewModel.issue == original)
    #expect(viewModel.errorMessage == DetailStubError.network.localizedDescription)
    #expect(!viewModel.isMutating)
  }

  @Test
  func failedCommentKeepsDraftAndExistingThread() async {
    let originalComment = detailViewModelComment(id: "existing", body: "Existing")
    let mutationClient = DetailMutationStub(commentResult: .failure(.network))
    let viewModel = makeViewModel(mutationClient: mutationClient)
    await viewModel.load(token: "token")
    viewModel.commentDraft = "Keep this draft"

    #expect(!viewModel.comments.isEmpty)
    #expect(await viewModel.addComment(token: "token") == false)
    #expect(viewModel.commentDraft == "Keep this draft")
    #expect(viewModel.comments == [originalComment])
  }

  @Test
  func successfulCloseUsesOneContractSafeUpdateAndAppliesServerResponse() async throws {
    let closedIssue = detailViewModelIssue(
      labels: ["status:done", "priority:p1", "area:work"],
      state: .closed
    )
    let mutationClient = DetailMutationStub(updateResult: .success(closedIssue))
    let viewModel = makeViewModel(mutationClient: mutationClient)
    await viewModel.load(token: "token")

    let result = await viewModel.close(token: "token")
    let call = try #require(await mutationClient.updateCalls.first)

    #expect(result == closedIssue)
    #expect(viewModel.issue == closedIssue)
    #expect(call.issueNumber == 42)
    #expect(call.labels == ["status:done", "priority:p1", "area:work"])
    #expect(call.state == .closed)
  }

  @Test
  func validNoOpDoesNotSendMutationRequest() async {
    let mutationClient = DetailMutationStub()
    let viewModel = makeViewModel(mutationClient: mutationClient)
    await viewModel.load(token: "token")

    let result = await viewModel.changeStatus(token: "token", to: "status:next")

    #expect(result == viewModel.issue)
    #expect(await mutationClient.updateCalls.isEmpty)
  }

  @Test
  func successfulCommentClearsDraftAndSortsReturnedComment() async {
    let newComment = detailViewModelComment(id: "new", body: "New", timestamp: 200)
    let mutationClient = DetailMutationStub(commentResult: .success(newComment))
    let viewModel = makeViewModel(mutationClient: mutationClient)
    await viewModel.load(token: "token")
    viewModel.commentDraft = "New"

    #expect(await viewModel.addComment(token: "token"))
    #expect(viewModel.commentDraft.isEmpty)
    #expect(viewModel.comments.map(\.id) == ["existing", "new"])
  }

  private func makeViewModel(
    issue: LifeOSIssue = detailViewModelIssue(),
    mutationClient: DetailMutationStub
  ) -> TaskDetailViewModel {
    TaskDetailViewModel(
      issue: issue,
      detailClient: DetailFetcherStub(
        detail: LifeOSIssueDetail(
          issue: issue,
          comments: [detailViewModelComment(id: "existing", body: "Existing")]
        )
      ),
      mutationClient: mutationClient
    )
  }
}

private enum DetailStubError: LocalizedError, Sendable {
  case network

  var errorDescription: String? {
    "The test network request failed."
  }
}

private struct DetailFetcherStub: GitHubIssueDetailFetching {
  let detail: LifeOSIssueDetail

  func fetchIssueDetail(token: String, number: Int) async throws -> LifeOSIssueDetail {
    detail
  }
}

private actor DetailMutationStub: GitHubIssueMutating {
  struct UpdateCall: Equatable, Sendable {
    let issueNumber: Int
    let labels: [String]
    let state: GitHubIssueState?
  }

  private let commentResult: Result<GitHubComment, DetailStubError>
  private let updateResult: Result<LifeOSIssue, DetailStubError>
  private(set) var updateCalls: [UpdateCall] = []

  init(
    commentResult: Result<GitHubComment, DetailStubError> = .failure(.network),
    updateResult: Result<LifeOSIssue, DetailStubError> = .success(detailViewModelIssue())
  ) {
    self.commentResult = commentResult
    self.updateResult = updateResult
  }

  func addComment(token: String, issueNumber: Int, body: String) async throws -> GitHubComment {
    try commentResult.get()
  }

  func updateIssue(
    token: String,
    issueNumber: Int,
    labels: [String],
    state: GitHubIssueState?
  ) async throws -> LifeOSIssue {
    updateCalls.append(
      UpdateCall(issueNumber: issueNumber, labels: labels, state: state)
    )
    return try updateResult.get()
  }
}

private func detailViewModelIssue(
  labels: [String] = ["status:next", "priority:p1", "area:work"],
  state: GitHubIssueState = .open
) -> LifeOSIssue {
  LifeOSIssue(
    number: 42,
    title: "Task",
    body: "# Body",
    labels: labels.map { GitHubLabel(name: $0, color: "ffffff") },
    updatedAt: Date(timeIntervalSince1970: 100),
    state: state
  )
}

private func detailViewModelComment(
  id: String,
  body: String,
  timestamp: TimeInterval = 100
) -> GitHubComment {
  GitHubComment(
    id: id,
    authorLogin: "octocat",
    body: body,
    createdAt: Date(timeIntervalSince1970: timestamp),
    updatedAt: Date(timeIntervalSince1970: timestamp)
  )
}
