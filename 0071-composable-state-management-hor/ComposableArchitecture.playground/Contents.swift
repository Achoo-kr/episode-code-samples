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

      var addedFavoritePrime: Int? {
        get {
          guard case let .addedFavoritePrime(value) = self else { return nil }
          return value
        }
        set {
          guard case .addedFavoritePrime = self, let newValue = newValue else { return }
          self = .addedFavoritePrime(newValue)
        }
      }

      var removedFavoritePrime: Int? {
        get {
          guard case let .removedFavoritePrime(value) = self else { return nil }
          return value
        }
        set {
          guard case .removedFavoritePrime = self, let newValue = newValue else { return }
          self = .removedFavoritePrime(newValue)
        }
      }
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

  var deleteFavoritePrimes: IndexSet? {
    get {
      guard case let .deleteFavoritePrimes(value) = self else { return nil }
      return value
    }
    set {
      guard case .deleteFavoritePrimes = self, let newValue = newValue else { return }
      self = .deleteFavoritePrimes(newValue)
    }
  }
}
enum AppAction {
  case counter(CounterAction)
  case primeModal(PrimeModalAction)
  case favoritePrimes(FavoritePrimesAction)

  var counter: CounterAction? {
    get {
      guard case let .counter(value) = self else { return nil }
      return value
    }
    set {
      guard case .counter = self, let newValue = newValue else { return }
      self = .counter(newValue)
    }
  }

  var primeModal: PrimeModalAction? {
    get {
      guard case let .primeModal(value) = self else { return nil }
      return value
    }
    set {
      guard case .primeModal = self, let newValue = newValue else { return }
      self = .primeModal(newValue)
    }
  }

  var favoritePrimes: FavoritePrimesAction? {
    get {
      guard case let .favoritePrimes(value) = self else { return nil }
      return value
    }
    set {
      guard case .favoritePrimes = self, let newValue = newValue else { return }
      self = .favoritePrimes(newValue)
    }
  }
}

let someAction = AppAction.counter(.incrTapped)
someAction.counter
someAction.favoritePrimes

\AppAction.counter
// WritableKeyPath<AppAction, CounterAction?>


// (A) -> A
// (inout A) -> Void

// (A, B) -> (A, C)
// (inout A, B) -> C

// (Value, Action) -> Value
// (inout Value, Action) -> Void

//[1, 2, 3].reduce(into: <#T##Result#>, <#T##updateAccumulatingResult: (inout Result, Int) throws -> ()##(inout Result, Int) throws -> ()#>)

func counterReducer(state: inout Int, action: CounterAction) {
  switch action {
  case .decrTapped:
    state -= 1

  case .incrTapped:
    state += 1
  }
}

// MARK: - 고차 reducer 적용을 위한 reducer 변화
/*
 primeModalReducer, favoritePrimesReducer의 변경사항
 SwiftUI의 서로 다른 View에서 Action을 수행할 때, 다른 reducer가 호출되는데
 서로 다른 reducer에 같은 기능을 하는 코드가 있었다. (Action에 대한 결과가 서로 중첩되는 부분이 있었기 때문이다.)
 예를들어, 일반 소수 목록 뷰에서 소수를 삭제하는 것과, 좋아하는 소수 목록 뷰에서 소수를 삭제하는 것. 삭제 후에 '삭제 활동 피드'를 기록하는 로직이 서로 같다.
 이렇게 서로 밀접한 로직이 서로 다른 reducer에 존재한다. 이러한 유형은 서로 다른 모듈에 있는 reducer에서 나타날 수도 있고 그렇게 되면 추후 수정을 하거나 추적하기 어려워진다.
 따라서 여기에 고차 reducer를 적용하여 return으로 클로저(고차함수)를 반환 할 때, 모든 Action에 대해 검사를 reducer 실행 전 선제적으로 수행한다.
 검사 결과, 밀접한 로직을 수행해야하는 Action인 경우 밀접한 로직을 수행하고 더 간단히 축소된 reducer를 실행하는 식으로 할 수 있다.
 이 과정으로 reducer는 더 작은 단위로 된다.
 */
func primeModalReducer(state: inout AppState, action: PrimeModalAction) {
  switch action {
  case .removeFavoritePrimeTapped:
    state.favoritePrimes.removeAll(where: { $0 == state.count })
//  state.activityFeed.append(.init(timestamp: Date(), type: .removedFavoritePrime(state.count))) 삭제
  case .saveFavoritePrimeTapped:
    state.favoritePrimes.append(state.count)
//  state.activityFeed.append(.init(timestamp: Date(), type: .addedFavoritePrime(state.count)))
  }
}

// favoritePrimesReducer의 변경으로 필요없음.
//struct FavoritePrimesState {
//  var favoritePrimes: [Int]
//  var activityFeed: [AppState.Activity]
//}

/*
 favoritePrimesReducer는 이제 activityFeed를 사용하지 않으므로, 매개변수는 FavoritePrimesState 타입에서 [Int] 타입으로 더욱 지역적인 타입 사용 가능
 따라서, FavoritePrimesState 와 관련된 모든 코드는 불필요해짐
 */
