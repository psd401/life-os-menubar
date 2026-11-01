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

public struct MarkdownOrderedListItem: Equatable, Sendable {
  public let marker: String
  public let text: String

  public init(marker: String, text: String) {
    self.marker = marker
    self.text = text
  }
}

public enum MarkdownLineParser {
  public static func orderedListItem(from line: String) -> MarkdownOrderedListItem? {
    guard line.first?.isNumber == true, let separator = line.firstIndex(of: ".") else {
      return nil
    }
    guard Int(line[..<separator]) != nil else {
      return nil
    }

    let textStart = line.index(after: separator)
    guard textStart < line.endIndex, line[textStart].isWhitespace else {
      return nil
    }
    let text = line[textStart...].trimmingCharacters(in: .whitespaces)
    guard !text.isEmpty else {
      return nil
    }
    return MarkdownOrderedListItem(
      marker: String(line[...separator]),
      text: text
    )
  }
}
