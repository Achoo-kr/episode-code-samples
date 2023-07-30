import XCTest
@testable import PrimeTime
import ComposableArchitecture
@testable import Counter
@testable import FavoritePrimes
@testable import PrimeModal
import ComposableArchitectureTestSupport

class PrimeTimeTests: XCTestCase {
  func testIntegration() {
//    Counter.Current = .mock
//    FavoritePrimes.Current = .mock
// 하나의 테스트에서 두 가지 다른 기능의 Side Effect를 실행
    var fileClient = FileClient.mock
    fileClient.load = { _ in Effect<Data?>.sync {
    try! JSONEncoder().encode([2, 31, 7])
    } }

    assert(
      initialValue: AppState(count: 4),
      reducer: appReducer,
      environment: (
        fileClient: fileClient,
        nthPrime: { _ in .sync { 17 } }
      ),
      /*
       사용자가 n번째 소수 무엇인가요 버튼 탭
       n번째 소수 버튼 비활성화
       Side Effect는 17이 포함된 응답인 액션을 시스템에 공급. 이 값은 Environment의 의존성에서 직접 나오는 값
       n번재 Prime 버튼이 다시 활성화 되고 경고 표시
       사용자가 alert의 dismiss 버튼 탭하여 alert창 닫힘
       favoritePrimes 화면에서 Load 버튼 탭
       상태 변경안됨
       마지막으로 일부 소수를 State에 load하는 과정에서 action이 수신된다. 이 값은 Enviroment의 의존성에서 직접 나오는 값
       favoritePrimes 배열이 설정
       */
      steps:
      Step(.send, .counterView(.counter(.nthPrimeButtonTapped))) {
        $0.isNthPrimeButtonDisabled = true
      },
      Step(.receive, .counterView(.counter(.nthPrimeResponse(n: 4, prime: 17)))) {
        $0.isNthPrimeButtonDisabled = false
        $0.alertNthPrime = PrimeAlert(n: 4, prime: 17)
      },
      Step(.send, .favoritePrimes(.loadButtonTapped)),
      Step(.receive, .favoritePrimes(.loadedFavoritePrimes([2, 31, 7]))) {
        $0.favoritePrimes = [2, 31, 7]
      }
    )
  }
}
