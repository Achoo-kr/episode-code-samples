import CasePaths
import Combine
import SwiftUI

/*
 TCA에서 Effect를 표현하는 방식은 Reducer에서 Effect 값 배열을 반환해서
 스토어가 모든 이벤트(배열)를 가져와 Effect를 실행하는 것이다.
 
 Environment의 종속성을 모듈 혹은 글로벌 영역에서 관리하고 제어하는 것은 꾀나 비효율적이고 다양한 종속성에 대해 테스트하기 어려워지거나 불가능하다.
 따라서 종속성을 전역 범위에서 제어하는 것이 아닌, Reducer에 종속성을 주입하여 함수에서 종속성에 따른 Effect를 반환하여 모듈로서 기능을 하게 한다.
 테스트 할 때에도 여러 종속성을 Reducer 함수를 사용하여 결과 값을 확인할 수 있다.
 */


public typealias Reducer<Value, Action, Environment> = (inout Value, Action, Environment) -> [Effect<Action>]
//public typealias Reducer<Value, Action, Environment> = (inout Value, Action) -> (Environment) -> [Effect<Action>]

// Reducer의 제네릭 타입에 Environment를 추가했기에, combine의 제네릭 타입에도 Environment를 추가 후 내부 코드 수정
public func combine<Value, Action, Environment>(
  _ reducers: Reducer<Value, Action, Environment>...
) -> Reducer<Value, Action, Environment> {
  return { value, action, environment in
    let effects = reducers.flatMap { $0(&value, action, environment) }
    return effects
  }
}

/*
 pullback은 가장 작은 도메인단위로 분리된 reducer 로직을 큰 범위의 reducer에서 작동하도록 하는 것이 목적
 그렇다면, 종속성 Environment도 작은 도메인 단위의 종속성으로 분리하여, reducer 자체를 작은 단위의 모듈로 만드는 pullback 함수를 구현
 */
public func pullback<LocalValue, GlobalValue, LocalAction, GlobalAction, LocalEnvironment, GlobalEnvironment>(
  _ reducer: @escaping Reducer<LocalValue, LocalAction, LocalEnvironment>,
  value: WritableKeyPath<GlobalValue, LocalValue>,
  action: CasePath<GlobalAction, LocalAction>,
  environment: @escaping (GlobalEnvironment) -> LocalEnvironment
) -> Reducer<GlobalValue, GlobalAction, GlobalEnvironment> {
  return { globalValue, globalAction, globalEnvironment in
    guard let localAction = action.extract(from: globalAction) else { return [] }
    let localEffects = reducer(&globalValue[keyPath: value], localAction, environment(globalEnvironment))

    return localEffects.map { localEffect in
      localEffect.map(action.embed)
        .eraseToEffect()
    }
  }
}

// Environment 종속성 제너릭을 추가하여 수정된 기존 함수들
public func logging<Value, Action, Environment>(
  _ reducer: @escaping Reducer<Value, Action, Environment>
) -> Reducer<Value, Action, Environment> {
  return { value, action, environment in
    let effects = reducer(&value, action, environment)
    let newValue = value
    return [.fireAndForget {
      print("Action: \(action)")
      print("Value:")
      dump(newValue)
      print("---")
      }] + effects
  }
}

/*
 Store에 Environment 제네릭 타입이 없는 이유
 사실 전체 개념으로서의 스토어는 환경과 거의 관련이 없다.
 스토어 사용자는 스토어에서 상태 값을 가져와서 액션을 전송하는 데만 관심이 있다.
 Environment에 액세스하거나 내부에서 사용 중인 Environment 대해 알 필요가 없다.

 Environment 제너릭을 지웠기 때문에, Environment의 타입을 특정할 수 없고,
 Environment의 타입이 명시된 reducer, environment 인스턴스 타입을 Any로 대체한다.
 */
public final class Store<Value, Action>: ObservableObject {
  private let reducer: Reducer<Value, Action, Any>
  private let environment: Any
  @Published public private(set) var value: Value
  private var viewCancellable: Cancellable?
  private var effectCancellables: Set<AnyCancellable> = []

    /*
     실제로 Environment 정보가 필요한 이니셜라이저의 경우 제네릭을 도입하여 reducer 및 Environment 인수에 사용할 수 있다.

     */
  public init<Environment>(
    initialValue: Value,
    reducer: @escaping Reducer<Value, Action, Environment>,
    environment: Environment
  ) {
    self.reducer = { value, action, environment in
      reducer(&value, action, environment as! Environment)
    }
    self.value = initialValue
    self.environment = environment
  }

  public func send(_ action: Action) {
    let effects = self.reducer(&self.value, action, self.environment)
    effects.forEach { effect in
      var effectCancellable: AnyCancellable?
      var didComplete = false
      effectCancellable = effect.sink(
        receiveCompletion: { [weak self] _ in
          didComplete = true
          guard let effectCancellable = effectCancellable else { return }
          self?.effectCancellables.remove(effectCancellable)
      },
        receiveValue: self.send
      )
      if !didComplete, let effectCancellable = effectCancellable {
        self.effectCancellables.insert(effectCancellable)
      }
    }
  }

  public func view<LocalValue, LocalAction>(
    value toLocalValue: @escaping (Value) -> LocalValue,
    action toGlobalAction: @escaping (LocalAction) -> Action
  ) -> Store<LocalValue, LocalAction> {
    let localStore = Store<LocalValue, LocalAction>(
      initialValue: toLocalValue(self.value),
      reducer: { localValue, localAction, _ in
        self.send(toGlobalAction(localAction))
        localValue = toLocalValue(self.value)
        return []
    },
      environment: self.environment // 다른 것들과 달리 Environment를 Local로 변환하지 않은 이유: 변환 역할은 Reducer가 담당한다.
    )
    localStore.viewCancellable = self.$value.sink { [weak localStore] newValue in
      localStore?.value = toLocalValue(newValue)
    }
    return localStore
  }
}
