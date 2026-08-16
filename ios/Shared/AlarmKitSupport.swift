import ActivityKit
import AlarmKit
import AppIntents
import Foundation
import SwiftUI

/// AlarmKit(iOS 26+) 카운트다운 경로의 메타데이터·제어 로직·위젯 버튼 인텐트.
/// TimerControlIntents와 마찬가지로 Runner와 LiveActivityExtension 양쪽 타겟에 컴파일된다
/// (LiveActivityIntent는 앱 프로세스에서 실행).
@available(iOS 26.0, *)
struct JogumanAlarmMetadata: AlarmMetadata {
  let label: String

  init(label: String = "") {
    self.label = label
  }
}

@available(iOS 26.0, *)
enum AlarmKitControlHandler {
  static let appGroupId = "group.com.joguman.pomodoro"
  static let syncChangedNotification = Notification.Name("JogumanTimerControlDidChange")

  /// 현재 권한 상태. 프롬프트를 띄우지 않는다.
  static func authState() -> String {
    switch AlarmManager.shared.authorizationState {
    case .authorized: return "authorized"
    case .denied: return "denied"
    default: return "notDetermined"
    }
  }

  /// 미결정이면 시스템 프롬프트로 권한 요청.
  static func ensureAuth() async -> Bool {
    switch AlarmManager.shared.authorizationState {
    case .authorized: return true
    case .denied: return false
    default:
      let state = try? await AlarmManager.shared.requestAuthorization()
      return state == .authorized
    }
  }

  private static var storedAlarmId: UUID? {
    guard let defaults = UserDefaults(suiteName: appGroupId),
          let raw = defaults.string(forKey: "ak_alarmId") else { return nil }
    return UUID(uuidString: raw)
  }

  /// 카운트다운 알람 예약. 같은 종료시각(±1.5초)의 알람이 이미 진행 중이면 no-op
  /// (위젯 재개 버튼 → 앱 복귀 reconcile이 재호출할 때 활동 재생성 깜빡임 방지).
  static func start(
    endDateMs: Int, label: String, alertTitle: String,
    stopLabel: String, pauseLabel: String, resumeLabel: String
  ) async -> Bool {
    guard let defaults = UserDefaults(suiteName: appGroupId) else { return false }
    let duration = (Double(endDateMs) - Date().timeIntervalSince1970 * 1000) / 1000.0
    guard duration > 0 else { return false }

    if let id = storedAlarmId,
       defaults.string(forKey: "ak_isPaused") != "true",
       let stored = Double(defaults.string(forKey: "ak_endDateMs") ?? ""),
       abs(stored - Double(endDateMs)) < 1500,
       alarmExists(id: id) {
      return true
    }

    if let id = storedAlarmId {
      try? AlarmManager.shared.stop(id: id)
      try? AlarmManager.shared.cancel(id: id)
    }

    let attributes = AlarmAttributes<JogumanAlarmMetadata>(
      presentation: AlarmPresentation(
        alert: AlarmPresentation.Alert(
          title: LocalizedStringResource(stringLiteral: alertTitle),
          stopButton: AlarmButton(
            text: LocalizedStringResource(stringLiteral: stopLabel),
            textColor: .black, systemImageName: "stop.fill")
        ),
        countdown: AlarmPresentation.Countdown(
          title: LocalizedStringResource(stringLiteral: label),
          pauseButton: AlarmButton(
            text: LocalizedStringResource(stringLiteral: pauseLabel),
            textColor: .black, systemImageName: "pause.fill")
        ),
        paused: AlarmPresentation.Paused(
          title: LocalizedStringResource(stringLiteral: label),
          resumeButton: AlarmButton(
            text: LocalizedStringResource(stringLiteral: resumeLabel),
            textColor: .black, systemImageName: "play.fill")
        )
      ),
      metadata: JogumanAlarmMetadata(label: label),
      tintColor: Color(red: 0.980, green: 0.831, blue: 0.290)  // TimerText 노랑(#FAD44A)
    )

    let id = UUID()
    do {
      // 알람 소리는 중지 전까지 파일을 루프한다 — bip 뒤 무음 5초를 붙인 파일로
      // 반복 간격을 벌린다 (알림용 원본 bip.wav와 별개, 30초 초과 시 기본음 폴백 주의)
      _ = try await AlarmManager.shared.schedule(
        id: id,
        configuration: .timer(
          duration: duration, attributes: attributes, sound: .named("bip_alarmkit.wav")))
      defaults.set(id.uuidString, forKey: "ak_alarmId")
      defaults.set(String(endDateMs), forKey: "ak_endDateMs")
      defaults.set("false", forKey: "ak_isPaused")
      defaults.set("0", forKey: "ak_remainingSeconds")
      return true
    } catch {
      NSLog("[AK] schedule 실패: \(error)")
      return false
    }
  }

