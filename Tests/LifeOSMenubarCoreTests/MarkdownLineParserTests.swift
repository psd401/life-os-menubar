import Testing

@testable import LifeOSMenubarCore

struct MarkdownLineParserTests {
  @Test
  func recognizesOrderedListMarkerOnlyWhenPeriodIsFollowedByWhitespace() {
    #expect(
      MarkdownLineParser.orderedListItem(from: "12. Review the task")
        == MarkdownOrderedListItem(marker: "12.", text: "Review the task")
    )
    #expect(MarkdownLineParser.orderedListItem(from: "12.No space") == nil)
  }

  @Test
  func leavesIPsVersionsAndDecimalsAsPlainText() {
    #expect(MarkdownLineParser.orderedListItem(from: "10.0.2.5 stopped responding") == nil)
    #expect(MarkdownLineParser.orderedListItem(from: "3.11 released") == nil)
    #expect(MarkdownLineParser.orderedListItem(from: "2.5 hours remaining") == nil)
  }
}
