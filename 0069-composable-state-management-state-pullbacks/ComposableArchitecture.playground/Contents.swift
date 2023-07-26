import Combine
import SwiftUI

struct AppState {
  var count = 0
  var favoritePrimes: [Int] = []
  var loggedInUser: User? = nil
  var activityFeed: [Activity] = []

  struct Activity {
    let timestamp: Date
    let type: ActivityType

    enum ActivityType {
      case addedFavoritePrime(Int)
      case removedFavoritePrime(Int)
    }
  }

  struct User {
    let id: Int
    let name: String
    let bio: String
  }
}

enum CounterAction {
  case decrTapped
  case incrTapped
}
enum PrimeModalAction {
  case saveFavoritePrimeTapped
  case removeFavoritePrimeTapped
}
enum FavoritePrimesAction {
  case deleteFavoritePrimes(IndexSet)
}
enum AppAction {
  case counter(CounterAction)
  case primeModal(PrimeModalAction)
  case favoritePrimes(FavoritePrimesAction)
}

// (A) -> A
// (inout A) -> Void

// (A, B) -> (A, C)
// (inout A, B) -> C

// (Value, Action) -> Value
// (inout Value, Action) -> Void

//[1, 2, 3].reduce(into: <#T##Result#>, <#T##updateAccumulatingResult: (inout Result, Int) throws -> ()##(inout Result, Int) throws -> ()#>)

/*
 여타 reducer와 달리 함수 매개변수 타입이 다르다.
 counterReducer의 state 타입은 inout Int
 다른 reducer의 state 타입은 inout AppState
 Combine 함수로 reducer를 묶기 위해서는 함수 타입이 모두 같아야하지만 counterReducer는 작은 단위의 reducer로서, 이를 pullback 함수로 사용해서 합칠 것이다.
 */
func counterReducer(state: inout Int, action: AppAction) {
  switch action {
  case .counter(.decrTapped):
    state -= 1

  case .counter(.incrTapped):
    state += 1

  default:
    break
  }
}

/*
 primeModalReducer의 state는 더 작은 단위까지 쪼개지 않은 이유
 primeModalReducer 함수 내에는 여러 state가 필요해서 쪼개면 더 비효율적이다.
 */
func primeModalReducer(state: inout AppState, action: AppAction) {
  switch action {
  case .primeModal(.removeFavoritePrimeTapped):
    state.favoritePrimes.removeAll(where: { $0 == state.count })
    state.activityFeed.append(.init(timestamp: Date(), type: .addedFavoritePrime(state.count)))

  case .primeModal(.saveFavoritePrimeTapped):
    state.favoritePrimes.append(state.count)
    state.activityFeed.append(.init(timestamp: Date(), type: .removedFavoritePrime(state.count)))

  default:
    break
  }
}

struct FavoritePrimesState {
  var favoritePrimes: [Int]
  var activityFeed: [AppState.Activity]
}

/*
 기존 AppState의 모든 state를 필요로하지 않기에, favoritePrimes, activityFeed 두 개의 state 변수만 갖는 FavoritePrimesState 구조체 정의 후 활용
 */
func favoritePrimesReducer(state: inout FavoritePrimesState, action: AppAction) {
  switch action {
  case let .favoritePrimes(.deleteFavoritePrimes(indexSet)):
    for index in indexSet {
      state.activityFeed.append(.init(timestamp: Date(), type: .removedFavoritePrime(state.favoritePrimes[index])))
      state.favoritePrimes.remove(at: index)
    }

  default:
    break
  }
}

//func appReducer(state: inout AppState, action: AppAction) {
//  switch action {
//  }
//}

/*
 State의 타입이 같고, Action의 타입이 같은 작은 reducer들을
 하나의 큰 reducer로 결합하여 실행하는 함수
 */

func combine<Value, Action>(
  _ reducers: (inout Value, Action) -> Void...
) -> (inout Value, Action) -> Void {
  return { value, action in
    for reducer in reducers {
      reducer(&value, action)
    }
  }
}
final class Store<Value, Action>: ObservableObject {
  let reducer: (inout Value, Action) -> Void
  @Published private(set) var value: Value

  init(initialValue: Value, reducer: @escaping (inout Value, Action) -> Void) {
    self.reducer = reducer
    self.value = initialValue
  }

  func send(_ action: Action) {
    self.reducer(&self.value, action)
  }
}

/*
 GlobalValue에 포함되어있는 프로퍼티를 가져올 수만 있다면(LocalValue) LocalValue에 적용할 작은 단위의 reducer를 구성하고 이를 GlobalValue reducer와 같이 결합하는 방법 -> pullback
 LocalValue의 값을 reducer에 전달하고 변경된 값을 다시 GlobalValue에 적용하여야 한다. 이 과정에 GlobalValue의 get, set 과정이 따라오는데, 이를 한번에 하기 위해 KeyPath 방법을 사용
 KeyPath를 사용함으로써 return 클로저 구문이 더 간결해짐
 */
