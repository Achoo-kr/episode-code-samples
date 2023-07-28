import ComposableArchitecture
@testable import FavoritePrimes
import PlaygroundSupport
import SwiftUI

// 앱의 모듈에 지역적인 개념의 Environment를 주입했기에
// 이전 종속성에 대한 전역변수 Current 대신, 지역적인 environment로 테스트 코드 작성
// 종속성을 앱의 모듈별로 테스트할 수 있기 때문에, 전체 앱을 변경해서 테스트하거나 전체 앱의 실행을 할 필요가 없음.
var environment = FavoritePrimesEnvironment.mock
environment.fileClient.load = { _ in
  Effect.sync { try! JSONEncoder().encode(Array(1...10)) }
}

PlaygroundPage.current.liveView = UIHostingController(
  rootView: NavigationView {
    FavoritePrimesView(
      store: Store<[Int], FavoritePrimesAction>(
        initialValue: [2, 3, 5, 7, 11],
        reducer: favoritePrimesReducer,
        environment: environment
      )
    )
  }
)
