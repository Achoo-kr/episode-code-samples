import Combine
import SwiftUI

/*
 State를 Combine에서 분리하고, 값 시맨틱의 이점을 활용하는 방법: AppState를 구조체로 변환하기
 변환된 AppState를 사용할 때에는 ObservableObject wrapper를 씌운다.
 AppState 내부는 더이상 ObservableObject을 따르지 않아도 되어 간결해짐
 */
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

/*
 사용자의 액션 유형은 다양한데, 이 중 하나일 수 있기 때문에 열거형으로 작성
 */
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
 업데이트 된 상태를 가져오기 위해 사용자 액션과 현재의 상태를 결합하는 함수
 매개인자 값을 복사해서 함수의 반환형으로 Store에 할당하는 방식을 취하지 않고 함수 내에서 변경된 사항을 State에 즉시 적용할 수 있도록 inout 키워드 사용
 state = appReducer(value, action) 으로 하지 않고, 선언적으로 appReducer($value, action) 을 사용하여 번거로운 과정을 없앴다.
 
 전달받은 액션에 따라 State 수정을 적용한다.
 */
func appReducer(value: inout AppState, action: AppAction) -> Void {
  switch action {
  case .counter(.decrTapped):
    value.count -= 1

  case .counter(.incrTapped):
    value.count += 1

  case .primeModal(.saveFavoritePrimeTapped):
    value.favoritePrimes.append(value.count)
    value.activityFeed.append(.init(timestamp: Date(), type: .addedFavoritePrime(value.count)))

  case .primeModal(.removeFavoritePrimeTapped):
    value.favoritePrimes.removeAll(where: { $0 == value.count })
    value.activityFeed.append(.init(timestamp: Date(), type: .removedFavoritePrime(value.count)))

  case let .favoritePrimes(.deleteFavoritePrimes(indexSet)):
    for index in indexSet {
      let prime = value.favoritePrimes[index]
      value.favoritePrimes.remove(at: index)
      value.activityFeed.append(.init(timestamp: Date(), type: .removedFavoritePrime(prime)))
    }
  }
}

/*
 구조체로 정의된 State에 ObservableObject의 속성을 갖게 하기 위하여 Class로 한번 감싼 형태(-> Store)를 가지고
 구조체로 변환된 State를 사용할 때에는 ObservableObject wrapper(@Published)를 씌운다.
 */
final class Store<Value, Action>: ObservableObject {
    // 사용자 액션에 따른 Store의 State 변화를 Store가 모두 처리할 수 있도록 reducer도 할당해야함(어떤 액션으로 State를 어떻게 변화시킬지 결정지을 녀석)
    // Store의 상태를 변경하고 싶다면 무조건 reducer를 거쳐야한다. State 변경 기능을 독립화 함
  let reducer: (inout Value, Action) -> Void
    /*
    State 타입을 대체할 제너릭 타입 Value가 사용됨
    State에 해당하는 Value 타입 프로퍼티를 @Published로 래핑
     @Published private(set) var value: AppState -> Store의 역할은 값 타입 객체를 래핑하여 관찰자에게 변화에대한 정보를 전달하는 것 뿐이다.
    따라서, AppState에 대해 알 필요가 없으며 이를 제너릭 타입으로 변환한다.
     */
  @Published private(set) var value: Value
    

  init(initialValue: Value, reducer: @escaping (inout Value, Action) -> Void) {
    self.reducer = reducer
    self.value = initialValue
  }

    /*
     외부에서 선언적으로 사용자 액션을 Store에게 보내면 send 함수로 받는다.
     send에서 액션에 따른 reducer를 실행시켜 State를 변경시켜 SwiftUI의 모든 View에 업데이트를 알린다.
     send: Store가 Action을 reducer로 처리할 수 있도록 해주는 함수 즉, 액션에 따른 상태 변경과 관련된 모든 것을 Store가 전담할 수 있도록 한다.
     */
  func send(_ action: Action) {
    self.reducer(&self.value, action)
  }
}

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
 Store<AppState>

 이제 위와 같이 사용하면, AppState에 변경이 발생하는 즉시 무언가 변경되었음을 알려주는 관찰 가능한 객체를 얻게된다. 개별적인 상태에 대한 요소들을 하나의 값으로 통합했다.
 
 */

struct PrimeAlert: Identifiable {
  let prime: Int
  var id: Int { self.prime }
}

// MARK: 변경사항
/*
 State를 Class -> Struct로 변경하고, Store<Value, Action>으로 사용하면서 몇가지 변경사항이 있다.
 self.state -> self.store.value
 (state: self.store.value) -> (store: self.store)
 
 rootView: ContentView(store: Store(value: AppState()))

 */
struct CounterView: View {
    /*
     @ObservedObject var state: AppState
     위 코드를
     @ObservedObject var store: Store<AppState>
     로 변경하여 이제 SwiftUI의 각 View는 AppState의 변경사항을 Store로부터 알림을 받을 수 있다.
     */
  @ObservedObject var store: Store<AppState, AppAction>
    /*
     아래 3개의 변수는 @State인 이유:
     - 상태 변화가 이뤄지더라도 SwiftUI 전체 View에서 글로벌적으로 반영될 필요가 없는 변수이기 때문이다.
     로컬 상태 변수는 해당 View 구조체에서 @State로 선언하여 상태 변화를 추적한다.
     */
  @State var isPrimeModalShown = false
  @State var alertNthPrime: PrimeAlert?
  @State var isNthPrimeButtonDisabled = false

  var body: some View {
    VStack {
      HStack {
          /*
           사용자 액션(Button)을 Store에게 선언적으로 알리고 Store 내부적으로 reducer를 사용하도록 한다.
           해당 reducer는 입력받은 액션을 토대로 State 값을 변화한다.
           */
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

import PlaygroundSupport
PlaygroundPage.current.liveView = UIHostingController(
  rootView: ContentView(
    store: Store(initialValue: AppState(), reducer: appReducer)
  )
)
