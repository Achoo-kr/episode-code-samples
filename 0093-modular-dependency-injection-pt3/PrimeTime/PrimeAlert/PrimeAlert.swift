// CounterView에서 사용한 로직을 FavoritePrimesView에서도 사용하기 위하여 PrimeAlert 기능을 확장하여 로직 구현
public struct PrimeAlert: Equatable, Identifiable {
  public let n: Int
  public let prime: Int
  public var id: Int { self.prime }

  public init(n: Int, prime: Int) {
    self.n = n
    self.prime = prime
  }

  public var title: String {
    return "The \(ordinal(self.n)) prime is \(self.prime)"
  }
}

public func ordinal(_ n: Int) -> String {
  let formatter = NumberFormatter()
  formatter.numberStyle = .ordinal
  return formatter.string(for: n) ?? ""
}
