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

public func counterReducer(
  state: inout CounterState,
  action: CounterAction,
  environment: CounterEnvironment
) -> [Effect<CounterAction>] {
  switch action {
  case .decrTapped:
    state.count -= 1
    let count = state.count
    return [
//      .fireAndForget {
//        print(count)
//      },
//
//      Just(CounterAction.incrTapped)
//        .delay(for: 1, scheduler: DispatchQueue.main)
//        .eraseToEffect()
    ]

  case .incrTapped:
    state.count += 1
    return []

      // 전역 변수인 Current 종속성 변수 대신 지역적인 environment 종속성을 사용할 수 있음.
      // Counter에 대한 종속성을 정의한 CounterEnvironment 타입 변수 environment를 사용
  case .nthPrimeButtonTapped:
    state.isNthPrimeButtonDisabled = true
    let n = state.count
    return [
      environment(state.count)
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

// ConterEnvironment를 구조체가 아닌 당일 항목의 타입으로 typealias를 할 수 있다.
//public struct CounterEnvironment {
//  var nthPrime: (Int) -> Effect<Int?>
//}

// 추가로 종속석을 추가한다면, 튜플 형태로 관리 가능
public typealias CounterEnvironment = (Int) -> Effect<Int?>

// CounterEnvironment는 더이상 구조체가 아니므로 제거
//extension CounterEnvironment {
//  public static let live = CounterEnvironment(nthPrime: Counter.nthPrime)
//}

//var Current = CounterEnvironment.live

//extension CounterEnvironment {
//  static let mock = CounterEnvironment(nthPrime: { _ in .sync { 17 }})
//}

/*
 counterViewReducer에는 counterReducer, primeModalReducer을 pullback하여 하나로 관리하는 큰 범위의 reducer이다.
 여기에 큰 범위의 environment를 counterReducer, primeModalReducer에 각각 맞게 변환하여 전달해주고 pullback을 받아야하는데,
 이 두 종류의 environment를 포괄하는 environment 타입이 필요하다.
 그러나 primeModalReducer에 environment는 void 타입이므로, 필요없다. 따라서 counterReducer 자체가 큰 범위의 environment이며
 지역적인 environment가 된다.
 */
public let counterViewReducer: Reducer<CounterViewState, CounterViewAction, CounterEnvironment> = combine(
  pullback(
    counterReducer,
    value: \CounterViewState.counter,
    action: /CounterViewAction.counter,
    environment: { $0 }
  ),
  pullback(
    primeModalReducer,
    value: \.primeModal,
    action: /CounterViewAction.primeModal,
    environment: { _ in () }
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
