import Foundation

public struct GitHubComment: Codable, Equatable, Identifiable, Sendable {
  public let id: String
  public let authorLogin: String
  public let body: String
  public let createdAt: Date
  public let updatedAt: Date

  public init(
    id: String,
    authorLogin: String,
    body: String,
    createdAt: Date,
    updatedAt: Date
  ) {
    self.id = id
    self.authorLogin = authorLogin
    self.body = body
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }
}

public struct LifeOSIssueDetail: Equatable, Sendable {
  public let issue: LifeOSIssue
  public let comments: [GitHubComment]

  public init(issue: LifeOSIssue, comments: [GitHubComment]) {
    self.issue = issue
    self.comments = comments
  }
}
