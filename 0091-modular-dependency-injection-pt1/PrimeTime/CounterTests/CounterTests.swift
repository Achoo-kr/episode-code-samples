import XCTest
@testable import Counter
import ComposableArchitecture
import ComposableArchitectureTestSupport
import SnapshotTesting
import SwiftUI

class CounterTests: XCTestCase {
  override func setUp() {
    super.setUp()
    Current = .mock
  }

  func testSnapshots() {
    let store = Store(initialValue: CounterViewState(), reducer: counterViewReducer)
    let view = CounterView(store: store)

    let vc = UIHostingController(rootView: view)
    vc.view.frame = UIScreen.main.bounds

    assertSnapshot(matching: vc, as: .windowedImage)

    store.send(.counter(.incrTapped))
    assertSnapshot(matching: vc, as: .windowedImage)

    store.send(.counter(.incrTapped))
    assertSnapshot(matching: vc, as: .windowedImage)

    store.send(.counter(.nthPrimeButtonTapped))
    assertSnapshot(matching: vc, as: .windowedImage)

    var expectation = self.expectation(description: "wait")
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
      expectation.fulfill()
    }
    self.wait(for: [expectation], timeout: 0.5)
    assertSnapshot(matching: vc, as: .windowedImage)

    store.send(.counter(.alertDismissButtonTapped))
    expectation = self.expectation(description: "wait")
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
      expectation.fulfill()
    }
    self.wait(for: [expectation], timeout: 0.5)
    assertSnapshot(matching: vc, as: .windowedImage)

    store.send(.counter(.isPrimeButtonTapped))
    assertSnapshot(matching: vc, as: .windowedImage)

    store.send(.primeModal(.saveFavoritePrimeTapped))
    assertSnapshot(matching: vc, as: .windowedImage)

    store.send(.counter(.primeModalDismissed))
    assertSnapshot(matching: vc, as: .windowedImage)
  }

  func testIncrDecrButtonTapped() {
    assert(
      initialValue: CounterViewState(count: 2),
      reducer: counterViewReducer,
      steps:
      Step(.send, .counter(.incrTapped)) { $0.count = 3 },
      Step(.send, .counter(.incrTapped)) { $0.count = 4 },
      Step(.send, .counter(.decrTapped)) { $0.count = 3 }
    )
  }

  func testNthPrimeButtonHappyFlow() {
    Current.nthPrime = { _ in .sync { 17 } }

    assert(
      initialValue: CounterViewState(
        alertNthPrime: nil,
        count: 7,
        isNthPrimeButtonDisabled: false
      ),
      reducer: counterViewReducer,
      steps:
      Step(.send, .counter(.nthPrimeButtonTapped)) {
        $0.isNthPrimeButtonDisabled = true
      },
      Step(.receive, .counter(.nthPrimeResponse(n: 7, prime: 17))) {
        $0.alertNthPrime = PrimeAlert(n: $0.count, prime: 17)
        $0.isNthPrimeButtonDisabled = false
      },
      Step(.send, .counter(.alertDismissButtonTapped)) {
        $0.alertNthPrime = nil
      }
    )
  }

  func testNthPrimeButtonUnhappyFlow() {
    Current.nthPrime = { _ in .sync { nil } }

    assert(
      initialValue: CounterViewState(
        alertNthPrime: nil,
        count: 7,
        isNthPrimeButtonDisabled: false
      ),
      reducer: counterViewReducer,
      steps:
      Step(.send, .counter(.nthPrimeButtonTapped)) {
        $0.isNthPrimeButtonDisabled = true
      },
      Step(.receive, .counter(.nthPrimeResponse(n: 7, prime: nil))) {
        $0.isNthPrimeButtonDisabled = false
      }
    )
  }

    /*
     카운터 기능과 소수 모달 기능이 제대로 통합되는지 확인하는 테스트
     특히 사용자가 카운터를 1씩 증가시킨 다음 좋아하는 소수에서 해당 숫자를 추가하거나 제거하는 과정을 시뮬레이션 했다.
     */
  func testPrimeModal() {
    Current = .mock // Effect에 대해 테스트하는데, 기본적으로 Counter 모듈에만 Effect가 정의되어있기 때문에 PrimeModal과 독립되어있다.
      // PrimeModal에 대한 Effect를 확인할 수 없기 때문에 해당 테스트 함수에 mock Effect를 반영한다.
    
    assert(
      initialValue: CounterViewState(
        count: 1,
        favoritePrimes: [3, 5]
      ),
      reducer: counterViewReducer,
      steps:
      Step(.send, .counter(.incrTapped)) {
        $0.count = 2
      },
      Step(.send, .primeModal(.saveFavoritePrimeTapped)) {
        $0.favoritePrimes = [3, 5, 2]
      },
      Step(.send, .primeModal(.removeFavoritePrimeTapped)) {
        $0.favoritePrimes = [3, 5]
      }
    )
  }
}
