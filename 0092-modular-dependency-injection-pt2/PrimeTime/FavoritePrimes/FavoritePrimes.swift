import ComposableArchitecture
import SwiftUI

public enum FavoritePrimesAction: Equatable {
  case deleteFavoritePrimes(IndexSet)
  case loadButtonTapped
  case loadedFavoritePrimes([Int])
  case saveButtonTapped
}

public func favoritePrimesReducer(
  state: inout [Int],
  action: FavoritePrimesAction,
  environment: FavoritePrimesEnvironment //
) -> [Effect<FavoritePrimesAction>] {
  switch action {
  case let .deleteFavoritePrimes(indexSet):
    for index in indexSet {
      state.remove(at: index)
    }
    return [
    ]

  case let .loadedFavoritePrimes(favoritePrimes):
    state = favoritePrimes
    return []

  case .saveButtonTapped:
    return [
      environment.save("favorite-primes.json", try! JSONEncoder().encode(state))
        .fireAndForget()
//      saveEffect(favoritePrimes: state)
    ]

      // 기존에는 전역적인 종속성변수 Current를 사용했지만, 이제 reducer에 전달되는 environment에 전적으로 의존가능해졌으므로,
      // Current를 사용하지 않고, reducer에 전달된 지역적인 environment로 대체
  case .loadButtonTapped:
    return [
      environment.load("favorite-primes.json")
        .compactMap { $0 }
        .decode(type: [Int].self, decoder: JSONDecoder())
        .catch { error in Empty(completeImmediately: true) }
        .map(FavoritePrimesAction.loadedFavoritePrimes)
//        .merge(with: Just(FavoritePrimesAction.loadedFavoritePrimes([2, 31])))
        .eraseToEffect()
//      loadEffect
//        .compactMap { $0 }
//        .eraseToEffect()
    ]
  }
}

// (Never) -> A

import Combine

extension Publisher where Output == Never, Failure == Never {
  func fireAndForget<A>() -> Effect<A> {
    return self.map(absurd).eraseToEffect()
  }
}


func absurd<A>(_ never: Never) -> A {}


public struct FileClient {
  var load: (String) -> Effect<Data?>
  var save: (String, Data) -> Effect<Never>
}
extension FileClient {
  public static let live = FileClient(
    load: { fileName -> Effect<Data?> in
      .sync {
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        let documentsUrl = URL(fileURLWithPath: documentsPath)
        let favoritePrimesUrl = documentsUrl.appendingPathComponent(fileName)
        return try? Data(contentsOf: favoritePrimesUrl)
      }
  },
    save: { fileName, data in
      return .fireAndForget {
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        let documentsUrl = URL(fileURLWithPath: documentsPath)
        let favoritePrimesUrl = documentsUrl.appendingPathComponent(fileName)
        try! data.write(to: favoritePrimesUrl)
      }
  }
  )
}

// FavoritePrimes의 의존성을 구조체로 관리할 필요가 없음.
// 구조체로서의 다른 기능을 사용하지 않고 오직 래핑하는 기능만 수행하는데, 래핑할필요가 없는 수준임
//public struct FavoritePrimesEnvironment {
//  var fileClient: FileClient
//}

// 차라리 typealias 키워드를 사용하여 FileClient 구조체 자체를 FavoritePrimesEnvironment로 지칭
// 추후 여기에 의존성을 더 추가한다면 구조체가 아닌 튜플 형식으로 정의 가능
public typealias FavoritePrimesEnvironment = FileClient

//extension FavoritePrimesEnvironment {
//  public static let live = FavoritePrimesEnvironment(fileClient: .live)
//}

//var Current = FavoritePrimesEnvironment.live

// FilePrimesEnvironment는 곧 FileClient가 되었다.
// 따라서 테스트에 사용할 FileClient의 mock 데이터 생성
#if DEBUG
extension FileClient {
  static let mock = FileClient(
    load: { _ in Effect<Data?>.sync {
      try! JSONEncoder().encode([2, 31])
      } },
    save: { _, _ in .fireAndForget {} }
  )
}
#endif

//struct Environment {
//  var date: () -> Date
//}
//extension Environment {
//  static let live = Environment(date: Date.init)
//}
//
//extension Environment {
//  static let mock = Environment(date: { Date.init(timeIntervalSince1970: 1234567890) })
//}
//
////Current = .mock
//
//struct GitHubClient {
//  var fetchRepos: (@escaping (Result<[Repo], Error>) -> Void) -> Void
//
//  struct Repo: Decodable {
//    var archived: Bool
//    var description: String?
//    var htmlUrl: URL
//    var name: String
//    var pushedAt: Date?
//  }
//}
//
//#if DEBUG
//var Current = Environment.live
//#else
//let Current = Environment.live
//#endif

//private func saveEffect(favoritePrimes: [Int]) -> Effect<FavoritePrimesAction> {
//  return .fireAndForget {
////    Current.date()
//    let data = try! JSONEncoder().encode(favoritePrimes)
//    let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
//    let documentsUrl = URL(fileURLWithPath: documentsPath)
//    let favoritePrimesUrl = documentsUrl.appendingPathComponent("favorite-primes.json")
//    try! data.write(to: favoritePrimesUrl)
//  }
//}

//private let loadEffect = Effect<FavoritePrimesAction?>.sync {
//  let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
//  let documentsUrl = URL(fileURLWithPath: documentsPath)
//  let favoritePrimesUrl = documentsUrl.appendingPathComponent("favorite-primes.json")
//  guard
//    let data = try? Data(contentsOf: favoritePrimesUrl),
//    let favoritePrimes = try? JSONDecoder().decode([Int].self, from: data)
//    else { return nil }
//  return .loadedFavoritePrimes(favoritePrimes)
//}

public struct FavoritePrimesView: View {
  @ObservedObject var store: Store<[Int], FavoritePrimesAction>

  public init(store: Store<[Int], FavoritePrimesAction>) {
    self.store = store
  }

  public var body: some View {
    List {
      ForEach(self.store.value, id: \.self) { prime in
        Text("\(prime)")
      }
      .onDelete { indexSet in
        self.store.send(.deleteFavoritePrimes(indexSet))
      }
    }
    .navigationBarTitle("Favorite primes")
    .navigationBarItems(
      trailing: HStack {
        Button("Save") {
          self.store.send(.saveButtonTapped)
        }
        Button("Load") {
          self.store.send(.loadButtonTapped)
        }
      }
    )
  }
}
