import Combine


// Effect는 Combine 프레임워크의 Publisher 프로토콜을 준수하는 사용자 정의 유형이다.

public struct Effect<Output>: Publisher {
  public typealias Failure = Never

  let publisher: AnyPublisher<Output, Failure>

  public func receive<S>(
    subscriber: S
  ) where S: Subscriber, Failure == S.Failure, Output == S.Input {
    self.publisher.receive(subscriber: subscriber)
  }
}

/*
 Effect는 Publisher로 간단히 감싸서 기존 Publisher을 수정하지 않고 원하는 함수를 새로 정의해서 사용할 수 잇다.
 */
extension Effect {
  public static func fireAndForget(work: @escaping () -> Void) -> Effect {
    return Deferred { () -> Empty<Output, Never> in
      work()
      return Empty(completeImmediately: true)
    }.eraseToEffect()
  }

// Effect에서 동기식 함수를 실행할 때 도움되는 함수
  public static func sync(work: @escaping () -> Output) -> Effect {
    return Deferred {
      Just(work())
    }.eraseToEffect()
  }
}

// 작업 마지막에 Publisher를 Effect 타입으로 변환하는 함수
extension Publisher where Failure == Never {
  public func eraseToEffect() -> Effect<Output> {
    return Effect(publisher: self.eraseToAnyPublisher())
  }
}
