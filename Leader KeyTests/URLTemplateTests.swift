import XCTest

@testable import Leader_Key

final class URLTemplateTests: XCTestCase {

  private func expand(_ template: String, with values: [URLPlaceholder: String])
    -> (result: String?, asked: [URLPlaceholder])
  {
    var asked: [URLPlaceholder] = []
    let result = URLTemplate.expand(template) { placeholder in
      asked.append(placeholder)
      return values[placeholder]
    }
    return (result, asked)
  }

  func testFillsEveryRealWorldForm() {
    let argument = URLPlaceholder.text(label: "Argument")
    let query = URLPlaceholder.text(label: "Query")
    let cases: [(template: String, placeholder: URLPlaceholder, expected: String)] = [
      (
        #"https://www.perplexity.ai/search/?q={argument name="Argument"}"#, argument,
        "https://www.perplexity.ai/search/?q=red%20fox"
      ),
      (
        "https://www.perplexity.ai/search/?q={clipboard}", .clipboard,
        "https://www.perplexity.ai/search/?q=red%20fox"
      ),
      (
        "https://music.apple.com/us/search?l=en&term={Query}", query,
        "https://music.apple.com/us/search?l=en&term=red%20fox"
      ),
      ("https://duckduckgo.com/?q={argument}", argument, "https://duckduckgo.com/?q=red%20fox"),
      (
        "https://www.justwatch.com/us/search?q={Query}", query,
        "https://www.justwatch.com/us/search?q=red%20fox"
      ),
      (
        "https://google.com/search?q={argument}", argument,
        "https://google.com/search?q=red%20fox"
      ),
      (
        "https://mail.google.com/mail/#search/{query}", query,
        "https://mail.google.com/mail/#search/red%20fox"
      ),
      (
        "https://www.google.com/search?q={Query}&udm=14", query,
        "https://www.google.com/search?q=red%20fox&udm=14"
      ),
      (
        "https://www.productreview.com.au/search?q={clipboard}", .clipboard,
        "https://www.productreview.com.au/search?q=red%20fox"
      ),
      (
        "https://www.reddit.com/search/?q={query}", query,
        "https://www.reddit.com/search/?q=red%20fox"
      ),
      (
        "https://open.spotify.com/search/{query}", query,
        "https://open.spotify.com/search/red%20fox"
      ),
      (
        "https://myactivity.google.com/product/youtube?hl=en&ent=r&utm_source=udc&pli=1"
          + "&q={Search Query}", .text(label: "Search Query"),
        "https://myactivity.google.com/product/youtube?hl=en&ent=r&utm_source=udc&pli=1"
          + "&q=red%20fox"
      ),
      (
        "https://www.youtube.com/results?search_query={Query}", query,
        "https://www.youtube.com/results?search_query=red%20fox"
      ),
    ]

    for (template, placeholder, expected) in cases {
      let (result, asked) = expand(template, with: [placeholder: "red fox"])
      XCTAssertEqual(result, expected, template)
      XCTAssertEqual(asked, [placeholder], template)
    }
  }

  func testMatchesPlaceholdersInAnyCase() {
    let (result, asked) = expand(
      "https://example.com/{CLIPBOARD}/{sEaRcH qUeRy}",
      with: [.clipboard: "a", .text(label: "Search Query"): "b"])
    XCTAssertEqual(result, "https://example.com/a/b")
    XCTAssertEqual(asked, [.clipboard, .text(label: "Search Query")])
  }

  func testCancelOpensNothingAndAsksNoFurther() {
    let (result, asked) = expand(
      "https://example.com/?q={query}&tag={argument}", with: [:])
    XCTAssertNil(result)
    XCTAssertEqual(asked, [.text(label: "Query")])
  }

  func testAsksOnceForARepeatedPlaceholder() {
    let (result, asked) = expand(
      "https://example.com/{query}?q={Query}&again={QUERY}",
      with: [.text(label: "Query"): "fox"])
    XCTAssertEqual(result, "https://example.com/fox?q=fox&again=fox")
    XCTAssertEqual(asked, [.text(label: "Query")])
  }

  func testAsksSeparatelyForDifferentPlaceholdersWithOneLabel() {
    var answers = ["first", "second"]
    let result = URLTemplate.expand(#"https://example.com/?a={query}&b={argument name="Query"}"#) {
      _ in answers.removeFirst()
    }
    XCTAssertEqual(result, "https://example.com/?a=first&b=second")
  }

  func testAsksForEachNamedArgumentInOrder() {
    let (result, asked) = expand(
      #"https://example.com/?from={argument name="From"}&to={argument name="To"}"#,
      with: [.text(label: "From"): "Adelaide", .text(label: "To"): "Perth"])
    XCTAssertEqual(result, "https://example.com/?from=Adelaide&to=Perth")
    XCTAssertEqual(asked, [.text(label: "From"), .text(label: "To")])
  }

  func testLeavesOtherBracesAsWritten() {
    let template =
      #"https://example.com/{id}?a={selection}&b={argument name='X'}"#
      + #"&c={argument name="X" default="Y"}&d={clipboard | trim}&e={searchquery}&f={}"#
    let (result, asked) = expand(template, with: [:])
    XCTAssertEqual(result, template)
    XCTAssertEqual(asked, [])
  }

  func testEncodesEverythingOutsideTheUnreservedSet() {
    let value = "AZaz09-._~ &#/?=+%!'()*;:@,$é😀"
    let (result, _) = expand("{query}", with: [.text(label: "Query"): value])
    XCTAssertEqual(
      result,
      "AZaz09-._~%20%26%23%2F%3F%3D%2B%25%21%27%28%29%2A%3B%3A%40%2C%24%C3%A9%F0%9F%98%80")
  }

  func testValueCannotBreakTheURL() throws {
    let value = "fish & chips #1/2 😀"
    let values: [URLPlaceholder: String] = [.text(label: "Query"): value]

    let query = try XCTUnwrap(
      expand("https://example.com/search?q={query}&lang=en", with: values).result)
    let queryItems = try XCTUnwrap(URLComponents(string: query)?.queryItems)
    XCTAssertEqual(queryItems, [.init(name: "q", value: value), .init(name: "lang", value: "en")])

    let path = try XCTUnwrap(expand("https://example.com/search/{query}", with: values).result)
    let segments = URLComponents(string: path)?.percentEncodedPath.split(separator: "/")
    XCTAssertEqual(segments?.map { $0.removingPercentEncoding }, ["search", value])

    let fragment = try XCTUnwrap(
      expand("https://example.com/mail/#search/{query}", with: values).result)
    XCTAssertEqual(URLComponents(string: fragment)?.fragment, "search/\(value)")
  }
}
