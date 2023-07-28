import XCTest
@testable import PrimeTime
import ComposableArchitecture
@testable import Counter
@testable import FavoritePrimes
@testable import PrimeModal

// 각 모듈이 독립적으로 완전히 제어가능한 상태인지 .mock으로 종속성 테스트 확인
class PrimeTimeTests: XCTestCase {
  func testIntegration() {
    Counter.Current = .mock
    FavoritePrimes.Current = .mock
  }
}
