import ServiceManagement

@MainActor
public protocol LaunchAtLoginControlling: AnyObject {
  var isEnabled: Bool { get }
  func setEnabled(_ isEnabled: Bool) throws
}

@MainActor
public final class LaunchAtLoginController: LaunchAtLoginControlling {
  private let service: SMAppService

  public init(service: SMAppService = .mainApp) {
    self.service = service
  }

  public var isEnabled: Bool {
    service.status == .enabled
  }

  public func setEnabled(_ isEnabled: Bool) throws {
    if isEnabled {
      guard service.status != .enabled else {
        return
      }
      try service.register()
      return
    }

    switch service.status {
    case .enabled, .requiresApproval:
      try service.unregister()
    case .notFound, .notRegistered:
      break
    @unknown default:
      break
    }
  }
}
