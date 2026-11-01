import Foundation
import Testing

@testable import LifeOSMenubarCore

@MainActor
struct QuickCaptureViewModelTests {
  @Test
  func successfulCaptureUsesDefaultsAndClearsDraft() async throws {
    let expectedIssue = quickCaptureIssue()
    let client = QuickCaptureClientStub(result: .success(expectedIssue))
    let viewModel = QuickCaptureViewModel(client: client)
    viewModel.title = "  Captured task "
    viewModel.body = "Details"

    let issue = await viewModel.submit(token: "token")
    let call = try #require(await client.calls.first)

    #expect(issue == expectedIssue)
    #expect(call.title == "Captured task")
    #expect(call.body == "Details")
    #expect(
      call.labels
        == ["status:inbox", "type:task", "source:manual", "priority:p2"]
    )
    #expect(viewModel.title.isEmpty)
    #expect(viewModel.body.isEmpty)
    #expect(viewModel.priority == .p2)
    #expect(viewModel.errorMessage == nil)
  }

  @Test
  func selectedPriorityOverridesDefault() async throws {
    let client = QuickCaptureClientStub(result: .success(quickCaptureIssue()))
    let viewModel = QuickCaptureViewModel(client: client)
    viewModel.title = "Urgent"
    viewModel.priority = .p0

    _ = await viewModel.submit(token: "token")
    let call = try #require(await client.calls.first)

    #expect(call.labels.last == "priority:p0")
    #expect(!call.labels.contains("priority:p2"))
  }

  @Test
  func failurePreservesDraftAndSurfacesError() async {
    let client = QuickCaptureClientStub(result: .failure(.network))
    let viewModel = QuickCaptureViewModel(client: client)
    viewModel.title = "Keep title"
    viewModel.body = "Keep notes"
    viewModel.priority = .p1

    #expect(await viewModel.submit(token: "token") == nil)
    #expect(viewModel.title == "Keep title")
    #expect(viewModel.body == "Keep notes")
    #expect(viewModel.priority == .p1)
    #expect(viewModel.errorMessage == QuickCaptureStubError.network.localizedDescription)
    #expect(!viewModel.isSubmitting)
  }

  @Test
  func emptyTitleCannotBeSubmitted() async {
    let client = QuickCaptureClientStub(result: .success(quickCaptureIssue()))
    let viewModel = QuickCaptureViewModel(client: client)
    viewModel.title = " \n "

    #expect(!viewModel.canSubmit)
    #expect(await viewModel.submit(token: "token") == nil)
    #expect(await client.calls.isEmpty)
    #expect(
      viewModel.errorMessage
        == GitHubIssueMutationClientError.emptyTitle.localizedDescription
    )
  }

  /// The panel quick-add composer binds only the title: it never touches `body` or
  /// `priority`, so a title-only submit has to send an empty body and exactly the
  /// four Agent Operating Contract defaults.
  @Test
  func titleOnlySubmitSendsEmptyBodyAndContractDefaults() async throws {
    let client = QuickCaptureClientStub(result: .success(quickCaptureIssue()))
    let viewModel = QuickCaptureViewModel(client: client)
    viewModel.title = "  Composed task  "

    let issue = await viewModel.submit(token: "token")
    let call = try #require(await client.calls.first)

    #expect(issue != nil)
    #expect(call.title == "Composed task")
    #expect(call.body.isEmpty)
    #expect(
      call.labels
        == ["status:inbox", "type:task", "source:manual", "priority:p2"]
    )
    #expect(viewModel.title.isEmpty)
    #expect(viewModel.errorMessage == nil)
  }

  /// The composer refocuses its field when the panel reopens, which rides on the
  /// focus-request counter rather than on `onAppear`.
  @Test
  func requestTitleFocusAdvancesTheFocusRequestCounter() {
    let viewModel = QuickCaptureViewModel(
      client: QuickCaptureClientStub(result: .failure(.network))
    )
    let initialRequest = viewModel.titleFocusRequest

    viewModel.requestTitleFocus()

    #expect(viewModel.titleFocusRequest == initialRequest &+ 1)
  }

  @Test
  func cancelRestoresFreshCaptureDefaults() {
    let viewModel = QuickCaptureViewModel(
      client: QuickCaptureClientStub(result: .failure(.network))
    )
    viewModel.title = "Discard"
    viewModel.body = "Discard notes"
    viewModel.priority = .p0

    viewModel.cancel()

    #expect(viewModel.title.isEmpty)
    #expect(viewModel.body.isEmpty)
    #expect(viewModel.priority == .p2)
    #expect(viewModel.errorMessage == nil)
  }
}

private enum QuickCaptureStubError: LocalizedError, Sendable {
  case network

  var errorDescription: String? {
    "The test creation request failed."
  }
}

private actor QuickCaptureClientStub: GitHubIssueCreating {
  struct Call: Equatable, Sendable {
    let token: String
    let title: String
    let body: String
    let labels: [String]
  }

  let result: Result<LifeOSIssue, QuickCaptureStubError>
  private(set) var calls: [Call] = []

  init(result: Result<LifeOSIssue, QuickCaptureStubError>) {
    self.result = result
  }

  func createIssue(
    token: String,
    title: String,
    body: String,
    labels: [String]
  ) async throws -> LifeOSIssue {
    calls.append(Call(token: token, title: title, body: body, labels: labels))
    return try result.get()
  }
}

private func quickCaptureIssue() -> LifeOSIssue {
  LifeOSIssue(
    number: 42,
    title: "Captured task",
    body: "Details",
    labels: [
      GitHubLabel(name: "status:inbox", color: "ffffff"),
      GitHubLabel(name: "type:task", color: "ffffff"),
      GitHubLabel(name: "source:manual", color: "ffffff"),
      GitHubLabel(name: "priority:p2", color: "ffffff"),
    ],
    updatedAt: Date(timeIntervalSince1970: 100)
  )
}