func pullback<LocalValue, GlobalValue, Action>(
  _ reducer: @escaping (inout LocalValue, Action) -> Void,
  // get: @escaping(GlobalValue) -> LocalValue,
  // set: @escaping(inout GlobalValue, LocalValue) -> Void
  // get, set을 value로 통합
  value: WritableKeyPath<GlobalValue, LocalValue> // localValue의 변화를 GlobalValue에
) -> (inout GlobalValue, Action) -> Void {
  return { globalValue, action in
//      var localValue = get(globalValue)
//      reducer(&localValue, action)
//      set(&globalValue, localValue)
    reducer(&globalValue[keyPath: value], action)
  }
}

/*
 pullback 함수를 통해 favoritePrimesReducer에 전달할 KeyPath가 필요하다.
 AppState에 새로운 변수 favoritePrimesState get / set 를 작성하여 AppState의 favoritePrimes, activityFeed의 값을 전달하면서
 AppState의 KeyPath를 전달하면서 pullback 작업을 이끌어낼 수 있다.
 */
extension AppState {
  var favoritePrimesState: FavoritePrimesState {
    get {
      FavoritePrimesState(
        favoritePrimes: self.favoritePrimes,
        activityFeed: self.activityFeed
      )
    }
    set {
      self.favoritePrimes = newValue.favoritePrimes
      self.activityFeed = newValue.activityFeed
    }
  }
}

let _appReducer = combine(
  pullback(counterReducer, value: \.count),
  primeModalReducer,
  pullback(favoritePrimesReducer, value: \.favoritePrimesState)
)

/*
 AppState -> appState를 이끌어내는 pullback
 */
let appReducer = pullback(_appReducer, value: \.self)
  //combine(combine(counterReducer, primeModalReducer), favoritePrimesReducer)

// [1, 2, 3].reduce(<#T##initialResult: Result##Result#>, <#T##nextPartialResult: (Result, Int) throws -> Result##(Result, Int) throws -> Result#>)

var state = AppState()
//appReducer(state: &state, action: .incrTapped)
//appReducer(state: &state, action: .decrTapped)
//print(
//  counterReducer(
//    state: counterReducer(state: state, action: .incrTapped),
//    action: .decrTapped
//  )
//)
//counterReducer(state: state, action: .decrTapped)

// Store<AppState>

struct PrimeAlert: Identifiable {
  let prime: Int
  var id: Int { self.prime }
}

struct CounterView: View {
  @ObservedObject var store: Store<AppState, AppAction>
  @State var isPrimeModalShown = false
  @State var alertNthPrime: PrimeAlert?
  @State var isNthPrimeButtonDisabled = false

  var body: some View {
    VStack {
      HStack {
        Button("-") { self.store.send(.counter(.decrTapped)) }
        Text("\(self.store.value.count)")
        Button("+") { self.store.send(.counter(.incrTapped)) }
      }
      Button("Is this prime?") { self.isPrimeModalShown = true }
      Button(
        "What is the \(ordinal(self.store.value.count)) prime?",
        action: self.nthPrimeButtonAction
      )
      .disabled(self.isNthPrimeButtonDisabled)
    }
    .font(.title)
    .navigationBarTitle("Counter demo")
    .sheet(isPresented: self.$isPrimeModalShown) {
      IsPrimeModalView(store: self.store)
    }
    .alert(item: self.$alertNthPrime) { alert in
      Alert(
        title: Text("The \(ordinal(self.store.value.count)) prime is \(alert.prime)"),
        dismissButton: .default(Text("Ok"))
      )
    }
  }

  func nthPrimeButtonAction() {
    self.isNthPrimeButtonDisabled = true
    nthPrime(self.store.value.count) { prime in
      self.alertNthPrime = prime.map(PrimeAlert.init(prime:))
      self.isNthPrimeButtonDisabled = false
    }
  }
}

struct IsPrimeModalView: View {
  @ObservedObject var store: Store<AppState, AppAction>

  var body: some View {
    VStack {
      if isPrime(self.store.value.count) {
        Text("\(self.store.value.count) is prime 🎉")
        if self.store.value.favoritePrimes.contains(self.store.value.count) {
          Button("Remove from favorite primes") {
            self.store.send(.primeModal(.removeFavoritePrimeTapped))
          }
        } else {
          Button("Save to favorite primes") {
            self.store.send(.primeModal(.saveFavoritePrimeTapped))
          }
        }
      } else {
        Text("\(self.store.value.count) is not prime :(")
      }
    }
  }
}

struct FavoritePrimesView: View {
  @ObservedObject var store: Store<AppState, AppAction>

  var body: some View {
    List {
      ForEach(self.store.value.favoritePrimes, id: \.self) { prime in
        Text("\(prime)")
      }
      .onDelete { indexSet in
        self.store.send(.favoritePrimes(.deleteFavoritePrimes(indexSet)))
      }
    }
    .navigationBarTitle("Favorite Primes")
  }
}

struct ContentView: View {
  @ObservedObject var store: Store<AppState, AppAction>

  var body: some View {
    NavigationView {
      List {
        NavigationLink(
          "Counter demo",
          destination: CounterView(store: self.store)
        )
        NavigationLink(
          "Favorite primes",
          destination: FavoritePrimesView(store: self.store)
        )
      }
      .navigationBarTitle("State management")
    }
  }
}

// import Overture

import PlaygroundSupport
PlaygroundPage.current.liveView = UIHostingController(
  rootView: ContentView(
    store: Store(initialValue: AppState(), reducer: appReducer)
  )
)
