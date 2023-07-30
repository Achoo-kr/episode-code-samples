import ComposableArchitecture
import XCTest
@testable import Todos

class TodosTests: XCTestCase {
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
        uuid: { fatalError("unimplemented") }
      )
    )
    /// 테스트가 만약 실패한다면, 일치하지 않는 상태 메세지를 정확히 출력합니다.
    store.assert(
      .send(.todo(index: 0, action: .checkboxTapped)) {
        $0.todos[0].isComplete = true
      }
    )
  }
  
  /// 항목을 추가하기 위한 기능을 테스트합니다.
  /// 테스트를 실행하면 매번 다른 UUID항목이 생성되기 때문에 오류 메세지가 변경되는 것을 볼 수 있습니다.
  /// 코드가 실행될 때 마다 임의의 값 UUID를 얻는 것을 의미합니다.
  /// 이는 제대로 제어되지 않는 reducer에 UUID에 대한 의존성이 남아있기 때문입니다.
  /// initializer를 직접 호출함으로써 UUID를 계산하기 위해 실제로 접근하고 있으며 테스트하기 위해서는 이를 제어하는 방법이 필요합니다.
    
  /// struct AppEnvironment {
  ///  var uuid: () -> UUID
  /// }
  /// 이를 통해 UUID를 만들 때 예측가능하다는 것을 의미합니다 -> reducer가 제어된 환경에서 작동하고 있음을 알 수 있음
  func testAddTodo() {
    let store = TestStore(
      initialState: AppState(),
      reducer: appReducer,
      environment: AppEnvironment(
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
  
  /// 완료된 목록이 아래쪽으로 정렬되게 하는 함수
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
        uuid: { fatalError("unimplemented") }
      )
    )
    /// 현재 2가지의 목록이 존재합니다.
    /// 0번째의 목록을 수행해서 완료가 되었다고 할 때 1번과 서로의 위치가 바뀌어야합니다.
    /// 주석을 포함한 3가지의 방법을 제시합니다.
    /// 오류가 발생했을 때 무엇이 잘못되었는지 매우 명확하도록 적절한 논리 로직을 추가 할 가치가 있습니다.
    store.assert(
      .send(.todo(index: 0, action: .checkboxTapped)) {
        $0.todos[0].isComplete = true
//        $0.todos = [
//          $0.todos[1],
//          $0.todos[0],
//        ]
        $0.todos.swapAt(0, 1)
        
//        $0.todos = [
//          Todo(
//            description: "Eggs",
//            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
//            isComplete: false
//          ),
//
//          Todo(
//            description: "Milk",
//            id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
//            isComplete: true
//          ),
//        ]
      
      }
    )
  }
  
}
