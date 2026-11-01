import Foundation
import Testing

@testable import LifeOSMenubarCore

@Suite(.serialized)
struct TaskRepositoryValidatorTests {
  @Test
  func readsTheConfiguredRepositorysLabelsAndReportsItConforming() async throws {
    RepositoryValidatorURLProtocolStub.handler = { request in
      #expect(request.httpMethod == "GET")
      #expect(request.url?.path == "/repos/octocat/tasks/labels")
      #expect(request.url?.query == "per_page=100&page=1")
      #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer repo-token")
      #expect(request.value(forHTTPHeaderField: "X-GitHub-Api-Version") == "2022-11-28")
      return try validatorResponse(for: request, json: labelsJSON(LabelRules.requiredLabelNames))
    }

    let report = try await makeValidator().validate(
      token: "  repo-token\n",
      repository: TaskRepository(owner: "octocat", name: "tasks")
    )

    #expect(report.missingLabels.isEmpty)
    #expect(report.isConforming)
    #expect(report.repository.slug == "octocat/tasks")
  }

  @Test
  func listsEveryMissingRequiredLabelInContractOrder() async throws {
    let present = LabelRules.requiredLabelNames.filter {
      $0 != "status:done" && $0 != "priority:p0"
    }
    RepositoryValidatorURLProtocolStub.handler = { request in
      try validatorResponse(for: request, json: labelsJSON(present))
    }

    let report = try await makeValidator().validate(
      token: "token",
      repository: TaskRepository(owner: "octocat", name: "tasks")
    )

    #expect(report.missingLabels == ["status:done", "priority:p0"])
    #expect(!report.isConforming)
  }

  @Test
  func ignoresLabelNameCasingAndExtraLabels() async throws {
    let present = LabelRules.requiredLabelNames.map { $0.uppercased() } + ["area:home"]
    RepositoryValidatorURLProtocolStub.handler = { request in
      try validatorResponse(for: request, json: labelsJSON(present))
    }

    let report = try await makeValidator().validate(
      token: "token",
      repository: TaskRepository(owner: "octocat", name: "tasks")
    )

    #expect(report.missingLabels.isEmpty)
  }

  @Test
  func followsEveryPageOfLabelsBeforeDecidingSomethingIsMissing() async throws {
    let firstPage = (0..<100).map { "area:a\($0)" }
    RepositoryValidatorURLProtocolStub.handler = { request in
      let page = request.url?.query?.contains("page=2") == true ? 2 : 1
      return try validatorResponse(
        for: request,
        json: labelsJSON(page == 1 ? firstPage : LabelRules.requiredLabelNames)
      )
    }

    let report = try await makeValidator().validate(
      token: "token",
      repository: TaskRepository(owner: "octocat", name: "tasks")
    )

    #expect(report.missingLabels.isEmpty)
  }

  @Test
  func reportsAMissingRepositoryByName() async {
    RepositoryValidatorURLProtocolStub.handler = { request in
      try validatorResponse(for: request, statusCode: 404, json: "{}")
    }

    await #expect(
      throws: TaskRepositoryValidationError.repositoryNotFound(repository: "octocat/typo")
    ) {
      try await makeValidator().validate(
        token: "token",
        repository: TaskRepository(owner: "octocat", name: "typo")
      )
    }
  }

  @Test
  func separatesARejectedTokenFromARepositoryThisTokenCannotReach() async {
    RepositoryValidatorURLProtocolStub.handler = { request in
      try validatorResponse(for: request, statusCode: 401, json: "{}")
    }
    await #expect(throws: TaskRepositoryValidationError.rejected) {
      try await makeValidator().validate(
        token: "token",
        repository: TaskRepository(owner: "octocat", name: "tasks")
      )
    }

    RepositoryValidatorURLProtocolStub.handler = { request in
      try validatorResponse(for: request, statusCode: 403, json: "{}")
    }
    await #expect(
      throws: TaskRepositoryValidationError.forbidden(repository: "octocat/tasks")
    ) {
      try await makeValidator().validate(
        token: "token",
        repository: TaskRepository(owner: "octocat", name: "tasks")
      )
    }
  }

  @Test
  func surfacesAnyOtherFailureStatus() async {
    RepositoryValidatorURLProtocolStub.handler = { request in
      try validatorResponse(for: request, statusCode: 500, json: "{}")
    }

    await #expect(throws: TaskRepositoryValidationError.requestFailed(statusCode: 500)) {
      try await makeValidator().validate(
        token: "token",
        repository: TaskRepository(owner: "octocat", name: "tasks")
      )
    }
  }

  @Test
  func rejectsAnEmptyTokenWithoutSendingARequest() async {
    RepositoryValidatorURLProtocolStub.handler = { _ in
      Issue.record("No request should be sent for an empty token.")
      throw URLError(.badURL)
    }

    await #expect(throws: TaskRepositoryValidationError.emptyToken) {
      try await makeValidator().validate(
        token: " \n ",
        repository: TaskRepository(owner: "octocat", name: "tasks")
      )
    }
  }

  @Test
  func noErrorMessageNamesTheOriginalHardcodedRepository() {
    let messages = [
      TaskRepositoryValidationError.emptyToken,
      .invalidResponse,
      .invalidRequestURL(repository: "octocat/tasks"),
      .rejected,
      .forbidden(repository: "octocat/tasks"),
      .repositoryNotFound(repository: "octocat/tasks"),
      .requestFailed(statusCode: 500),
    ].compactMap(\.errorDescription)

    #expect(messages.count == 7)
    #expect(messages.allSatisfy { !$0.contains("krishagel") && !$0.contains("life-os") })
  }

  private func makeValidator() -> TaskRepositoryValidator {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [RepositoryValidatorURLProtocolStub.self]
    return TaskRepositoryValidator(
      session: URLSession(configuration: configuration),
      endpoint: URL(string: "https://example.test")!
    )
  }
}

private func labelsJSON(_ names: [String]) -> String {
  let entries = names.map { "{\"name\": \"\($0)\"}" }.joined(separator: ",")
  return "[\(entries)]"
}

private func validatorResponse(
  for request: URLRequest,
  statusCode: Int = 200,
  json: String
) throws -> (HTTPURLResponse, Data) {
  let response = try #require(
    HTTPURLResponse(
      url: request.url!,
      statusCode: statusCode,
      httpVersion: nil,
      headerFields: nil
    )
  )
  return (response, Data(json.utf8))
}

private final class RepositoryValidatorURLProtocolStub: URLProtocol, @unchecked Sendable {
  nonisolated(unsafe) static var handler:
    @Sendable (URLRequest) throws -> (
      HTTPURLResponse, Data
    ) = { request in
      throw URLError(.badServerResponse, userInfo: ["url": request.url as Any])
    }

  override class func canInit(with request: URLRequest) -> Bool {
    true
  }

  override class func canonicalRequest(for request: URLRequest) -> URLRequest {
    request
  }

  override func startLoading() {
    do {
      let (response, data) = try Self.handler(request)
      client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
      client?.urlProtocol(self, didLoad: data)
      client?.urlProtocolDidFinishLoading(self)
    } catch {
      client?.urlProtocol(self, didFailWithError: error)
    }
  }

  override func stopLoading() {}
}
