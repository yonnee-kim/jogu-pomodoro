import ActivityKit
import Foundation

// live_activities 패키지 규약상 이름은 반드시 LiveActivitiesAppAttributes 여야 한다.
// ActivityKit은 타입 이름으로 활동을 매칭하므로 플러그인 내부 사본과 같은 활동을 공유한다.
@available(iOS 16.1, *)
struct LiveActivitiesAppAttributes: ActivityAttributes, Identifiable {
  public typealias LiveDeliveryData = ContentState
  public struct ContentState: Codable, Hashable {}
  var id = UUID()
}

@available(iOS 16.1, *)
extension LiveActivitiesAppAttributes {
  func prefixedKey(_ key: String) -> String {
    return "\(id)_\(key)"
  }
}
