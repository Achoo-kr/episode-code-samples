import ComposableArchitecture
import Counter
import SwiftUI
import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
  var window: UIWindow?

  func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
    if let windowScene = scene as? UIWindowScene {
      let window = UIWindow(windowScene: windowScene)
      window.rootViewController = UIHostingController(
        rootView: ContentView(
          store: Store(
            initialValue: AppState(),
            reducer: with(
              appReducer,
              compose(
                logging,
                activityFeed
              )
            ),
            environment: AppEnvironment( // 앱 전체 수준의 Environment를 Store에 할당
              fileClient: .live,
              nthPrime: Counter.nthPrime
//              counter: .live,
//              favoritePrimes: .live
            )
          )
        )
      )
      self.window = window
      window.makeKeyAndVisible()
    }
  }
}
