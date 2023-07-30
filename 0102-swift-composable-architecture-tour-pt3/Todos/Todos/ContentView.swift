import ComposableArchitecture
import SwiftUI

struct Todo: Equatable, Identifiable {
  var description = ""
  let id: UUID
  var isComplete = false
}

enum TodoAction: Equatable {
  case checkboxTapped
  case textFieldChanged(String)
}

struct TodoEnvironment {
}

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

enum AppAction: Equatable {
  case addButtonTapped
  case todo(index: Int, action: TodoAction)
  case todoDelayCompleted
//  case todoCheckboxTapped(index: Int)
//  case todoTextFieldChanged(index: Int, text: String)
}

struct AppEnvironment {
  var uuid: () -> UUID
}

let appReducer = Reducer<AppState, AppAction, AppEnvironment>.combine(
  todoReducer.forEach(
    state: \AppState.todos,
    action: /AppAction.todo(index:action:),
    environment: { _ in TodoEnvironment() }
  ),
  Reducer { state, action, environment in
    switch action {
    case .addButtonTapped:
      state.todos.insert(Todo(id: environment.uuid()), at: 0)
      return .none
    
    /// 할일의 완료를 체크할 때 여러개의 할 일을 빠르게 완료하고 싶다면 어떨까요??
    /// 완료를 체크했을 때 즉시 맨아래로 이동한다는 점은 위의 목표달성에 방해가 되고 있습니다.
    /// 따라서 정렬이 완료되기 전 잠시 대기하도록 약간의 지연을 추가하는 방법을 제시합니다.
    case .todo(index: _, action: .checkboxTapped):
      struct CancelDelayId: Hashable {}

      /// 작업을 스토어로 다시 보냅니다.
      return Effect(value: AppAction.todoDelayCompleted)
        .delay(for: 1, scheduler: DispatchQueue.main)
        /// Effect 유형으로 지워 마무리합니다.
        .eraseToEffect()
        .cancellable(id: CancelDelayId(), cancelInFlight: true)
      
    case .todo(index: let index, action: let action):
      return .none
      
    case .todoDelayCompleted:
      
      state.todos = state.todos
        .enumerated()
        .sorted { lhs, rhs in
          (!lhs.element.isComplete && rhs.element.isComplete)
            || lhs.offset < rhs.offset
      }
      .map(\.element)
      
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
            self.store.scope(state: \.todos, action: AppAction.todo(index:action:)),
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
        environment: AppEnvironment(
          uuid: UUID.init
        )
      )
    )
  }
}
