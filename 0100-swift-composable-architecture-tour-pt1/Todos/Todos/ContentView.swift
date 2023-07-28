import ComposableArchitecture
import SwiftUI


/// - 기능이 작업을 수행하는 데 필요한 상태를 정의하고, (State)
/// - 기능에서 발생할 수 있는 액션을 정의하고, (Action)
/// - 기능이 작업을 수행하는 데 필요한 종속성 환경을 정의합니다. (Environment)

    ///viewStore가 상태 방출의 중복을 제거하기 위해서 Equatable채택이 필요합니다.
struct Todo: Equatable, Identifiable {
  var description = ""
  let id: UUID
  var isComplete = false
}

/// [State] State는 독립적인 데이터 값을 보유하기 때문에 일반적으로 구조체로 생성합니다.
struct AppState: Equatable {
  var todos: [Todo] = []
}

/// [Action] Action은 Button Tap, TextField의 text값 입력 등 사용자가 UI에서 수행가능한 다양한 유형을 나타내기 때문에
/// 일반적으로 열거형으로 생성합니다.
enum AppAction {
  case todoCheckboxTapped(index: Int)
  case todoTextFieldChanged(index: Int, text: String)
}

/// [Environment] API 클라이언트, 분석 클라이언트, 날짜 initializer 등과 같이 기능이 작업을 수행하는데 필요한 모든 종속성을 포함하기 때문에
/// Environment는 구조체로 생성합니다.
struct AppEnvironment {
}

/// App을 위한 reducer를 정의합니다.
/// reducer는 State, Action, Environment를 하나의 패키지로 결합하는 것입니다.
/// App을 실행하는 비즈니스 로직을 담당하는 것입니다.
///
let appReducer = Reducer<AppState, AppAction, AppEnvironment> { state, action, environment in
  switch action {
  case .todoCheckboxTapped(index: let index):
    state.todos[index].isComplete.toggle()
    /// Effect를 실행 할 필요가 없으므로 아무것도 하지않는 특수 Effect를 반환할 수 있습니다. (.none)
    return .none
  case .todoTextFieldChanged(index: let index, text: let text):
    state.todos[index].description = text
    return .none
  }
}
/// debug를 통해 저장소로 전송되는 모든 작업, 결과의 상태 변경을 기록하는 메서드를 실행합니다.
/// SceneDelegate나 특정한 reducer로 localize하는 경우 끝에 첨부하여 사용할 수 있으며 두 접근방식 모두 유효합니다.
.debug()

struct ContentView: View {
  let store: Store<AppState, AppAction>
    /// 이전에는 viewStore를 사용하려면 View에 Field를 추가하여 viewStore를 보관하고 @ObservedObject로 만들었지만,
    /// 이제는 View에 액세스 가능한 특수한 뷰를 만들기만 하면 됩니다.
//  @ObservableObject var viewStore
  
  var body: some View {
    NavigationView {
      WithViewStore(self.store) { viewStore in
        List {
//          zip(viewStore.todos.indices, viewStore.todos)
            
          /// 어떠한 요소에 접근하는지 알 수 없기 때문에 요소의 id를 키 경로로 지정해주어야 합니다.
          /// Swift 에서는 고유하게 식별되는 데이터 값을 전달하는 유형을 표현하는 프로토콜이 있습니다. (Identifiable)
          /// reducer의 기능을 사용하려면 index가 필요하다는 것을 알 수 있습니다.
          /// 따라서 enumerated()를 통해 인덱스에 액세스할 수 있습니다.
          ForEach(Array(viewStore.todos.enumerated()), id: \.element.id) { index, todo in
            HStack {
              /// 로직이 실행되기 위해서는 store에 Action을 보냅니다.
              Button(action: { viewStore.send(.todoCheckboxTapped(index: index)) }) {
                Image(systemName: todo.isComplete ? "checkmark.square" : "square")
              }
              .buttonStyle(PlainButtonStyle())
              
                /// 로직이 실행되기 위해서는 store에 Action을 보냅니다.
                /// TextField에서는 text를 설정하고 알림을 받을 수 있는 binding이 필요합니다.
              TextField(
                "Untitled todo",
                text: viewStore.binding(
                  get: { $0.todos[index].description },
                  send: { .todoTextFieldChanged(index: index, text: $0) }
                )
              )
            }
            .foregroundColor(todo.isComplete ? .gray : nil)
          }
        }
        .navigationBarTitle("Todos")
      }
    }
  }
}

/// Preview에서도 다음과 같이 설정이 필요합니다.
/// 스토어를 생성하려면 초기상태와 비즈니스 로직 구동을 위한 reducer, 스토어가 실행되는 environment가 필요합니다.
struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    ContentView(
      store: Store(
        initialState: AppState(
          todos: [
            Todo(
              description: "Milk",
              id: UUID(),
              isComplete: false
            ),
            Todo(
              description: "Eggs",
              id: UUID(),
              isComplete: false
            ),
            Todo(
              description: "Hand Soap",
              id: UUID(),
              isComplete: true
            ),
          ]
        ),
        reducer: appReducer,
        environment: AppEnvironment()
      )
    )
  }
}
