import Foundation
import Testing

@testable import LifeOSMenubarCore

struct DeviceFlowAuthorizerTests {
  @Test
  func isUnavailableAndRefusesToStartWhenNoClientIDIsConfigured() async {
    let requester = DeviceFlowRequesterStub(outcomes: [.authorized(token: "never-used")])
    let authorizer = GitHubDeviceFlowAuthorizer(
      clientID: "",
      client: requester,
      clock: RecordingClock()
    )

    #expect(!authorizer.isAvailable)
    await #expect(throws: DeviceFlowError.clientIDMissing) {
      try await authorizer.requestAuthorization()
    }
    #expect(await requester.authorizationRequestCount == 0)
  }

  @Test
  func forwardsTheConfiguredClientIDAndScopes() async throws {
    let requester = DeviceFlowRequesterStub(outcomes: [])
    let authorizer = GitHubDeviceFlowAuthorizer(
      clientID: "cid",
      scopes: ["repo", "read:project"],
      client: requester,
      clock: RecordingClock()
    )

    #expect(authorizer.isAvailable)
    _ = try await authorizer.requestAuthorization()

    #expect(await requester.requestedClientIDs == ["cid"])
    #expect(await requester.requestedScopes == [["repo", "read:project"]])
  }

  @Test
  func waitsTheAdvertisedIntervalBetweenPollsUntilGitHubIssuesAToken() async throws {
    let requester = DeviceFlowRequesterStub(outcomes: [
      .authorizationPending,
      .authorizationPending,
      .authorized(token: "gho_test"),
    ])
    let clock = RecordingClock()
    let authorizer = GitHubDeviceFlowAuthorizer(
      clientID: "cid",
      client: requester,
      clock: clock
    )

    let token = try await authorizer.waitForAccessToken(
      authorization: makeAuthorization(pollIntervalSeconds: 5)
    )

    #expect(token == "gho_test")
    #expect(await clock.sleptSeconds == [5, 5, 5])
    #expect(await requester.redeemedDeviceCodes == ["dc-1", "dc-1", "dc-1"])
  }

  @Test
  func addsFiveSecondsToTheIntervalWhenGitHubAsksTheAppToSlowDown() async throws {
    let requester = DeviceFlowRequesterStub(outcomes: [
      .slowDown(pollIntervalSeconds: 5),
      .authorized(token: "gho_test"),
    ])
    let clock = RecordingClock()
    let authorizer = GitHubDeviceFlowAuthorizer(
      clientID: "cid",
      client: requester,
      clock: clock
    )

    _ = try await authorizer.waitForAccessToken(
      authorization: makeAuthorization(pollIntervalSeconds: 5)
    )

    // GitHub echoed the old interval, so the documented +5 seconds applies.
    #expect(await clock.sleptSeconds == [5, 10])
  }

  @Test
  func honoursALongerIntervalThanTheDocumentedIncrement() async throws {
    let requester = DeviceFlowRequesterStub(outcomes: [
      .slowDown(pollIntervalSeconds: 30),
      .authorized(token: "gho_test"),
    ])
    let clock = RecordingClock()
    let authorizer = GitHubDeviceFlowAuthorizer(
      clientID: "cid",
      client: requester,
      clock: clock
    )

    _ = try await authorizer.waitForAccessToken(
      authorization: makeAuthorization(pollIntervalSeconds: 5)
    )

    #expect(await clock.sleptSeconds == [5, 30])
  }

  @Test
  func stopsPollingWithAnExpiredCodeErrorOnceTheCodeLifetimeIsSpent() async {
    let requester = DeviceFlowRequesterStub(
      outcomes: Array(repeating: .authorizationPending, count: 10)
    )
    let clock = RecordingClock()
    let authorizer = GitHubDeviceFlowAuthorizer(
      clientID: "cid",
      client: requester,
      clock: clock
    )

    await #expect(throws: DeviceFlowError.expiredCode) {
      try await authorizer.waitForAccessToken(
        authorization: makeAuthorization(expiresInSeconds: 12, pollIntervalSeconds: 5)
      )
    }

    // 5 + 5 spends 10 of the 12 seconds; a third wait would overrun the code.
    #expect(await clock.sleptSeconds == [5, 5])
  }

  @Test
  func propagatesATerminalErrorFromTheRedeemCallWithoutRetrying() async {
    let requester = DeviceFlowRequesterStub(
      outcomes: [.authorizationPending],
      redeemError: DeviceFlowError.accessDenied,
      errorOnCallIndex: 1
    )
    let authorizer = GitHubDeviceFlowAuthorizer(
      clientID: "cid",
      client: requester,
      clock: RecordingClock()
    )

    await #expect(throws: DeviceFlowError.accessDenied) {
      try await authorizer.waitForAccessToken(authorization: makeAuthorization())
    }

    #expect(await requester.redeemedDeviceCodes.count == 2)
  }

  @Test
  func treatsAnIntervalOfZeroAsOneSecondSoPollingCannotSpin() async throws {
    let requester = DeviceFlowRequesterStub(outcomes: [.authorized(token: "gho_test")])
    let clock = RecordingClock()
    let authorizer = GitHubDeviceFlowAuthorizer(
      clientID: "cid",
      client: requester,
      clock: clock
    )

    _ = try await authorizer.waitForAccessToken(
      authorization: makeAuthorization(pollIntervalSeconds: 0)
    )

    #expect(await clock.sleptSeconds == [1])
  }

  @Test
  func clampsAnAbsurdAuthorizationSoTheLoopArithmeticCannotTrap() async throws {
    // A DeviceAuthorization can be built by any caller, so the ceiling is
    // enforced here too: `elapsed + interval` on Int.max would trap, not throw.
    let requester = DeviceFlowRequesterStub(outcomes: [.authorized(token: "gho_test")])
    let clock = RecordingClock()
    let authorizer = GitHubDeviceFlowAuthorizer(
      clientID: "cid",
      client: requester,
      clock: clock
    )

    let token = try await authorizer.waitForAccessToken(
      authorization: DeviceAuthorization(
        deviceCode: "dc-1",
        userCode: "WDJB-MJHT",
        verificationURL: URL(string: "https://github.com/login/device")!,
        expiresInSeconds: .max,
        pollIntervalSeconds: .max
      )
    )

    #expect(token == "gho_test")
    #expect(await clock.sleptSeconds == [DeviceFlowSeconds.maximum])
  }

  @Test
  func givesUpRatherThanTrappingWhenSlowDownAsksForAnAbsurdInterval() async {
    let requester = DeviceFlowRequesterStub(outcomes: [
      .slowDown(pollIntervalSeconds: .max),
      .authorized(token: "never-reached"),
    ])
    let clock = RecordingClock()
    let authorizer = GitHubDeviceFlowAuthorizer(
      clientID: "cid",
      client: requester,
      clock: clock
    )

    // The clamped interval no longer fits in the code's remaining lifetime, so
    // the loop ends with an expired code — the point being that it ends at all
    // rather than trapping on `elapsed + Int.max`.
    await #expect(throws: DeviceFlowError.expiredCode) {
      try await authorizer.waitForAccessToken(
        authorization: makeAuthorization(expiresInSeconds: 900, pollIntervalSeconds: 5)
      )
    }

    #expect(await clock.sleptSeconds == [5])
  }

  private func makeAuthorization(
    expiresInSeconds: Int = 900,
    pollIntervalSeconds: Int = 5
  ) -> DeviceAuthorization {
    DeviceAuthorization(
      deviceCode: "dc-1",
      userCode: "WDJB-MJHT",
      verificationURL: URL(string: "https://github.com/login/device")!,
      expiresInSeconds: expiresInSeconds,
      pollIntervalSeconds: pollIntervalSeconds
    )
  }
}

