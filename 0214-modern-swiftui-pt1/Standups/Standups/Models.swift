import SwiftUI
import Tagged

struct Standup: Equatable, Identifiable, Codable {
  let id: Tagged<Self, UUID> /// Tagged는 식별자 유형을 강화할 수 있는 라이브러리입니다.
                             /// 모델 유형 자체로 태그가 지정될 수 있도록 모델의 식별자를 업그레이드
  var attendees: [Attendee] = []
  var duration = Duration.seconds(60 * 5)
  var meetings: [Meeting] = []
  var theme: Theme = .bubblegum
  var title = ""

  var durationPerAttendee: Duration {
    self.duration / self.attendees.count
  }
}

struct Attendee: Equatable, Identifiable, Codable {
  let id: Tagged<Self, UUID>
  var name: String
}

struct Meeting: Equatable, Identifiable, Codable {
  let id: Tagged<Self, UUID>
  let date: Date
  var transcript: String
}

/// 각 모델의 id를 비교할 수 없게 됩니다.
/// 만약 비교하는 함수를 만든다고 했을 때 각기다른 유형의 피연산자에 적용불가하다는 컴파일러 오류가 발생합니다.
//func check(standup: Standup, attendee: Attendee) -> Bool {
//  standup.id == attendee.id
//}


enum Theme: String, CaseIterable, Equatable, Hashable, Identifiable, Codable {
  case bubblegum
  case buttercup
  case indigo
  case lavender
  case magenta
  case navy
  case orange
  case oxblood
  case periwinkle
  case poppy
  case purple
  case seafoam
  case sky
  case tan
  case teal
  case yellow

  var id: Self { self }

  var accentColor: Color {
    switch self {
    case .bubblegum, .buttercup, .lavender, .orange, .periwinkle, .poppy, .seafoam, .sky, .tan,
        .teal, .yellow:
      return .black
    case .indigo, .magenta, .navy, .oxblood, .purple:
      return .white
    }
  }

  var mainColor: Color { Color(self.rawValue) }

  var name: String { self.rawValue.capitalized }
}


extension Standup {
  static let mock = Self(
    id: Standup.ID(UUID()),
    attendees: [
      Attendee(id: Attendee.ID(UUID()), name: "Blob"),
      Attendee(id: Attendee.ID(UUID()), name: "Blob Jr"),
      Attendee(id: Attendee.ID(UUID()), name: "Blob Sr"),
      Attendee(id: Attendee.ID(UUID()), name: "Blob Esq"),
      Attendee(id: Attendee.ID(UUID()), name: "Blob III"),
      Attendee(id: Attendee.ID(UUID()), name: "Blob I"),
    ],
    duration: .seconds(60),
    meetings: [
      Meeting(
        id: Meeting.ID(UUID()),
        date: Date().addingTimeInterval(-60 * 60 * 24 * 7),
        transcript: """
          Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor \
          incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud \
          exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure \
          dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. \
          Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt \
          mollit anim id est laborum.
          """
      )
    ],
    theme: .orange,
    title: "Design"
  )
}
