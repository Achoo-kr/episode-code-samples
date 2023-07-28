import XCTest
@testable import FavoritePrimes

class FavoritePrimesTests: XCTestCase {
//  var environment:

  override func setUp() {
    super.setUp()
      // 더이상 전역적인 Environment를 사용하지 않으므로 모두 주석처리
//    Current = .mock

//    self.environment = (
//    )
  }

    // FavoritePrimes의 mock Environment를 전달
  func testDeleteFavoritePrimes() {
    var state = [2, 3, 5, 7]
    let effects = favoritePrimesReducer(state: &state, action: .deleteFavoritePrimes([2]), environment: .mock)

    XCTAssertEqual(state, [2, 3, 7])
    XCTAssert(effects.isEmpty)
  }

    // reducer에서 environment가 호출되는지 확인하는 코드
    // 파일 저장하는 Endpoint를 통해 reducer에서 environment가 호출되는지 확인.
    // 이 용도의 environment를 새로 만들고 테스트
  func testSaveButtonTapped() {
    var didSave = false
    var environment = FileClient.mock
    environment.save = { _, data in
      .fireAndForget {
        didSave = true
      }
    }

    var state = [2, 3, 5, 7]
    let effects = favoritePrimesReducer(state: &state, action: .saveButtonTapped, environment: environment)

    XCTAssertEqual(state, [2, 3, 5, 7])
    XCTAssertEqual(effects.count, 1)

    effects[0].sink { _ in XCTFail() }

    XCTAssert(didSave)
  }
    
    /*
     FileClient의 load Endpoint가 특정 데이터를 로드하는 상황을 시뮬레이션
     이를 위해 이를 수행하는 파일 클라이언트를 구성
     */

  func testLoadFavoritePrimesFlow() {
    var environment = FileClient.mock
    environment.load = { _ in .sync { try! JSONEncoder().encode([2, 31]) } }

    var state = [2, 3, 5, 7]
    var effects = favoritePrimesReducer(state: &state, action: .loadButtonTapped, environment: environment)

    XCTAssertEqual(state, [2, 3, 5, 7])
    XCTAssertEqual(effects.count, 1)

    var nextAction: FavoritePrimesAction!
    let receivedCompletion = self.expectation(description: "receivedCompletion")
    effects[0].sink(
      receiveCompletion: { _ in
        receivedCompletion.fulfill()
    },
      receiveValue: { action in
        XCTAssertEqual(action, .loadedFavoritePrimes([2, 31]))
        nextAction = action
    })
    self.wait(for: [receivedCompletion], timeout: 0)

    effects = favoritePrimesReducer(state: &state, action: nextAction, environment: environment)

    XCTAssertEqual(state, [2, 31])
    XCTAssert(effects.isEmpty)
  }

}
