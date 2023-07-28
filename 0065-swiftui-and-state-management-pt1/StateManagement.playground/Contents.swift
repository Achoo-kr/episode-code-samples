
import SwiftUI

struct ContentView: View {
  /// @ObservedBinding var state: AppState
  /// @ObservedBinding -> @ObservedObject
  /// Xcode 11 Beta 5이상에서는 더이상 SwiftUI의 @ObservedBinding Wrapper가 사용되지 않고,
  /// Combine FrameWork의 @ObservedObject이 사용됩니다.
  @ObservedObject var state: AppState

  var body: some View {
    /// 다른 화면으로 이동하고 싶기 때문에, 루트 뷰는 NavigationView로 설정합니다.
    NavigationView {
      /// List를 사용해 두개의 NavigationLink 요소를 순차적으로 렌더링합니다.
      List {
        /// 앱 상태를 CountView로 명시적으로 전달합니다.
        NavigationLink(destination: CounterView(state: self.state)) {
          Text("Counter demo")
        }
        NavigationLink(destination: EmptyView()) {
          Text("Favorite primes")
        }
      }
      /// NavigationView 내부의 루트 뷰에서(현재는 List) 뷰의 제목을 추가할 수 있습니다.
      .navigationBarTitle("State management")
    }
  }
}

private func ordinal(_ n: Int) -> String {
  let formatter = NumberFormatter()
  formatter.numberStyle = .ordinal
  return formatter.string(for: n) ?? ""
}

//MARK: - ObservableObject

import Combine

/// BindableObject -> ObservableObject
/// ObservableObject 프로토콜이 AnyObject를 채택했기 때문에 반드시 클래스여야 합니다.
/// 앱 상태에 대한 하나의 오래가는 데이터를 원하기 때문에 구조체로 상태의 복사값을 만들고 작업하는 것은 합리적이지 않습니다.
class AppState: ObservableObject {
  /// [1]과 [2]는 동일하며 @Published 속성 래퍼를 사용하여 [2]의 상용구를 완전히 제거할 수 있습니다.
    
  /// [1]
  @Published var count = 0
  
  /// [2]
//  var count = 0 {
//      willSet {
//          self.objectWillChange.send()
//      }
//  }
    
}

struct CounterView: View {

  @ObservedObject var state: AppState

  var body: some View {
    VStack {
      HStack {
        Button(action: { self.state.count -= 1 }) {
          Text("-")
        }
        Text("\(self.state.count)")
        Button(action: { self.state.count += 1 }) {
          Text("+")
        }
      }
      Button(action: {}) {
        Text("Is this prime?")
      }
      Button(action: {}) {
        Text("What is the \(ordinal(self.state.count)) prime?")
      }
    }
    .font(.title)
    .navigationBarTitle("Counter demo")
  }
}


//MARK: - Playground Live View
import PlaygroundSupport

/// App이 처음 인스턴스화 될 때 ContentView에 상태를 제공해줍니다.
PlaygroundPage.current.liveView = UIHostingController(
  rootView: ContentView(state: AppState())
//  rootView: CounterView()
)
