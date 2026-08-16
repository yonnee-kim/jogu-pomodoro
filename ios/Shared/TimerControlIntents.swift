import ActivityKit
import AppIntents
import Foundation
import UserNotifications

/// LiveActivityIntent는 위젯 익스텐션이 아니라 앱 프로세스에서 실행된다.
/// 앱이 예약한 종료 알림(id "0")을 여기서 직접 취소/재예약할 수 있는 이유다.
/// 이 파일은 Runner와 LiveActivityExtension 양쪽 타겟에 컴파일된다
/// (위젯은 Button(intent:) 참조용, 실행은 앱 프로세스).
@available(iOS 17.0, *)
enum TimerControlHandler {
  static let appGroupId = "group.com.joguman.pomodoro"
  static let notificationId = "0"
  static let syncChangedNotification = Notification.Name("JogumanTimerControlDidChange")

  static func currentActivity() -> Activity<LiveActivitiesAppAttributes>? {
    Activity<LiveActivitiesAppAttributes>.activities.first { $0.activityState == .active }
  }

  static func pause() async {
    guard let activity = currentActivity(),
          let defaults = UserDefaults(suiteName: appGroupId) else { return }
    let prefix = activity.attributes.id
    let endMs = Double(defaults.string(forKey: "\(prefix)_endDateMs") ?? "0") ?? 0
    let remainingMs = max(0, Int(endMs - Date().timeIntervalSince1970 * 1000))
    let remainingSec = Int(ceil(Double(remainingMs) / 1000))

    // 이미 일시정지 상태에서 중복 탭 시 endDateMs가 "0"이라 remainingMs가 0으로
    // 재계산되어 남은 시간을 덮어쓴다. 저장된 남은 시간을 보존하도록 가드.
    let isPaused = defaults.string(forKey: "\(prefix)_isPaused") == "true"
    guard !isPaused, remainingMs > 0 else { return }

    UNUserNotificationCenter.current()
      .removePendingNotificationRequests(withIdentifiers: [notificationId])

    defaults.set("true", forKey: "\(prefix)_isPaused")
    defaults.set(String(remainingSec), forKey: "\(prefix)_remainingSeconds")
    defaults.set("0", forKey: "\(prefix)_endDateMs")
    writeSync(defaults, action: "pause", endDateMs: 0, remainingMs: remainingMs)

    await activity.update(ActivityContent(state: .init(appGroupId: appGroupId), staleDate: nil))
    notifyApp()
  }

  static func resume() async {
    guard let activity = currentActivity(),
          let defaults = UserDefaults(suiteName: appGroupId) else { return }
    let prefix = activity.attributes.id
    let remainingSec = Int(defaults.string(forKey: "\(prefix)_remainingSeconds") ?? "0") ?? 0
    guard remainingSec > 0 else { return }
    let endMs = Int(Date().timeIntervalSince1970 * 1000) + remainingSec * 1000

    scheduleEndNotification(defaults: defaults, prefix: prefix, secondsFromNow: remainingSec)

    defaults.set("false", forKey: "\(prefix)_isPaused")
    defaults.set("0", forKey: "\(prefix)_remainingSeconds")
    defaults.set(String(endMs), forKey: "\(prefix)_endDateMs")
    writeSync(defaults, action: "resume", endDateMs: endMs, remainingMs: 0)

    await activity.update(ActivityContent(state: .init(appGroupId: appGroupId), staleDate: nil))
    notifyApp()
  }

  static func cancel() async {
    guard let defaults = UserDefaults(suiteName: appGroupId) else { return }
    UNUserNotificationCenter.current()
      .removePendingNotificationRequests(withIdentifiers: [notificationId])
    if let activity = currentActivity() {
      await activity.end(ActivityContent(state: .init(appGroupId: appGroupId), staleDate: nil),
                         dismissalPolicy: .immediate)
    }
    writeSync(defaults, action: "cancel", endDateMs: 0, remainingMs: 0)
    notifyApp()
  }

  /// flutter_local_notifications가 예약하던 종료 알림을 동일 identifier("0")로 재예약.
  /// 제목/본문은 타이머 시작 시 Dart가 payload에 실어 둔 번역 문자열을 그대로 쓴다.
  private static func scheduleEndNotification(defaults: UserDefaults, prefix: UUID, secondsFromNow: Int) {
    let content = UNMutableNotificationContent()
    content.title = defaults.string(forKey: "\(prefix)_notifTitle") ?? "조구만 뽀모도로"
    content.body = defaults.string(forKey: "\(prefix)_notifBody") ?? ""
    content.sound = UNNotificationSound(named: UNNotificationSoundName("bip.wav"))
    content.interruptionLevel = .critical
    let trigger = UNTimeIntervalNotificationTrigger(
      timeInterval: TimeInterval(secondsFromNow), repeats: false)
    let request = UNNotificationRequest(
      identifier: notificationId, content: content, trigger: trigger)
    UNUserNotificationCenter.current().add(request)
  }

  private static func writeSync(_ defaults: UserDefaults, action: String, endDateMs: Int, remainingMs: Int) {
    defaults.set(action, forKey: "la_sync_action")
    defaults.set(String(endDateMs), forKey: "la_sync_end_date_ms")
    defaults.set(String(remainingMs), forKey: "la_sync_remaining_ms")
  }

  /// 앱이 foreground로 떠 있는 상태에서 버튼이 눌린 경우(Dynamic Island 확장 뷰 등)
  /// Flutter 엔진이 즉시 동기화하도록 같은 프로세스 안에서 핑을 보낸다.
  private static func notifyApp() {
    NotificationCenter.default.post(name: syncChangedNotification, object: nil)
  }
}

@available(iOS 17.0, *)
struct PauseTimerIntent: LiveActivityIntent {
  static var title: LocalizedStringResource = "Pause Timer"
  func perform() async throws -> some IntentResult {
    await TimerControlHandler.pause()
    return .result()
  }
}

@available(iOS 17.0, *)
struct ResumeTimerIntent: LiveActivityIntent {
  static var title: LocalizedStringResource = "Resume Timer"
  func perform() async throws -> some IntentResult {
    await TimerControlHandler.resume()
    return .result()
  }
}

@available(iOS 17.0, *)
struct CancelTimerIntent: LiveActivityIntent {
  static var title: LocalizedStringResource = "Cancel Timer"
  func perform() async throws -> some IntentResult {
    await TimerControlHandler.cancel()
    return .result()
  }
}