  /// fromWidget이 true면 앱 복귀 시 Dart가 상태를 맞추도록 동기화 스냅샷을 남긴다.
  static func pause(fromWidget: Bool) {
    guard let defaults = UserDefaults(suiteName: appGroupId), let id = storedAlarmId else { return }
    let endMs = Double(defaults.string(forKey: "ak_endDateMs") ?? "0") ?? 0
    let remainingMs = max(0, Int(endMs - Date().timeIntervalSince1970 * 1000))
    let isPaused = defaults.string(forKey: "ak_isPaused") == "true"
    guard !isPaused, remainingMs > 0 else { return }

    try? AlarmManager.shared.pause(id: id)
    defaults.set("true", forKey: "ak_isPaused")
    defaults.set(String(Int(ceil(Double(remainingMs) / 1000))), forKey: "ak_remainingSeconds")
    defaults.set("0", forKey: "ak_endDateMs")
    if fromWidget {
      writeSync(defaults, action: "pause", endDateMs: 0, remainingMs: remainingMs)
      notifyApp()
    }
  }

  static func resume(fromWidget: Bool) {
    guard let defaults = UserDefaults(suiteName: appGroupId), let id = storedAlarmId else { return }
    let remainingSec = Int(defaults.string(forKey: "ak_remainingSeconds") ?? "0") ?? 0
    guard remainingSec > 0, defaults.string(forKey: "ak_isPaused") == "true" else { return }
    let endMs = Int(Date().timeIntervalSince1970 * 1000) + remainingSec * 1000

    try? AlarmManager.shared.resume(id: id)
    defaults.set("false", forKey: "ak_isPaused")
    defaults.set("0", forKey: "ak_remainingSeconds")
    defaults.set(String(endMs), forKey: "ak_endDateMs")
    if fromWidget {
      writeSync(defaults, action: "resume", endDateMs: endMs, remainingMs: 0)
      notifyApp()
    }
  }

  /// 알람 중지(울리는 중이면 stop, 대기 중이면 cancel — 실패는 무시하고 둘 다 시도).
  static func cancel(fromWidget: Bool) {
    guard let defaults = UserDefaults(suiteName: appGroupId) else { return }
    if let id = storedAlarmId {
      try? AlarmManager.shared.stop(id: id)
      try? AlarmManager.shared.cancel(id: id)
    }
    defaults.removeObject(forKey: "ak_alarmId")
    defaults.set("0", forKey: "ak_endDateMs")
    defaults.set("false", forKey: "ak_isPaused")
    defaults.set("0", forKey: "ak_remainingSeconds")
    if fromWidget {
      writeSync(defaults, action: "cancel", endDateMs: 0, remainingMs: 0)
      notifyApp()
    }
  }

  private static func alarmExists(id: UUID) -> Bool {
    ((try? AlarmManager.shared.alarms) ?? []).contains { $0.id == id }
  }

  private static func writeSync(
    _ defaults: UserDefaults, action: String, endDateMs: Int, remainingMs: Int
  ) {
    defaults.set(action, forKey: "la_sync_action")
    defaults.set(String(endDateMs), forKey: "la_sync_end_date_ms")
    defaults.set(String(remainingMs), forKey: "la_sync_remaining_ms")
  }

  private static func notifyApp() {
    NotificationCenter.default.post(name: syncChangedNotification, object: nil)
  }
}

@available(iOS 26.0, *)
struct AlarmKitPauseIntent: LiveActivityIntent {
  static var title: LocalizedStringResource = "Pause Timer"
  func perform() async throws -> some IntentResult {
    AlarmKitControlHandler.pause(fromWidget: true)
    return .result()
  }
}

@available(iOS 26.0, *)
struct AlarmKitResumeIntent: LiveActivityIntent {
  static var title: LocalizedStringResource = "Resume Timer"
  func perform() async throws -> some IntentResult {
    AlarmKitControlHandler.resume(fromWidget: true)
    return .result()
  }
}

@available(iOS 26.0, *)
struct AlarmKitCancelIntent: LiveActivityIntent {
  static var title: LocalizedStringResource = "Cancel Timer"
  func perform() async throws -> some IntentResult {
    AlarmKitControlHandler.cancel(fromWidget: true)
    return .result()
  }
}
