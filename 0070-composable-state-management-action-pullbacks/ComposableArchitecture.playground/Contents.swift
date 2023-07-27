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

    // AppAction 열거형의 각 케이스 프로퍼티 값을 얻기 위한 프로퍼티
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

// MARK: - 열거형 관리도구 패키지
/*
 https://github.com/pointfreeco/swift-enum-properties.git
위 패키지를 설치하면 아래 코드 작성시 Xcode가 열거형 자료형 Key-Path, 프로퍼티 속성등을 추적해주는 기능을 사용할 수 있다.
없어도 프로젝트 진행하는데 문제 안되지만, enum 관리가 수월해짐 (SwiftUI에서 작동시 에러발생하는 현상 있음 *해결법 아직 찾지못함)
 구조체 타입에서 구조체에 '.'을 붙여서 구조체 내부 인스턴스에 접근하면서 관리하기 쉬워지듯이 이와 같은 Xcode 툴을 열거형에도 제공함
let someAction = AppAction.counter(.incrTapped)
someAction.counter
someAction.favoritePrimes

패키지 설치 후 아래 코드 작성시 Key-Path 프로퍼티 자동완성 도구 사용가능
\AppAction.counter
// WritableKeyPath<AppAction, CounterAction?>

*/

// (A) -> A
// (inout A) -> Void

// (A, B) -> (A, C)
// (inout A, B) -> C

// (Value, Action) -> Value
// (inout Value, Action) -> Void

//[1, 2, 3].reduce(into: <#T##Result#>, <#T##updateAccumulatingResult: (inout Result, Int) throws -> ()##(inout Result, Int) throws -> ()#>)

/*
 counterReducer에 사용되는 Action을 가장 기본단위의 Action으로 나타내기위해 변형된 reducer 형태
 */
func counterReducer(state: inout Int, action: CounterAction) {
  switch action {
  case .decrTapped:
    state -= 1

  case .incrTapped:
    state += 1
  }
}

/*
 primeModalReducer에 사용되는 Action을 가장 기본단위의 Action으로 나타내기위해 변형된 reducer 형태
 */
func primeModalReducer(state: inout AppState, action: PrimeModalAction) -> Void {
  switch action {
  case .removeFavoritePrimeTapped:
    state.favoritePrimes.removeAll(where: { $0 == state.count })
    state.activityFeed.append(.init(timestamp: Date(), type: .removedFavoritePrime(state.count)))

  case .saveFavoritePrimeTapped:
    state.favoritePrimes.append(state.count)
    state.activityFeed.append(.init(timestamp: Date(), type: .addedFavoritePrime(state.count)))
  }
}

struct FavoritePrimesState {
  var favoritePrimes: [Int]
  var activityFeed: [AppState.Activity]
}

/*
 favoritePrimesReducer에 사용되는 Action을 가장 기본단위의 Action으로 나타내기위해 변형된 reducer 형태
 */
func favoritePrimesReducer(state: inout FavoritePrimesState, action: FavoritePrimesAction) -> Void {
  switch action {
  case let .deleteFavoritePrimes(indexSet):
    for index in indexSet {
      state.activityFeed.append(.init(timestamp: Date(), type: .removedFavoritePrime(state.favoritePrimes[index])))
      state.favoritePrimes.remove(at: index)
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

/*
 LocalAction을 GlobalAction으로 변형하기 위한 pullback 함수
 가장 최소 단위의 Action을 다른 GlobalAction의 타입과 일치시키기 위한 기능을 한다.
 */

func pullback<LocalValue, GlobalValue, LocalAction, GlobalAction>( // State에 대한 pullback 함수와 Action에 대한 pullback 함수를 합친 최종 pullback
  _ reducer: @escaping (inout LocalValue, LocalAction) -> Void,
  value: WritableKeyPath<GlobalValue, LocalValue>,
  action: WritableKeyPath<GlobalAction, LocalAction?> // Optional인 이유: GlobalAction에서 LocalAction을 추출할 때 LocalAction이 항상 존재하지 않을 수 있기 때문
) -> (inout GlobalValue, GlobalAction) -> Void {
  return { globalValue, globalAction in
    guard let localAction = globalAction[keyPath: action] else { return }
    reducer(&globalValue[keyPath: value], localAction)
  }
}

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

// MARK: - enum의 KeyPath 기능 구현 - Key-Path 패키지 작동 원리를 설명하기 위한 내용 (근데 패키지 없어도 잘 작동하는데 이 내용이 왜 있는지 잘 모르겠음;)
/*
 Key-Path 기능을 구현한 구조체
 enum인 경우 Swift에서 Key-Path 기능을 기본 제공하지 않기에
 get/set 의 핵심 기능을 하는 구조체
 
struct _KeyPath<Root, Value> {
  let get: (Root) -> Value
  let set: (inout Root, Value) -> Void
}

 enum도 기본적으로 get/set와 비슷한 기능을 사용할 수 있는데,
 아래 코드는 CounterAction.incrTapped의 열거형 값을 .counter(action) action 변수에 set 하는 기능
AppAction.counter(CounterAction.incrTapped)

let action = AppAction.favoritePrimes(.deleteFavoritePrimes([1]))
let favoritePrimes: FavoritePrimesAction?
switch action {
case let .favoritePrimes(action):
    // 아래 코드는 case let의 action를 favoritePrimes에 할당하는 기능 -> 여기에는 action의 App.favoritePrimes(.deleteFavoritePrimes([1]))의 열거형 값을 get하는 과정이 있다.
  favoritePrimes = action
default:
  favoritePrimes = nil
}

위에서 예시로 사용한 열거형의 get/set의 기능을 key-path로 패키지화한다면 아래처럼 코드를 정의할 수 있다.
 Swift에서 직접적으로 enum의 Key-Path 기능을 지원하지 않는다. Key-Path의 get/set 연산을 enum에서도 사용할 수 있다는 것을 알았다.
 따라서, 열거형에서 사용할 get/set 구조를 Swift의 Struct로 정의하여 Key-Path 기능을 구현하였다.
 Swift에서 열거형의 Key-Path 기능을 제공하진 않지만 이와 매우 유사하게 작동할 수 있도록 한 결과이다.

struct EnumKeyPath<Root, Value> {
  let embed: (Value) -> Root
  let extract: (Root) -> Value?
}
// \AppAction.counter // EnumKeyPath<AppAction, CounterAction>

 https://github.com/pointfreeco/swift-enum-properties.git
 패키지는 위와같은 지금까지 설명한 원리로 열거형에도 구조체와 같은 Key-Path 기능을 쉽게 사용할 수 있도록 되어있다.
 Swift에는 기본적으로 구조체 변수를 쉽게 활용할 수 있도록 하는 툴을 제공하지 않지만 해당 프로퍼티는 위와같은 구조체 개념을 열거형에도 적용할 수 있도록 하여
 구조체 내부 인스턴스에 접근하기 위해 '.'을 입력하면 자동으로 내부 인스턴스를 보여주는 Xcode 툴을 열거형에도 사용할 수 있다.
 */

// _appReducer에 타입명시를 한 이유: combine은 더이상 GlobalAcction이 뭔지 추론할 수 없다. combine 안에 있는 모든 매개변수(pullback)이 제너릭 타입은 일치하지만 정확히 뭔지 대체할 타입이 없기 때문에
let _appReducer: (inout AppState, AppAction) -> Void = combine(
    pullback(counterReducer, value: \.count, action: \.counter),
  pullback(primeModalReducer, value: \.self, action: \.primeModal),
  pullback(favoritePrimesReducer, value: \.favoritePrimesState, action: \.favoritePrimes)
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