/// Records every poll interval the authorizer waits, so the tests can assert the
/// documented backoff without spending real time.
actor RecordingClock: DeviceFlowClocking {
  private(set) var sleptSeconds: [Int] = []

  func sleep(forSeconds seconds: Int) async throws {
    sleptSeconds.append(seconds)
  }
}

actor DeviceFlowRequesterStub: DeviceFlowRequesting {
  private var outcomes: [DeviceAccessTokenOutcome]
  private let redeemError: (any Error)?
  private let errorOnCallIndex: Int?
  private(set) var authorizationRequestCount = 0
  private(set) var requestedClientIDs: [String] = []
  private(set) var requestedScopes: [[String]] = []
  private(set) var redeemedDeviceCodes: [String] = []

  init(
    outcomes: [DeviceAccessTokenOutcome],
    redeemError: (any Error)? = nil,
    errorOnCallIndex: Int? = nil
  ) {
    self.outcomes = outcomes
    self.redeemError = redeemError
    self.errorOnCallIndex = errorOnCallIndex
  }

  func requestDeviceAuthorization(
    clientID: String,
    scopes: [String]
  ) async throws -> DeviceAuthorization {
    authorizationRequestCount += 1
    requestedClientIDs.append(clientID)
    requestedScopes.append(scopes)
    return DeviceAuthorization(
      deviceCode: "dc-1",
      userCode: "WDJB-MJHT",
      verificationURL: URL(string: "https://github.com/login/device")!,
      expiresInSeconds: 900,
      pollIntervalSeconds: 5
    )
  }

  func redeemAccessToken(
    clientID: String,
    deviceCode: String
  ) async throws -> DeviceAccessTokenOutcome {
    redeemedDeviceCodes.append(deviceCode)
    if let redeemError, redeemedDeviceCodes.count > (errorOnCallIndex ?? 0) {
      throw redeemError
    }
    guard !outcomes.isEmpty else {
      throw DeviceFlowError.invalidResponse
    }
    return outcomes.removeFirst()
  }
}
