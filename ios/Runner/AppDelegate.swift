import Flutter
import UIKit
// import UserNotifications
// import alarm
import flutter_local_notifications

@main
@objc class AppDelegate: FlutterAppDelegate {
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
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
