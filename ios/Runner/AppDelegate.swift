import ActivityKit
import Flutter
import UIKit
// import UserNotifications
// import alarm
import flutter_local_notifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var liveActivityChannel: FlutterMethodChannel?
  private static let appGroupId = "group.com.joguman.pomodoro"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // local_notification 설정
    // This is required to make any communication available in the action isolate.
    FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { (registry) in
        GeneratedPluginRegistrant.register(with: registry)
    }
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    }
    // local_notification 설정 끝
    // if #available(iOS 10.0, *) {
    //   UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
    // }
    // SwiftAlarmPlugin.registerBackgroundTasks() // alarm 설정

    GeneratedPluginRegistrant.register(with: self)

    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: "com.joguman.pomodoro/live_activity",
        binaryMessenger: controller.binaryMessenger)
      channel.setMethodCallHandler { call, result in
        if call.method == "consumeSync" {
          result(AppDelegate.consumeSyncSnapshot())
        } else if call.method == "setStaleDate" {
          let args = call.arguments as? [String: Any]
          let endDateMs = args?["endDateMs"] as? Int ?? 0
          AppDelegate.setStaleDate(endDateMs: endDateMs)
          result(nil)
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
      liveActivityChannel = channel

      NotificationCenter.default.addObserver(
        forName: Notification.Name("JogumanTimerControlDidChange"),
        object: nil, queue: .main
      ) { [weak self] _ in
        self?.liveActivityChannel?.invokeMethod("syncRequested", arguments: nil)
      }
    } else {
      NSLog("[LA] FlutterViewController 캐스트 실패 — Live Activity 채널 미설치")
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  /// 활동의 staleDate를 지정한다 (endDateMs 0 = 해제). 만료 시각에 위젯이
  /// stale로 재렌더링되어 '끝!' 표시로 전환된다. 플러그인 updateActivity는
  /// staleDate를 다루지 못해 갱신 직후 이 메서드로 보정한다.
  private static func setStaleDate(endDateMs: Int) {
    guard #available(iOS 16.2, *) else { return }
    Task {
      guard let activity = Activity<LiveActivitiesAppAttributes>.activities
        .first(where: { $0.activityState == .active }) else { return }
      let staleDate: Date? =
        endDateMs > 0 ? Date(timeIntervalSince1970: Double(endDateMs) / 1000.0) : nil
      await activity.update(
        ActivityContent(state: .init(appGroupId: appGroupId), staleDate: staleDate))
    }
  }

  private static func consumeSyncSnapshot() -> [String: String]? {
    guard let defaults = UserDefaults(suiteName: appGroupId),
          let action = defaults.string(forKey: "la_sync_action") else { return nil }
    let snapshot = [
      "action": action,
      "endDateMs": defaults.string(forKey: "la_sync_end_date_ms") ?? "0",
      "remainingMs": defaults.string(forKey: "la_sync_remaining_ms") ?? "0",
    ]
    defaults.removeObject(forKey: "la_sync_action")
    defaults.removeObject(forKey: "la_sync_end_date_ms")
    defaults.removeObject(forKey: "la_sync_remaining_ms")
    return snapshot
  }
}
