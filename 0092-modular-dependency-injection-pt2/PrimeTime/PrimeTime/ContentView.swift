import CasePaths
import Combine
import ComposableArchitecture
import Counter
import FavoritePrimes
import SwiftUI

struct AppState: Equatable {
  var count = 0
  var favoritePrimes: [Int] = []
  var loggedInUser: User? = nil
  var activityFeed: [Activity] = []
  var alertNthPrime: PrimeAlert? = nil
  var isNthPrimeButtonDisabled: Bool = false
  var isPrimeModalShown: Bool = false

  struct Activity: Equatable {
    let timestamp: Date
    let type: ActivityType

    enum ActivityType: Equatable {
      case addedFavoritePrime(Int)
      case removedFavoritePrime(Int)
    }
  }

  struct User: Equatable {
    let id: Int
    let name: String
    let bio: String
  }
}

enum AppAction: Equatable {
  case counterView(CounterViewAction)
  case favoritePrimes(FavoritePrimesAction)
}

extension AppState {
  var counterView: CounterViewState {
    get {
      CounterViewState(
        alertNthPrime: self.alertNthPrime,
        count: self.count,
        favoritePrimes: self.favoritePrimes,
        isNthPrimeButtonDisabled: self.isNthPrimeButtonDisabled,
        isPrimeModalShown: self.isPrimeModalShown
      )
    }
    set {
      self.alertNthPrime = newValue.alertNthPrime
      self.count = newValue.count
      self.favoritePrimes = newValue.favoritePrimes
      self.isNthPrimeButtonDisabled = newValue.isNthPrimeButtonDisabled
      self.isPrimeModalShown = newValue.isPrimeModalShown
    }
  }
}

//struct AppEnvironment {
//  var counter: CounterEnvironment
//  var favoritePrimes: FavoritePrimesEnvironment
//}

// 앱 전체 수준에서의 Environment를 튜플 형태로 정의
// 구조체 전달로서의 단점: 동일한 종속성을 값 복사해서 같은 종속성을 사용하고 싶지만, 서로 다른 버전의 종속성을 가지게 될 수 있음.
// 또한 현재 엡에서는 구조체로서 존재할 필요가 없음. 구조체 인스턴스를 생성해서 구조체 필드에 접근해서 필드 값을 수정하지 않음, 메서드를 추가하지도, 변형하지도, 프로토콜을 따르지도 않음.
// 결국, 구조체를 생성해도 get만 하는 과정을 하기 때문에 차라리 간단한 튜플 형태로 모든 것을 단순화할 수 있다.
/*
 struct AppEnvironment {
   var counter: CounterEnvironment
   var favoritePrimes: FavoritePrimesEnvironment
 }
 를 정의한 것과 같음
 
 여러 다운스트림 기능 간에 종속성을 공유하기 어려운 앱 환경에 중첩된 구조체를 사용하는 대신
 각 기능에 필요한 모든 종속성을 포함하고 공유 가능한 플랫 튜플 형태로 구현
 하지만, Xcode에서 튜플과 관련된 이니셜라이저 자동완성과 같은 도구를 제공해주지 않으므로 이건 단점이다.
 */
typealias AppEnvironment = (
  fileClient: FileClient,
  nthPrime: (Int) -> Effect<Int?>
)

let appReducer: Reducer<AppState, AppAction, AppEnvironment> = combine(
  pullback(
    counterViewReducer,
    value: \AppState.counterView,
    action: /AppAction.counterView,
    environment: { $0.nthPrime }
  ),
  pullback(
    favoritePrimesReducer,
    value: \.favoritePrimes,
    action: /AppAction.favoritePrimes,
    environment: { $0.fileClient }
  )
)

func activityFeed(
  _ reducer: @escaping Reducer<AppState, AppAction, AppEnvironment>
) -> Reducer<AppState, AppAction, AppEnvironment> {

  return { state, action, environment in
    switch action {
    case .counterView(.counter),
         .favoritePrimes(.loadedFavoritePrimes),
         .favoritePrimes(.loadButtonTapped),
         .favoritePrimes(.saveButtonTapped):
      break
    case .counterView(.primeModal(.removeFavoritePrimeTapped)):
      state.activityFeed.append(.init(timestamp: Date(), type: .removedFavoritePrime(state.count)))

    case .counterView(.primeModal(.saveFavoritePrimeTapped)):
      state.activityFeed.append(.init(timestamp: Date(), type: .addedFavoritePrime(state.count)))

    case let .favoritePrimes(.deleteFavoritePrimes(indexSet)):
      for index in indexSet {
        state.activityFeed.append(.init(timestamp: Date(), type: .removedFavoritePrime(state.favoritePrimes[index])))
      }
    }

    return reducer(&state, action, environment)
  }
}

struct ContentView: View {
  @ObservedObject var store: Store<AppState, AppAction>

  var body: some View {
    NavigationView {
      List {
        NavigationLink(
          "Counter demo",
          destination: CounterView(
            store: self.store.view(
              value: { $0.counterView },
              action: { .counterView($0) }
            )
          )
        )
        NavigationLink(
          "Favorite primes",
          destination: FavoritePrimesView(
            store: self.store.view(
              value: { $0.favoritePrimes },
              action: { .favoritePrimes($0) }
            )
          )
        )
      }
      .navigationBarTitle("State management")
    }
  }
}
