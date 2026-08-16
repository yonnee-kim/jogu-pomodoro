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
        } else if call.method == "alarmkitAvailable" {
          if #available(iOS 26.0, *) { result(true) } else { result(false) }
        } else if call.method == "alarmkitAuthState" {
          if #available(iOS 26.0, *) {
            result(AlarmKitControlHandler.authState())
          } else {
            result("unavailable")
          }
        } else if call.method == "alarmkitEnsureAuth" {
          if #available(iOS 26.0, *) {
            Task { @MainActor in result(await AlarmKitControlHandler.ensureAuth()) }
          } else {
            result(false)
          }
        } else if call.method == "alarmkitStart" {
          if #available(iOS 26.0, *) {
            let args = call.arguments as? [String: Any] ?? [:]
            Task { @MainActor in
              let ok = await AlarmKitControlHandler.start(
                endDateMs: args["endDateMs"] as? Int ?? 0,
                label: args["label"] as? String ?? "",
                alertTitle: args["alertTitle"] as? String ?? "",
                stopLabel: args["stopLabel"] as? String ?? "",
                pauseLabel: args["pauseLabel"] as? String ?? "",
                resumeLabel: args["resumeLabel"] as? String ?? "")
              result(ok)
            }
          } else {
            result(false)
          }
        } else if call.method == "alarmkitPause" {
          if #available(iOS 26.0, *) { AlarmKitControlHandler.pause(fromWidget: false) }
          result(nil)
        } else if call.method == "alarmkitCancel" {
          if #available(iOS 26.0, *) { AlarmKitControlHandler.cancel(fromWidget: false) }
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
