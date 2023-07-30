import CasePaths
import Combine
import ComposableArchitecture
import Counter
import FavoritePrimes
import PrimeAlert
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
  case offlineCounterView(CounterViewAction) // 오프라인 ConuterView에 특화된 새로운 Action 세트
  case favoritePrimes(FavoritePrimesAction)
}

extension AppState {
  var favoritePrimesState: FavoritePrimesState { // FavoritePrimesState에 새로운 의존성 관련 인스턴스가 추가되었기에 수정(Key-Path 기능 설정)
    get {
      (self.alertNthPrime, self.favoritePrimes)
    }
    set {
      (self.alertNthPrime, self.favoritePrimes) = newValue
    }
  }

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

typealias AppEnvironment = (
  fileClient: FileClient,
  nthPrime: (Int) -> Effect<Int?>,
  offlineNthPrime: (Int) -> Effect<Int?> // Offline 의존성에 관련된 새로운 튜플
)

let appReducer: Reducer<AppState, AppAction, AppEnvironment> = combine(
  pullback(
    counterViewReducer,
    value: \AppState.counterView,
    action: /AppAction.counterView,
    environment: { $0.nthPrime }
  ),
  pullback( // OfflineCounterView에서 사용할 pullback reducer
    counterViewReducer,
    value: \AppState.counterView,
    action: /AppAction.offlineCounterView,
    environment: { $0.offlineNthPrime }
  ),
  pullback(
    favoritePrimesReducer,
    value: \.favoritePrimesState,
    action: /AppAction.favoritePrimes,
    environment: { ($0.fileClient, $0.nthPrime) }
  )
)

func activityFeed(
  _ reducer: @escaping Reducer<AppState, AppAction, AppEnvironment>
) -> Reducer<AppState, AppAction, AppEnvironment> {

  return { state, action, environment in
    switch action {
    case .counterView(.counter),
         .offlineCounterView(.counter),
         .favoritePrimes(.loadedFavoritePrimes),
         .favoritePrimes(.loadButtonTapped),
         .favoritePrimes(.saveButtonTapped),
         .favoritePrimes(.primeButtonTapped(_)),
         .favoritePrimes(.nthPrimeResponse),
         .favoritePrimes(.alertDismissButtonTapped):
      break
    case .counterView(.primeModal(.removeFavoritePrimeTapped)),
         .offlineCounterView(.primeModal(.removeFavoritePrimeTapped)):
      state.activityFeed.append(.init(timestamp: Date(), type: .removedFavoritePrime(state.count)))

    case .counterView(.primeModal(.saveFavoritePrimeTapped)),
         .offlineCounterView(.primeModal(.saveFavoritePrimeTapped)):
      state.activityFeed.append(.init(timestamp: Date(), type: .addedFavoritePrime(state.count)))

    case let .favoritePrimes(.deleteFavoritePrimes(indexSet)):
      for index in indexSet {
        state.activityFeed.append(.init(timestamp: Date(), type: .removedFavoritePrime(state.favoritePrimes[index])))
      }
    }

    return reducer(&state, action, environment)
  }
}

let isInExperiment = Bool.random() // 랜덤한 Bool 값을 사용하여 어떤 환경에서 어떤 종속성이 포함된 기능을 사용할지 선택하는 Flag 기능을 제공한다.
// 물론, 랜덤하게 Bool 값을 선택하는 것이 아니라 정확한 기준의 계산 과정이 필요하지만 여튼간에, 이런 방법도 가능하다는 것을 나타낸다.

struct ContentView: View {
  @ObservedObject var store: Store<AppState, AppAction>

  var body: some View {
    NavigationView {
      List {
        if !isInExperiment {
          NavigationLink(
            "Counter demo",
            destination: CounterView(
              store: self.store.view(
                value: { $0.counterView },
                action: { .counterView($0) }
              )
            )
          )
        } else {
          NavigationLink( // 기존 CounterView를 재활용하고 여기에 새로운 오프라인 종속성을 주입하여 생성된 View
            "Offline counter demo",
            destination: CounterView(
              store: self.store.view(
                value: { $0.counterView },
                action: { .offlineCounterView($0) }
              )
            )
          )
        }
        NavigationLink(
          "Favorite primes",
          destination: FavoritePrimesView(
            store: self.store.view(
              value: { $0.favoritePrimesState },
              action: { .favoritePrimes($0) }
            )
          )
        )
      }
      .navigationBarTitle("State management")
    }
  }
}
