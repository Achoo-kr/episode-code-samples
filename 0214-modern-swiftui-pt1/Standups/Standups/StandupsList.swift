import SwiftUI

final class StandupsListModel: ObservableObject {
  @Published var standups: [Standup]

  init(standups: [Standup] = []) {
    self.standups = standups
  }
}

struct StandupsList: View {
  /// @StateObject는 Deep Link 및 기능 동작에 적합하지 않은 고립된 작은 섬을 생성하기 때문에 사용하지 않습니다.
  @ObservedObject var model: StandupsListModel

  var body: some View {
    NavigationStack {
      List {
        ForEach(self.model.standups) { standup in
          CardView(standup: standup)
            .listRowBackground(standup.theme.mainColor)
        }
      }
      .navigationTitle("Daily Standups")
    }
  }
}

struct CardView: View {
  let standup: Standup

  var body: some View {
    VStack(alignment: .leading) {
      Text(self.standup.title)
        .font(.headline)
      Spacer()
      HStack {
        Label("\(self.standup.attendees.count)", systemImage: "person.3")
        Spacer()
        Label(self.standup.duration.formatted(.units()), systemImage: "clock")
          .labelStyle(.trailingIcon)
      }
      .font(.caption)
    }
    .padding()
    .foregroundColor(self.standup.theme.accentColor)
  }
}

struct TrailingIconLabelStyle: LabelStyle {
  func makeBody(configuration: Configuration) -> some View {
    HStack {
      configuration.title
      configuration.icon
    }
  }
}

extension LabelStyle where Self == TrailingIconLabelStyle {
  static var trailingIcon: Self { Self() }
}


struct StandupsList_Previews: PreviewProvider {
  static var previews: some View {
    StandupsList(
      model: StandupsListModel(
        standups: [
          .mock,
        ]
      )
    )
  }
}
