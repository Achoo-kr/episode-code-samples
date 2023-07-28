
import SwiftUI


/// API에서 반환되는 값을 모델링하는 구조체입니다.
struct WolframAlphaResult: Decodable {
  let queryresult: QueryResult

  struct QueryResult: Decodable {
    let pods: [Pod]

    struct Pod: Decodable {
      let primary: Bool?
      let subpods: [SubPod]

      struct SubPod: Decodable {
        let plaintext: String
      }
    }
  }
}


/// query: String을 받아 API로 전송하고 json Data를 구조체로 Decoding하며, 이 결과를 콜백으로 호출
func wolframAlpha(query: String, callback: @escaping (WolframAlphaResult?) -> Void) -> Void {
  var components = URLComponents(string: "https://api.wolframalpha.com/v2/query")!
  components.queryItems = [
    URLQueryItem(name: "input", value: query),
    URLQueryItem(name: "format", value: "plaintext"),
    URLQueryItem(name: "output", value: "JSON"),
    URLQueryItem(name: "appid", value: wolframAlphaApiKey),
  ]

  URLSession.shared.dataTask(with: components.url(relativeTo: nil)!) { data, response, error in
    callback(
      data
        .flatMap { try? JSONDecoder().decode(WolframAlphaResult.self, from: $0) }
    )
  }
  .resume()
}


/// wolframAlpha 함수를 통해 보다 더 구체적인 API 요청을 만들 수 있습니다.
func nthPrime(_ n: Int, callback: @escaping (Int?) -> Void) -> Void {
  wolframAlpha(query: "prime \(n)") { result in
    callback(
      result
        .flatMap {
          $0.queryresult
            .pods
            .first(where: { $0.primary == .some(true) })?
            .subpods
            .first?
            .plaintext
      }
      .flatMap(Int.init)
    )
  }
}

/// API를 활용하면 100만번 째 소수를 쿼리로 날릴 수 있습니다.
/// 이는 로컬에서 수행하기에는 계산비용이 많이 듭니다.
//nthPrime(1_000_000) { p in
//  print(p) // 15485863
//}


struct ContentView: View {
  @ObservedObject var state: AppState

  var body: some View {
    NavigationView {
      List {
        NavigationLink(destination: CounterView(state: self.state)) {
          Text("Counter demo")
        }
        NavigationLink(destination: FavoritePrimesView(state: self.state)) {
          Text("Favorite primes")
        }
      }
      .navigationBarTitle("State management")
    }
  }
}

private func ordinal(_ n: Int) -> String {
  let formatter = NumberFormatter()
  formatter.numberStyle = .ordinal
  return formatter.string(for: n) ?? ""
}

//BindableObject

import Combine

class AppState: ObservableObject {
  @Published var count = 0
  @Published var favoritePrimes: [Int] = []
}

struct PrimeAlert: Identifiable {
  let prime: Int

  var id: Int { self.prime }
}

struct CounterView: View {
  @ObservedObject var state: AppState
  @State var isPrimeModalShown: Bool = false
  @State var alertNthPrime: PrimeAlert?
  @State var isNthPrimeButtonDisabled = false

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
      Button(action: { self.isPrimeModalShown = true }) {
        Text("Is this prime?")
      }
      Button(action: self.nthPrimeButtonAction) {
        Text("What is the \(ordinal(self.state.count)) prime?")
      }
      .disabled(self.isNthPrimeButtonDisabled)
    }
    .font(.title)
    .navigationBarTitle("Counter demo")
    /// .presentation() -> .sheet로 변경되었음
    /// isPrimeModalShown의 값을 감지하고 있다가 IsPrimeModalView를 모달로 띄워줍니다.
    .sheet(isPresented: self.$isPrimeModalShown) {
      IsPrimeModalView(state: self.state)
    }
    /// alert(isPresented: content:) -> alert(item: content:)
    /// Bool값이 아닌 $alertNthPrime를 전달하기 위해 사용하고 있습니다.
    /// 값이 들어온다면 클로저가 실행되고 알람 창을 구성할 수 있습니다.
    .alert(item: self.$alertNthPrime) { alert in
      Alert(
        title: Text("The \(ordinal(self.state.count)) prime is \(alert.prime)"),
        dismissButton: .default(Text("Ok"))
      )
    }
  }
  /// 버튼이 클릭되었을 때 다음함수를 실행하게 됩니다.
  /// nthPrime의 API 호출 결과를 alertNthPrime으로 저장합니다.
  /// 이로 인해 alert의 바인딩 되고 있는 $alertNthPrime으로 데이터가 흘러들어가고 메세지창이 띄워집니다.
  func nthPrimeButtonAction() {
    self.isNthPrimeButtonDisabled = true
    nthPrime(self.state.count) { prime in
      self.alertNthPrime = prime.map(PrimeAlert.init(prime:))
      self.isNthPrimeButtonDisabled = false
    }
  }
}

private func isPrime (_ p: Int) -> Bool {
  if p <= 1 { return false }
  if p <= 3 { return true }
  for i in 2...Int(sqrtf(Float(p))) {
    if p % i == 0 { return false }
  }
  return true
}

struct IsPrimeModalView: View {
  @ObservedObject var state: AppState

  var body: some View {
    VStack {
      /// 만약 값이 소수라면은
      if isPrime(self.state.count) {
        Text("\(self.state.count) is prime 🎉")
        /// 만약 state의 favoritePrimes배열에 존재하는 소수값이라면
        if self.state.favoritePrimes.contains(self.state.count) {
          /// 존재하는 소수값을 삭제할 수 있는 action이 실행됩니다.
          Button(action: {
            self.state.favoritePrimes.removeAll(where: { $0 == self.state.count })
          }) {
            Text("Remove from favorite primes")
          }
          /// /// 만약 state의 favoritePrimes배열에 존재하는 소수값이 아니라면
        } else {
          /// 존재하는 소수값을 추가할 수 있는 action이 실행됩니다.
          Button(action: {
            self.state.favoritePrimes.append(self.state.count)
          }) {
            Text("Save to favorite primes")
          }
        }
        /// 만약 값이 소수가 아니라면은
      } else {
        Text("\(self.state.count) is not prime :(")
      }

    }
  }
}

struct FavoritePrimesView: View {
  @ObservedObject var state: AppState

  var body: some View {
    List {
      /// 기존 List 대신 목록의 모든 행을 지정할 수 있는 ForEach가 있습니다.
      /// IsPrimeModalView()에서 추가했던 모든 소수들의 목록을 보여줍니다.
      ForEach(self.state.favoritePrimes, id: \.self) { prime in
        Text("\(prime)")
      }
      /// Swipe했을 때 일치하는 값을 삭제할 수 있습니다.
      .onDelete { indexSet in
        for index in indexSet {
          self.state.favoritePrimes.remove(at: index)
        }
      }
    }
      .navigationBarTitle(Text("Favorite Primes"))
  }
}


import PlaygroundSupport

PlaygroundPage.current.liveView = UIHostingController(
  rootView: ContentView(state: AppState())
//  rootView: CounterView()
)
