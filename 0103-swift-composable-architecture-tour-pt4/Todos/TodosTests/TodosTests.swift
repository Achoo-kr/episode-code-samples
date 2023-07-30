import ComposableArchitecture
import XCTest
@testable import Todos

class TodosTests: XCTestCase {
  let scheduler = DispatchQueue.testScheduler

  func testCompletingTodo() {
    let store = TestStore(
      initialState: AppState(
        todos: [
          Todo(
            description: "Milk",
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
            isComplete: false
          )
        ]
      ),
      reducer: appReducer,
      environment: AppEnvironment(
        mainQueue: scheduler.eraseToAnyScheduler(),
        uuid: { fatalError("unimplemented") }
      )
    )

//    scheduler.advance(by: 1000)
    
    store.assert(
      .send(.todo(index: 0, action: .checkboxTapped)) {
        $0.todos[0].isComplete = true
      },
      .do {
//        _ = XCTWaiter.wait(for: [self.expectation(description: "wait")], timeout: 1)
        self.scheduler.advance(by: 1)
      },
      .receive(.todoDelayCompleted)
    )
  }
  
  func testAddTodo() {
    let store = TestStore(
      initialState: AppState(),
      reducer: appReducer,
      environment: AppEnvironment(
      mainQueue: scheduler.eraseToAnyScheduler(),
        uuid: { UUID(uuidString: "DEADBEEF-DEAD-BEEF-DEAD-DEADBEEFDEAD")! }
      )
    )
    
    store.assert(
      .send(.addButtonTapped) {
        $0.todos = [
          Todo(
            description: "",
            id: UUID(uuidString: "DEADBEEF-DEAD-BEEF-DEAD-DEADBEEFDEAD")!,
            isComplete: false
          )
        ]
      }
    )
  }
  
  func testTodoSorting() {
    let store = TestStore(
      initialState: AppState(
        todos: [
          Todo(
            description: "Milk",
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
            isComplete: false
          ),
          Todo(
            description: "Eggs",
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            isComplete: false
          )
        ]
      ),
      reducer: appReducer,
      environment: AppEnvironment(
      mainQueue: scheduler.eraseToAnyScheduler(),
        uuid: { fatalError("unimplemented") }
      )
    )
      /// 기존 Test suite 의 문제점:
      /// 1. 완료되지 않은 Effect가 진행중
      /// 2. assert에서 상태에 대한 변경 사항이 실제와 일치하지 않음
    store.assert(
      /// 2의 해결: .checkboxTapped가 전송된 후 그 다음 첫번째 항목의 isComplete 플래그가 true로 바뀌기 때문
      .send(.todo(index: 0, action: .checkboxTapped)) {
        $0.todos[0].isComplete = true
      },
      /// 1의 해결: 1초가 지나면 작업을 전달하는 지연 효과
      /// 단계 사이에 이와 같은 작은 명령형 작업 삽입을 지원함 (블록)
      .do {
          /// 다음 단계로 넘어가기 전 실행이 되므로 여기에서 잠시 기다릴 수 있습니다.
//        _ = XCTWaiter.wait(for: [self.expectation(description: "wait")], timeout: 1)
        self.scheduler.advance(by: 1)
      },
      /// 이후 "해당 값을 받을 것이다" 라고 예상했다면 이를 증명해야 합니다.
      .receive(.todoDelayCompleted) {
        /// 값을 받고 실제로 상태가 어떻게 변경되었는지에 대한 설명이 필요합니다.
        $0.todos.swapAt(0, 1)
      }
    )
  }
  
  /// Effect의 취소가 실제로 발생하고 있는 것인지 확인하기 위해 테스트를 진행합니다.
  func testTodoSorting_Cancellation() {
    let store = TestStore(
      initialState: AppState(
        todos: [
          Todo(
            description: "Milk",
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
            isComplete: false
          ),
          Todo(
            description: "Eggs",
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            isComplete: false
          )
        ]
      ),
      reducer: appReducer,
      environment: AppEnvironment(
        mainQueue: scheduler.eraseToAnyScheduler(),
        uuid: { fatalError("unimplemented") }
      )
    )
    
    store.assert(
      .send(.todo(index: 0, action: .checkboxTapped)) {
        $0.todos[0].isComplete = true
      },
      .do {
//        _ = XCTWaiter.wait(for: [self.expectation(description: "wait")], timeout: 0.5)
        self.scheduler.advance(by: 0.5)
      },
      .send(.todo(index: 0, action: .checkboxTapped)) {
        $0.todos[0].isComplete = false
      },
      .do {
//        _ = XCTWaiter.wait(for: [self.expectation(description: "wait")], timeout: 1)
        self.scheduler.advance(by: 1)
      },
      .receive(.todoDelayCompleted)
    )
  }
}
