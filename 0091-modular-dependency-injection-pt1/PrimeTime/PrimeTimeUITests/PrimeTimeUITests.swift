import XCTest
@testable import Counter

class PrimeTimeUITests: XCTestCase {
  override func setUp() {
    continueAfterFailure = false
    Current = .mock // 테스트할 때, mock 데이터로 종속성 테스트 가능 (종속성 모델을 사용하여 모델 안에 정의되어있는 종속성을 가져와 테스트할 수 있다.)
      // 즉, 모든 테스트가 통제된 환경에서 실행되도록 보장할 수 있다.
      // 예를 들어 종속성을 다시 작성하여(추가하여) 각 테스트 케이스의 환경을 추가로 조정할 수도 있다.

  }

  func testExample() {
    let app = XCUIApplication()
    app.launchEnvironment["UI_TESTS"] = "1"
    app.launchEnvironment["UNHAPPY_PATHS"] = "1"
    app.launch()

    app.tables.buttons["Counter demo"].tap()

    let button = app.buttons["+"]
    button.tap()
    XCTAssert(app.staticTexts["1"].exists)
    button.tap()
    XCTAssert(app.staticTexts["2"].exists)
    app.buttons["What is the 2nd prime?"].tap()
    let alert = app.alerts["The 2nd prime is 3"]
    XCTAssert(alert.waitForExistence(timeout: 5))
    alert.scrollViews.otherElements.buttons["Ok"].tap()
    app.buttons["Is this prime?"].tap()
    app.buttons["Save to favorite primes"].tap()
    app.children(matching: .window).element(boundBy: 0).children(matching: .other).element.children(matching: .other).element(boundBy: 0).swipeDown()
  }
}