func favoritePrimesReducer(state: inout [Int], action: FavoritePrimesAction) {
  switch action {
  case let .deleteFavoritePrimes(indexSet):
    for index in indexSet {
      state.remove(at: index)
//    state.activityFeed.append(.init(timestamp: Date(), type: .removedFavoritePrime(state.favoritePrimes[index]))) 삭제
    }
  }
}

//func appReducer(state: inout AppState, action: AppAction) {
//  switch action {
//  }
//}

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
func pullback<LocalValue, GlobalValue, LocalAction, GlobalAction>(
  _ reducer: @escaping (inout LocalValue, LocalAction) -> Void,
  value: WritableKeyPath<GlobalValue, LocalValue>,
  action: WritableKeyPath<GlobalAction, LocalAction?>
) -> (inout GlobalValue, GlobalAction) -> Void {
  return { globalValue, globalAction in
    guard let localAction = globalAction[keyPath: action] else { return }
    reducer(&globalValue[keyPath: value], localAction)
  }
}

// favoritePrimesReducer의 변경으로 필요없음.
//extension AppState {
//  var favoritePrimesState: FavoritePrimesState {
//    get {
//      FavoritePrimesState(
//        favoritePrimes: self.favoritePrimes,
//        activityFeed: self.activityFeed
//      )
//    }
//    set {
//      self.favoritePrimes = newValue.favoritePrimes
//      self.activityFeed = newValue.activityFeed
//    }
//  }
//}

struct _KeyPath<Root, Value> {
  let get: (Root) -> Value
  let set: (inout Root, Value) -> Void
}

AppAction.counter(CounterAction.incrTapped)

let action = AppAction.favoritePrimes(.deleteFavoritePrimes([1]))
let favoritePrimes: FavoritePrimesAction?
switch action {
case let .favoritePrimes(action):
  favoritePrimes = action
default:
  favoritePrimes = nil
}


struct EnumKeyPath<Root, Value> {
  let embed: (Value) -> Root
  let extract: (Root) -> Value?
}
// \AppAction.counter // EnumKeyPath<AppAction, CounterAction>

/*
 고차함수 reducer
 
 */
func activityFeed(
  _ reducer: @escaping (inout AppState, AppAction) -> Void
) -> (inout AppState, AppAction) -> Void {

  return { state, action in
    switch action {
    case .counter: // counter Action에서 activityFeed 관련된 Effect가 없으므로 break 처리(무시)
      break
        /*
         reducer간 동일한 기능을 하는 로직을 reducer 전에 선제적으로 Action을 switch로 검사 후 로직 수행한다.
         이로서, reducer간 동일한 기능을 하는 로직을 한 곳에서 관리하고 수정할 수 있음.
         reducer는 더 간결해짐.
         */
    case .primeModal(.removeFavoritePrimeTapped):
      state.activityFeed.append(.init(timestamp: Date(), type: .removedFavoritePrime(state.count)))

    case .primeModal(.saveFavoritePrimeTapped):
      state.activityFeed.append(.init(timestamp: Date(), type: .addedFavoritePrime(state.count)))

    case let .favoritePrimes(.deleteFavoritePrimes(indexSet)):
      for index in indexSet {
        state.activityFeed.append(.init(timestamp: Date(), type: .removedFavoritePrime(state.favoritePrimes[index])))
      }
    }

    reducer(&state, action)
  }
}

let _appReducer: (inout AppState, AppAction) -> Void = combine(
  pullback(counterReducer, value: \.count, action: \.counter),
  pullback(primeModalReducer, value: \.self, action: \.primeModal),
  pullback(favoritePrimesReducer, value: \.favoritePrimes, action: \.favoritePrimes)
)
let appReducer = pullback(_appReducer, value: \.self, action: \.self)
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

/*
activityFeed의 변화를 확인하기 위한 로깅 기능이 추가된 고차 reducer 함수
고차 reducer 함수를 사용하면 여러가지 기능을 추가한 reducer를 만들어 선택적으로 사용 가능.
ex) 로깅이 있는 reducer, 로깅 없는 reducer, 추가적인 상태 변경을 위한 reducer 등
 */
func logging<Value, Action>(
  _ reducer: @escaping (inout Value, Action) -> Void
) -> (inout Value, Action) -> Void {
  return { value, action in
    reducer(&value, action)
    print("Action: \(action)")
    print("Value:")
    dump(value)
    print("---")
  }
}

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

/*
 고차 reducer를 사용하게 되면, 다음처럼 appReducer 상위에 상위에 상위에 함수를 덮어 아래처럼 지저분해질 수 있다.
 bar(foo(logger(activityFeed(appReducer))))

 이 때 사용하기 좋은, Overture 라이브러리를 사용하면,
 함수명 나열만으로 중첩 함수를 보기 좋게 표현할 수 있다.
  -> with(appReducer, compose(logging, activityFeed))
 */
// import Overture

import PlaygroundSupport
PlaygroundPage.current.liveView = UIHostingController(
  rootView: ContentView(
    store: Store(
      initialValue: AppState(),
//      reducer: logging(activityFeed(appReducer)) 을 보기좋게 아래처럼 Overture 라이브러리 함수를 사용하여 표현
      reducer: with(
        appReducer,
        compose(
          logging,
          activityFeed
        )
      )
    )
  )
)
