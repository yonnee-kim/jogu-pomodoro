import ActivityKit
import Foundation

// live_activities 패키지 규약상 이름은 반드시 LiveActivitiesAppAttributes 여야 한다.
// ActivityKit은 타입 이름으로 활동을 매칭하므로 플러그인 내부 사본과 같은 활동을 공유한다.
@available(iOS 16.1, *)
struct LiveActivitiesAppAttributes: ActivityAttributes, Identifiable {
  public typealias LiveDeliveryData = ContentState
  // 플러그인 내부 사본은 이 필드를 필수(non-optional)로 선언한다.
  // 우리 쪽에서 빈 {}로 인코딩하면 플러그인 모듈의 디코딩이 실패해
  // Activity<LiveActivitiesAppAttributes>.activities 열거에서 활동이 누락될 수 있다(옵셔널로 방지).
  public struct ContentState: Codable, Hashable { var appGroupId: String? }
  var id = UUID()
}

@available(iOS 16.1, *)
extension LiveActivitiesAppAttributes {
  func prefixedKey(_ key: String) -> String {
    return "\(id)_\(key)"
  }
}
