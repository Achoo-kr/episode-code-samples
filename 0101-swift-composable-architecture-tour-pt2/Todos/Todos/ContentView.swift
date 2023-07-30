import ComposableArchitecture
import SwiftUI

struct Todo: Equatable, Identifiable {
  var description = ""
  let id: UUID
  var isComplete = false
}
/// Action에 더 많은 작업을 추가함에 따라 인덱스가 필요한 작업은 더 많아지고 반복될 것입니다.
/// 또한 작업을 처리할 때 마다 인덱스를 반복적으로 binding하고 state.todos에 접근하게 될 것입니다.
/// 따라서 단일 todo의 domain에만 초점을 맞춘 reducer를 작성하고,
/// 이를 todo collection에서 작동하는 reducer로 변환할 수 있다면 어떨까요?

/// todo 접두사를 지우고 인덱스를 삭제했습니다.
enum TodoAction: Equatable {
  case checkboxTapped
  /// before: todoCheckboxTapped(index: Int)
  case textFieldChanged(String)
  /// before: todoTextFieldChanged(index: Int, text: String)
}

struct TodoEnvironment {
}

/// 하나의 todo와 todoAction에 대해서만 작동하는 reducer를 정의합니다.
/// 이는 인덱스 subscript를 수행할 필요가 없음을 의미합니다.  -> state.todos[index]. ...
let todoReducer = Reducer<Todo, TodoAction, TodoEnvironment> { state, action, environment in
  switch action {
  case .checkboxTapped:
    state.isComplete.toggle()
    return .none
  case .textFieldChanged(let text):
    state.description = text
    return .none
  }
}

struct AppState: Equatable {
  var todos: [Todo] = []
}

/// 특정 인덱스에서 작동하도록 앱의 도메인을 수정합니다.
enum AppAction: Equatable {
  case addButtonTapped
  case todo(index: Int, action: TodoAction)
//  case todoCheckboxTapped(index: Int)
//  case todoTextFieldChanged(index: Int, text: String)
}

struct AppEnvironment {
}

/// 하나의 todo에 대해 작동하는 하위 todo reducer를 전체 todo collection에서 작동하는 reducer로 변환하려면
/// forEach 고차함수 reducer를 사용할 수 있습니다.
let appReducer = Reducer<AppState, AppAction, AppEnvironment>.combine(
  todoReducer.forEach(
    /// forEach Method에서는 복잡한 제네릭이 있는 3개의 인수가 있습니다. (state, action, environment)
    
                                            /// 키 경로 VS 케이스 경로
                                            /// "키 경로"를 사용하면 "구조체"에서 단일 프로퍼티를 추상적으로 분리할 수 있습니다.
                                            /// "케이스 경로"를 사용하면 "열거형"의 단일 케이스를 추상적으로 분리할 수 있습니다.
    state: \AppState.todos,                 /// state는 쓰기가능한  "키 경로"의 형태를 취합합니다.
    action: /AppAction.todo(index:action:), /// action은 "케이스 경로"의 형태로 나타냅니다.
    environment: { _ in TodoEnvironment() }
  ),
  Reducer { state, action, environment in
    switch action {
    case .addButtonTapped:
      state.todos.insert(Todo(id: UUID()), at: 0)
      return .none
    case .todo(index: let index, action: let action):
      return .none
    }
  }
)
  .debug()
  
//  Reducer<AppState, AppAction, AppEnvironment> { state, action, environment in
//  switch action {
//  case .todoCheckboxTapped(index: let index):
//    state.todos[index].isComplete.toggle()
//    return .none
//  case .todoTextFieldChanged(index: let index, text: let text):
//    state.todos[index].description = text
//    return .none
//  }
//}
//.debug()

struct ContentView: View {
  let store: Store<AppState, AppAction>
//  @ObservableObject var viewStore
  
  var body: some View {
    NavigationView {
      WithViewStore(self.store) { viewStore in
        List {
          ForEachStore(
            /// state: global -> local상태로 변환
            /// action: local -> global 상태로 변환
            /// content: 단일 todo domain으로 범위가 축소된 store를 사용
            self.store.scope(state: \.todos,
                             action: AppAction.todo(index:action:)),
            content: TodoView.init(store:)
          )
        }
        .navigationBarTitle("Todos")
        .navigationBarItems(trailing: Button("Add") {
          viewStore.send(.addButtonTapped)
        })
      }
    }
  }
}

struct TodoView: View {
  let store: Store<Todo, TodoAction>
  
  var body: some View {
    WithViewStore(self.store) { viewStore in
      HStack {
        Button(action: { viewStore.send(.checkboxTapped) }) {
          Image(systemName: viewStore.isComplete ? "checkmark.square" : "square")
        }
        .buttonStyle(PlainButtonStyle())
        
        TextField(
          "Untitled todo",
          text: viewStore.binding(
            get: \.description,
            send: TodoAction.textFieldChanged
          )
        )
      }
      .foregroundColor(viewStore.isComplete ? .gray : nil)
    }
  }
}

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
