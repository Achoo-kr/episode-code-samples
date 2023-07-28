import CasePaths
import Combine
import ComposableArchitecture
import PrimeModal
import SwiftUI

public enum CounterAction: Equatable {
  case decrTapped
  case incrTapped
  case nthPrimeButtonTapped
  case nthPrimeResponse(n: Int, prime: Int?)
  case alertDismissButtonTapped
  case isPrimeButtonTapped
  case primeModalDismissed
}

public typealias CounterState = (
  alertNthPrime: PrimeAlert?,
  count: Int,
  isNthPrimeButtonDisabled: Bool,
  isPrimeModalShown: Bool
)

public func counterReducer(state: inout CounterState, action: CounterAction) -> [Effect<CounterAction>] {
  switch action {
  case .decrTapped:
    state.count -= 1
    let count = state.count
    return [
      .fireAndForget {
        print(count)
      },

      Just(CounterAction.incrTapped)
        .delay(for: 1, scheduler: DispatchQueue.main)
        .eraseToEffect()
    ]

  case .incrTapped:
    state.count += 1
    return []

  case .nthPrimeButtonTapped:
    state.isNthPrimeButtonDisabled = true
    let n = state.count
    return [
      Current.nthPrime(state.count) // Current에 접근하여 현재 종속성을 가져온다. 종속성 관련해서는 이제 Current에 의해서면 통제가능
        .map { CounterAction.nthPrimeResponse(n: n, prime: $0) }
        .receive(on: DispatchQueue.main)
        .eraseToEffect()
    ]

  case let .nthPrimeResponse(n, prime):
    state.alertNthPrime = prime.map { PrimeAlert(n: n, prime: $0) }
    state.isNthPrimeButtonDisabled = false
    return []

  case .alertDismissButtonTapped:
    state.alertNthPrime = nil
    return []

  case .isPrimeButtonTapped:
    state.isPrimeModalShown = true
    return []

  case .primeModalDismissed:
    state.isPrimeModalShown = false
    return []
  }
}

/*
 Environment가 작동하는 방식이다.
 시작하기가 매우 쉽고, 종속성에 액세스하는 일관된 단일 방법을 제공하며, 모든 종속성을 한 번에 모의하는 것도 간단하다.

 */
struct CounterEnvironment {
  var nthPrime: (Int) -> Effect<Int?> // var로 설정한 이유: live, mock 두가지 케이스를 할당해야하기 때문
}

extension CounterEnvironment { // 실제 작동하는 종속성
  static let live = CounterEnvironment(nthPrime: Counter.nthPrime)
}

// 현재의 종속성 주입 (종속성 프로퍼티)
var Current = CounterEnvironment.live

extension CounterEnvironment { // mock 데이터로 작동하는 종속성(테스트에 사용)
  static let mock = CounterEnvironment(nthPrime: { _ in .sync { 17 }})
}

public let counterViewReducer = combine(
  pullback(
    counterReducer,
    value: \CounterViewState.counter,
    action: /CounterViewAction.counter
  ),
  pullback(
    primeModalReducer,
    value: \.primeModal,
    action: /CounterViewAction.primeModal
  )
)

public struct PrimeAlert: Equatable, Identifiable {
  public let n: Int
  public let prime: Int
  public var id: Int { self.prime }

  public init(n: Int, prime: Int) {
    self.n = n
    self.prime = prime
  }
}

public struct CounterViewState: Equatable {
  public var alertNthPrime: PrimeAlert?
  public var count: Int
  public var favoritePrimes: [Int]
  public var isNthPrimeButtonDisabled: Bool
  public var isPrimeModalShown: Bool

  public init(
    alertNthPrime: PrimeAlert? = nil,
    count: Int = 0,
    favoritePrimes: [Int] = [],
    isNthPrimeButtonDisabled: Bool = false,
    isPrimeModalShown: Bool = false
  ) {
    self.alertNthPrime = alertNthPrime
    self.count = count
    self.favoritePrimes = favoritePrimes
    self.isNthPrimeButtonDisabled = isNthPrimeButtonDisabled
    self.isPrimeModalShown = isPrimeModalShown
  }

  var counter: CounterState {
    get { (self.alertNthPrime, self.count, self.isNthPrimeButtonDisabled, self.isPrimeModalShown) }
    set { (self.alertNthPrime, self.count, self.isNthPrimeButtonDisabled, self.isPrimeModalShown) = newValue }
  }

  var primeModal: PrimeModalState {
    get { (self.count, self.favoritePrimes) }
    set { (self.count, self.favoritePrimes) = newValue }
  }
}

public enum CounterViewAction: Equatable {
  case counter(CounterAction)
  case primeModal(PrimeModalAction)
}

public struct CounterView: View {
  @ObservedObject var store: Store<CounterViewState, CounterViewAction>

  public init(store: Store<CounterViewState, CounterViewAction>) {
    self.store = store
  }

  public var body: some View {
    VStack {
      HStack {
        Button("-") { self.store.send(.counter(.decrTapped)) }
        Text("\(self.store.value.count)")
        Button("+") { self.store.send(.counter(.incrTapped)) }
      }
      Button("Is this prime?") { self.store.send(.counter(.isPrimeButtonTapped)) }
      Button("What is the \(ordinal(self.store.value.count)) prime?") {
        self.store.send(.counter(.nthPrimeButtonTapped))
      }
      .disabled(self.store.value.isNthPrimeButtonDisabled)
    }
    .font(.title)
    .navigationBarTitle("Counter demo")
    .sheet(
      isPresented: .constant(self.store.value.isPrimeModalShown),
      onDismiss: { self.store.send(.counter(.primeModalDismissed)) }
    ) {
      IsPrimeModalView(
        store: self.store.view(
          value: { ($0.count, $0.favoritePrimes) },
          action: { .primeModal($0) }
        )
      )
    }
    .alert(
      item: .constant(self.store.value.alertNthPrime)
    ) { alert in
      Alert(
        title: Text("The \(ordinal(self.store.value.count)) prime is \(alert.prime)"),
        dismissButton: .default(Text("Ok")) {
          self.store.send(.counter(.alertDismissButtonTapped))
        }
      )
    }
  }
}

func ordinal(_ n: Int) -> String {
  let formatter = NumberFormatter()
  formatter.numberStyle = .ordinal
  return formatter.string(for: n) ?? ""
}
