# Android 잠금화면 진행형 알림 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 타이머 실행 중 Android 잠금화면·알림창에 자동 카운트다운 + 일시정지/재개/취소 버튼이 있는 진행형 알림을 띄우고, 앱 복귀 시 기존 reconcile 흐름으로 상태를 정합시킨다.

**Architecture:** iOS Live Activity 구조 미러링. Dart `LiveActivityService`가 MethodChannel(`com.joguman.pomodoro/live_activity`)로 네이티브에 start/updatePaused/end를 위임하고, 알림 버튼 탭은 BroadcastReceiver가 순수 네이티브로 완결(SharedPreferences 상태 + sync 스냅샷) → Dart는 resumed 시 `consumeSync` + 기존 `reconcileFromSync` 재사용. 카운트다운은 Chronometer(countDown)로 시스템이 자동 갱신하므로 Foreground Service 불필요.

**Tech Stack:** Flutter/Dart, Kotlin, NotificationCompat + RemoteViews, AlarmManager, SharedPreferences, flutter_local_notifications(기존), easy_localization(기존)

**Spec:** `docs/superpowers/specs/2026-08-15-android-ongoing-notification-design.md`

## Global Constraints

- 작업 디렉터리: `/Users/kim/Developer/joguman/joguman_pomodoro/.claude/worktrees/android-ongoing-notification` (워크트리, 브랜치 `worktree-android-ongoing-notification`)
- 채널명 고정: `com.joguman.pomodoro/live_activity` (iOS와 동일 — 변경 금지)
- sync 키 고정: `la_sync_action`, `la_sync_end_date_ms`, `la_sync_remaining_ms`. `consumeSync`가 Dart에 반환하는 맵 키는 `action`, `endDateMs`, `remainingMs` (home_screen.dart:123-125가 이 이름으로 파싱)
- 알림 id: 진행형 = 1001, 종료 알림 = 0 (flutter_local_notifications 예약과 동일 id → 앱의 `plugin.cancel(0)`이 함께 지움)
- minSdk 26으로 상향 (`res/font` 커스텀 폰트, Chronometer countDown, NotificationChannel 요구)
- 앱을 직접 실행(flutter run)하지 않는다 — 기기 E2E는 사용자가 수행. 검증은 `flutter analyze` / `flutter test` / `flutter build apk --debug`까지만
- Kotlin 신규 파일 패키지는 `com.joguman.pomodoro`, 위치는 기존 `android/app/src/main/kotlin/com/example/joguman_pomodoro/` (기존 디렉터리 불일치는 이번에 손대지 않음)
- 폰트 원본: `/Users/kim/Developer/joguman/joguman_pomodoro/assets/fonts/Joguman_Handwriting-Rg.ttf` (메인 체크아웃, git 미추적). 워크트리 Android 리소스로 복사해서 커밋
- 커밋 메시지 말미: `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`

### 스펙 대비 구체화 사항 (구현 중 확정)

1. **정리용 자체 알람을 항상 예약**: 앱에서 시작한 타이머가 백그라운드에서 자연 종료되면 진행형 알림이 음수 카운트다운으로 남는 문제 방지. `start` 핸들러도 자체 알람(정리 전용)을 예약하고, prefs `endNotifOwner`(`plugin`|`native`)로 종료 알림 게시 주체를 구분 — `plugin`이면 정리 Receiver는 진행형 알림 제거만 하고 종료 알림은 플러그인 예약분이 울린다. `native`(잠금화면 재개 경로)면 정리 Receiver가 종료 알림도 게시.
2. **Android 12+ 데코레이션**: 시스템이 커스텀 뷰에도 앱 아이콘·이름 헤더를 강제하므로 `DecoratedCustomViewStyle` 사용(완전 무헤더 카드는 불가 — 스펙의 "OEM별 차이" 제약에 포함).

---

### Task 1: Dart — Android payload 순수 함수 + 번역 키

**Files:**
- Modify: `lib/services/live_activity_payload.dart`
- Modify: `assets/translations/en.json`, `assets/translations/ko.json`, `assets/translations/ja.json`, `assets/translations/zh-Hans.json`, `assets/translations/zh-Hant.json`
- Test: `test/services/live_activity_payload_test.dart`

**Interfaces:**
- Consumes: 없음
- Produces: `Map<String, dynamic> buildAndroidStartPayload({required DateTime endDate, required String label, required String notifTitle, required String notifBody, required String totalLabel, required String pauseLabel, required String resumeLabel, required String cancelLabel})`, `Map<String, dynamic> buildAndroidPausedPayload({required int remainingSeconds, required String label})`, 번역 키 `la_pause`, `la_resume`, `la_cancel`, `la_minutes`

- [ ] **Step 1: 실패하는 테스트 작성** — `test/services/live_activity_payload_test.dart`의 기존 `main()` 안에 그룹 추가:

```dart
group('buildAndroidStartPayload', () {
  test('MethodChannel용 타입 그대로 담는다 (endDateMs는 int)', () {
    final payload = buildAndroidStartPayload(
      endDate: DateTime.fromMillisecondsSinceEpoch(1234567890000),
      label: '집중',
      notifTitle: '조구만 뽀모도로 타이머',
      notifBody: '끝!',
      totalLabel: '50분',
      pauseLabel: '일시정지',
      resumeLabel: '재개',
      cancelLabel: '취소',
    );
    expect(payload, {
      'endDateMs': 1234567890000,
      'label': '집중',
      'notifTitle': '조구만 뽀모도로 타이머',
      'notifBody': '끝!',
      'totalLabel': '50분',
      'pauseLabel': '일시정지',
      'resumeLabel': '재개',
      'cancelLabel': '취소',
    });
  });
});

group('buildAndroidPausedPayload', () {
  test('remainingSeconds는 int로 담는다', () {
    final payload =
        buildAndroidPausedPayload(remainingSeconds: 2700, label: '집중');
    expect(payload, {'remainingSeconds': 2700, 'label': '집중'});
  });
});
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `flutter test test/services/live_activity_payload_test.dart`
Expected: FAIL — `buildAndroidStartPayload` 미정의 컴파일 에러

- [ ] **Step 3: 구현** — `lib/services/live_activity_payload.dart` 파일 끝에 추가:

```dart
/// Android 진행형 알림 시작 페이로드 (MethodChannel 'start' 인자).
/// iOS와 달리 UserDefaults 문자열 제약이 없으므로 원 타입 그대로 전달한다.
Map<String, dynamic> buildAndroidStartPayload({
  required DateTime endDate,
  required String label,
  required String notifTitle,
  required String notifBody,
  required String totalLabel,
  required String pauseLabel,
  required String resumeLabel,
  required String cancelLabel,
}) {
  return {
    'endDateMs': endDate.millisecondsSinceEpoch,
    'label': label,
    'notifTitle': notifTitle,
    'notifBody': notifBody,
    'totalLabel': totalLabel,
    'pauseLabel': pauseLabel,
    'resumeLabel': resumeLabel,
    'cancelLabel': cancelLabel,
  };
}

/// Android 진행형 알림 일시정지 페이로드 (MethodChannel 'updatePaused' 인자).
Map<String, dynamic> buildAndroidPausedPayload({
  required int remainingSeconds,
  required String label,
}) {
  return {
    'remainingSeconds': remainingSeconds,
    'label': label,
  };
}
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `flutter test test/services/live_activity_payload_test.dart`
Expected: PASS (기존 테스트 포함 전부)

- [ ] **Step 5: 번역 키 추가** — 5개 파일 각각의 JSON 객체 끝에 키 4개 추가 (기존 키·포맷 유지, 마지막 항목 뒤 쉼표 주의):

`assets/translations/ko.json`:
```json
"la_pause" : "일시정지",
"la_resume" : "재개",
"la_cancel" : "취소",
"la_minutes" : "{}분"
```

`assets/translations/en.json`:
```json
"la_pause" : "Pause",
"la_resume" : "Resume",
"la_cancel" : "Cancel",
"la_minutes" : "{} min"
```

`assets/translations/ja.json`:
```json
"la_pause" : "一時停止",
"la_resume" : "再開",
"la_cancel" : "キャンセル",
"la_minutes" : "{}分"
```

`assets/translations/zh-Hans.json`:
```json
"la_pause" : "暂停",
"la_resume" : "继续",
"la_cancel" : "取消",
"la_minutes" : "{}分钟"
```

`assets/translations/zh-Hant.json`:
```json
"la_pause" : "暫停",
"la_resume" : "繼續",
"la_cancel" : "取消",
"la_minutes" : "{}分鐘"
```

- [ ] **Step 6: 정적 검사 + 전체 테스트**

Run: `flutter analyze && flutter test`
Expected: 이슈 0건, 전체 PASS

- [ ] **Step 7: 커밋**

```bash
git add lib/services/live_activity_payload.dart test/services/live_activity_payload_test.dart assets/translations/
git commit -m "feat: Android 진행형 알림 페이로드 순수 함수·번역 키 추가

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 2: Dart — LiveActivityService 플랫폼 분기 + DataProvider 연결

**Files:**
- Modify: `lib/services/live_activity_service.dart`
- Modify: `lib/providers/data_provider.dart:115-120` (setMyTimer의 startOrUpdateRunning 호출)

**Interfaces:**
- Consumes: Task 1의 `buildAndroidStartPayload`, `buildAndroidPausedPayload`, 번역 키 `la_*`
- Produces: 네이티브가 구현해야 할 MethodChannel 계약 — 메서드 `start`(Task 1 start payload), `updatePaused`(paused payload), `end`(인자 없음), `consumeSync`(반환 `Map{action, endDateMs, remainingMs}` 또는 null), 인바운드 `syncRequested`. `startOrUpdateRunning`에 옵셔널 파라미터 `totalLabel`, `pauseLabel`, `resumeLabel`, `cancelLabel` (String, 기본 `''`)

- [ ] **Step 1: LiveActivityService 수정** — `lib/services/live_activity_service.dart`를 다음과 같이 변경.

`init()` — iOS 전용 유지(첫 줄 가드만 명시적으로):

```dart
  Future<void> init() async {
    if (!Platform.isIOS) return; // Android는 사전 초기화 불필요(상태는 네이티브 prefs가 소유)
```
(본문 나머지 변경 없음)

`consumeSync()` — Android 허용:

```dart
  /// 네이티브(iOS Swift Intent / Android Receiver)가 남긴 동기화 스냅샷을 읽고 비운다. 없으면 null.
  Future<Map<String, String>?> consumeSync() async {
    if (!Platform.isIOS && !Platform.isAndroid) return null;
    try {
      final raw = await _syncChannel.invokeMethod<Map>('consumeSync');
      return raw?.map((k, v) => MapEntry(k.toString(), v.toString()));
    } catch (e) {
      debugPrint('[LA] consumeSync 실패: $e');
      return null;
    }
  }
```

`setNativePingListener()` — Android 허용:

```dart
  void setNativePingListener(void Function()? onPing) {
    if (!Platform.isIOS && !Platform.isAndroid) return;
    _syncChannel.setMethodCallHandler((call) async {
      if (call.method == 'syncRequested') onPing?.call();
    });
  }
```

`startOrUpdateRunning()` — Android 분기 + 파라미터 추가:

```dart
  /// 실행 중 상태로 시작(없으면 생성) 또는 갱신.
  /// totalLabel/pauseLabel/resumeLabel/cancelLabel은 Android 알림 표시용(iOS 경로에서는 무시).
  Future<void> startOrUpdateRunning({
    required DateTime endDate,
    required String label,
    required String notifTitle,
    required String notifBody,
    String totalLabel = '',
    String pauseLabel = '',
    String resumeLabel = '',
    String cancelLabel = '',
  }) async {
    if (Platform.isAndroid) {
      try {
        await _syncChannel.invokeMethod(
          'start',
          buildAndroidStartPayload(
            endDate: endDate,
            label: label,
            notifTitle: notifTitle,
            notifBody: notifBody,
            totalLabel: totalLabel,
            pauseLabel: pauseLabel,
            resumeLabel: resumeLabel,
            cancelLabel: cancelLabel,
          ),
        );
      } catch (e) {
        debugPrint('[LA] Android 알림 시작 실패: $e');
      }
      return;
    }
    if (!await _enabled()) return;
    // ... 기존 iOS 본문 그대로 ...
  }
```

`updatePaused()` — Android 분기:

```dart
  Future<void> updatePaused({
    required int remainingSeconds,
    required String label,
  }) async {
    if (Platform.isAndroid) {
      try {
        await _syncChannel.invokeMethod(
          'updatePaused',
          buildAndroidPausedPayload(
              remainingSeconds: remainingSeconds, label: label),
        );
      } catch (e) {
        debugPrint('[LA] Android 알림 일시정지 실패: $e');
      }
      return;
    }
    if (!await _enabled() || _activityId == null) return;
    // ... 기존 iOS 본문 그대로 ...
  }
```

`end()` — Android 분기:

```dart
  Future<void> end() async {
    if (Platform.isAndroid) {
      try {
        await _syncChannel.invokeMethod('end');
      } catch (e) {
        debugPrint('[LA] Android 알림 종료 실패: $e');
      }
      return;
    }
    if (!Platform.isIOS || _activityId == null) return;
    // ... 기존 iOS 본문 그대로 ...
  }
```

- [ ] **Step 2: DataProvider 호출부에 라벨 전달** — `lib/providers/data_provider.dart` `setMyTimer()`의 `startOrUpdateRunning` 호출을 다음으로 교체:

```dart
      LiveActivityService.instance.startOrUpdateRunning(
        endDate: alarmDate,
        label: 'live_activity_title'.tr(),
        notifTitle: 'app_name'.tr(),
        notifBody: 'end_message'.tr(),
        totalLabel:
            'la_minutes'.tr(args: [(startSec / 60).round().toString()]),
        pauseLabel: 'la_pause'.tr(),
        resumeLabel: 'la_resume'.tr(),
        cancelLabel: 'la_cancel'.tr(),
      );
```

- [ ] **Step 3: 정적 검사 + 전체 테스트**

Run: `flutter analyze && flutter test`
Expected: 이슈 0건, 전체 PASS (플랫폼 분기는 `Platform.isAndroid` 기반이라 단위 테스트 불가 — 순수 함수는 Task 1에서 커버됨)

- [ ] **Step 4: 커밋**

```bash
git add lib/services/live_activity_service.dart lib/providers/data_provider.dart
git commit -m "feat: LiveActivityService Android MethodChannel 분기 추가

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 3: Android 리소스 — minSdk·권한·폰트·레이아웃

**Files:**
- Modify: `android/app/build.gradle.kts:37` (minSdk)
- Modify: `android/app/src/main/AndroidManifest.xml:11` (POST_NOTIFICATIONS 주석 해제)
- Create: `android/app/src/main/res/font/joguman_handwriting.ttf` (복사)
- Create: `android/app/src/main/res/drawable/bg_timer_notification.xml`
- Create: `android/app/src/main/res/layout/notification_timer_collapsed.xml`
- Create: `android/app/src/main/res/layout/notification_timer_expanded.xml`

**Interfaces:**
- Consumes: 없음
- Produces: 뷰 id — `@id/timer_icon`, `@id/timer_chrono`(Chronometer), `@id/timer_paused_text`, `@id/timer_subtext`, `@id/btn_cancel`, `@id/btn_toggle`(expanded 전용). Task 4가 이 id로 RemoteViews를 조작

- [ ] **Step 1: minSdk 상향** — `android/app/build.gradle.kts`의 `minSdk = flutter.minSdkVersion`을 교체:

```kotlin
        minSdk = maxOf(flutter.minSdkVersion, 26) // res/font·Chronometer countDown·NotificationChannel 요구
```

- [ ] **Step 2: POST_NOTIFICATIONS 활성화** — `AndroidManifest.xml`에서 주석 해제:

```xml
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
```

- [ ] **Step 3: 폰트 복사**

```bash
mkdir -p android/app/src/main/res/font
cp /Users/kim/Developer/joguman/joguman_pomodoro/assets/fonts/Joguman_Handwriting-Rg.ttf android/app/src/main/res/font/joguman_handwriting.ttf
```

- [ ] **Step 4: 배경 drawable 작성** — `android/app/src/main/res/drawable/bg_timer_notification.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android"
    android:shape="rectangle">
    <solid android:color="#F7F3EA" />
    <corners android:radius="16dp" />
</shape>
```

- [ ] **Step 5: 확장 레이아웃 작성** — `android/app/src/main/res/layout/notification_timer_expanded.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:layout_width="match_parent"
    android:layout_height="wrap_content"
    android:orientation="vertical"
    android:background="@drawable/bg_timer_notification"
    android:padding="12dp">

    <LinearLayout
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:orientation="horizontal"
        android:gravity="center_vertical">

        <ImageView
            android:id="@+id/timer_icon"
            android:layout_width="40dp"
            android:layout_height="40dp"
            android:src="@mipmap/ic_launcher"
            android:contentDescription="@string/app_name" />

        <LinearLayout
            android:layout_width="0dp"
            android:layout_height="wrap_content"
            android:layout_weight="1"
            android:layout_marginStart="12dp"
            android:orientation="vertical">

            <Chronometer
                android:id="@+id/timer_chrono"
                android:layout_width="wrap_content"
                android:layout_height="wrap_content"
                android:countDown="true"
                android:fontFamily="@font/joguman_handwriting"
                android:textColor="#1F1B16"
                android:textSize="28sp" />

            <TextView
                android:id="@+id/timer_paused_text"
                android:layout_width="wrap_content"
                android:layout_height="wrap_content"
                android:visibility="gone"
                android:fontFamily="@font/joguman_handwriting"
                android:textColor="#1F1B16"
                android:textSize="28sp" />

            <TextView
                android:id="@+id/timer_subtext"
                android:layout_width="wrap_content"
                android:layout_height="wrap_content"
                android:fontFamily="@font/joguman_handwriting"
                android:textColor="#8A857C"
                android:textSize="13sp" />
        </LinearLayout>
    </LinearLayout>

    <View
        android:layout_width="match_parent"
        android:layout_height="1dp"
        android:layout_marginTop="10dp"
        android:background="#E5E0D5" />

    <LinearLayout
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:orientation="horizontal">

        <TextView
            android:id="@+id/btn_cancel"
            android:layout_width="0dp"
            android:layout_height="wrap_content"
            android:layout_weight="1"
            android:gravity="center"
            android:paddingVertical="10dp"
            android:fontFamily="@font/joguman_handwriting"
            android:textColor="#1F1B16"
            android:textSize="15sp" />

        <View
            android:layout_width="1dp"
            android:layout_height="match_parent"
            android:background="#E5E0D5" />

        <TextView
            android:id="@+id/btn_toggle"
            android:layout_width="0dp"
            android:layout_height="wrap_content"
            android:layout_weight="1"
            android:gravity="center"
            android:paddingVertical="10dp"
            android:fontFamily="@font/joguman_handwriting"
            android:textColor="#1F1B16"
            android:textSize="15sp" />
    </LinearLayout>
</LinearLayout>
```

- [ ] **Step 6: 축소 레이아웃 작성** — `android/app/src/main/res/layout/notification_timer_collapsed.xml` (확장 레이아웃의 상단 행만, 버튼·구분선 없음):

```xml
<?xml version="1.0" encoding="utf-8"?>
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:layout_width="match_parent"
    android:layout_height="wrap_content"
    android:orientation="horizontal"
    android:gravity="center_vertical"
    android:background="@drawable/bg_timer_notification"
    android:padding="10dp">

    <ImageView
        android:id="@+id/timer_icon"
        android:layout_width="32dp"
        android:layout_height="32dp"
        android:src="@mipmap/ic_launcher"
        android:contentDescription="@string/app_name" />

    <Chronometer
        android:id="@+id/timer_chrono"
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:layout_marginStart="10dp"
        android:countDown="true"
        android:fontFamily="@font/joguman_handwriting"
        android:textColor="#1F1B16"
        android:textSize="20sp" />

    <TextView
        android:id="@+id/timer_paused_text"
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:layout_marginStart="10dp"
        android:visibility="gone"
        android:fontFamily="@font/joguman_handwriting"
        android:textColor="#1F1B16"
        android:textSize="20sp" />

    <TextView
        android:id="@+id/timer_subtext"
        android:layout_width="0dp"
        android:layout_height="wrap_content"
        android:layout_weight="1"
        android:layout_marginStart="10dp"
        android:gravity="end"
        android:fontFamily="@font/joguman_handwriting"
        android:textColor="#8A857C"
        android:textSize="12sp" />
</LinearLayout>
```

- [ ] **Step 7: 커밋** (빌드 검증은 Kotlin이 채워지는 Task 6에서 일괄 — 리소스 단독으론 컴파일 대상 없음)

```bash
git add android/app/build.gradle.kts android/app/src/main/AndroidManifest.xml android/app/src/main/res/font/ android/app/src/main/res/drawable/bg_timer_notification.xml android/app/src/main/res/layout/
git commit -m "feat: Android 진행형 알림 리소스(폰트·레이아웃·권한) 추가

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 4: Kotlin — TimerPrefs + TimerNotificationManager + TimerAlarm

**Files:**
- Create: `android/app/src/main/kotlin/com/example/joguman_pomodoro/TimerPrefs.kt`
- Create: `android/app/src/main/kotlin/com/example/joguman_pomodoro/TimerNotificationManager.kt`
- Create: `android/app/src/main/kotlin/com/example/joguman_pomodoro/TimerAlarm.kt`

**Interfaces:**
- Consumes: Task 3의 레이아웃/뷰 id, `R.font.joguman_handwriting`(레이아웃 경유), `R.raw.bip`
- Produces:
  - `TimerPrefs.get(context): SharedPreferences` + 키 상수(`KEY_STATE`, `KEY_END_DATE_MS`, `KEY_REMAINING_MS`, `KEY_TOTAL_LABEL`, `KEY_NOTIF_TITLE`, `KEY_NOTIF_BODY`, `KEY_PAUSE_LABEL`, `KEY_RESUME_LABEL`, `KEY_CANCEL_LABEL`, `KEY_END_NOTIF_OWNER`, `KEY_SYNC_ACTION`, `KEY_SYNC_END_DATE_MS`, `KEY_SYNC_REMAINING_MS`)
  - `TimerNotificationManager.showRunning(context, endDateMs: Long)` / `showPaused(context, remainingMs: Long)` / `cancelOngoing(context)` / `showFinished(context)`
  - `TimerAlarm.schedule(context, triggerAtMs: Long)` / `cancel(context)`
  - `TimerActionReceiver`/`TimerFinishReceiver`(Task 5)가 위 전부를 사용

- [ ] **Step 1: TimerPrefs.kt 작성**

```kotlin
package com.joguman.pomodoro

import android.content.Context
import android.content.SharedPreferences

/// 진행형 알림의 단일 진실 저장소. 앱 프로세스가 죽어도 Receiver가 이 값으로 동작한다.
object TimerPrefs {
    private const val FILE = "joguman_timer_notification"

    const val KEY_STATE = "state" // "running" | "paused" | ""(비활성)
    const val KEY_END_DATE_MS = "endDateMs"
    const val KEY_REMAINING_MS = "remainingMs"
    const val KEY_TOTAL_LABEL = "totalLabel"
    const val KEY_NOTIF_TITLE = "notifTitle"
    const val KEY_NOTIF_BODY = "notifBody"
    const val KEY_PAUSE_LABEL = "pauseLabel"
    const val KEY_RESUME_LABEL = "resumeLabel"
    const val KEY_CANCEL_LABEL = "cancelLabel"

    // 종료 알림 게시 주체: "plugin"(Dart 예약분이 울림) | "native"(TimerFinishReceiver가 게시)
    const val KEY_END_NOTIF_OWNER = "endNotifOwner"

    // Dart consumeSync가 소비하는 1회성 스냅샷 (iOS App Group 키와 동일 규약)
    const val KEY_SYNC_ACTION = "la_sync_action"
    const val KEY_SYNC_END_DATE_MS = "la_sync_end_date_ms"
    const val KEY_SYNC_REMAINING_MS = "la_sync_remaining_ms"

    fun get(context: Context): SharedPreferences =
        context.getSharedPreferences(FILE, Context.MODE_PRIVATE)
}
```

- [ ] **Step 2: TimerAlarm.kt 작성**

```kotlin
package com.joguman.pomodoro

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build

/// 네이티브 소유의 종료 시각 알람. 진행형 알림 정리와(재개 경로에선) 종료 알림 게시를 담당.
/// 플러그인 알람(id 0)은 Dart 소유 — 여기서 건드리지 않는다.
object TimerAlarm {
    private const val REQUEST_CODE = 1002

    private fun pending(context: Context): PendingIntent =
        PendingIntent.getBroadcast(
            context,
            REQUEST_CODE,
            Intent(context, TimerFinishReceiver::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

    fun schedule(context: Context, triggerAtMs: Long) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        if (Build.VERSION.SDK_INT >= 31 && !am.canScheduleExactAlarms()) {
            am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMs, pending(context))
        } else {
            am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMs, pending(context))
        }
    }

    fun cancel(context: Context) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        am.cancel(pending(context))
    }
}
```

- [ ] **Step 3: TimerNotificationManager.kt 작성**

```kotlin
package com.joguman.pomodoro

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.net.Uri
import android.os.SystemClock
import android.view.View
import android.widget.RemoteViews
import androidx.core.app.NotificationCompat
import java.text.DateFormat
import java.util.Date

object TimerNotificationManager {
    const val ONGOING_NOTIFICATION_ID = 1001
    const val END_NOTIFICATION_ID = 0 // flutter_local_notifications 예약 알림과 동일 id
    private const val ONGOING_CHANNEL_ID = "timer_ongoing"
    private const val END_CHANNEL_ID = "end_alarm" // 플러그인이 만드는 채널과 동일 id 재사용

    fun showRunning(context: Context, endDateMs: Long) {
        notify(context, buildOngoing(context, running = true, endDateMs = endDateMs, remainingMs = 0))
    }

    fun showPaused(context: Context, remainingMs: Long) {
        notify(context, buildOngoing(context, running = false, endDateMs = 0, remainingMs = remainingMs))
    }

    fun cancelOngoing(context: Context) {
        manager(context).cancel(ONGOING_NOTIFICATION_ID)
    }

    /// 재개 경로(endNotifOwner=native)에서 TimerFinishReceiver가 호출하는 종료 알림.
    fun showFinished(context: Context) {
        val prefs = TimerPrefs.get(context)
        ensureEndChannel(context)
        val notification = NotificationCompat.Builder(context, END_CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(prefs.getString(TimerPrefs.KEY_NOTIF_TITLE, "") ?: "")
            .setContentText(prefs.getString(TimerPrefs.KEY_NOTIF_BODY, "") ?: "")
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setAutoCancel(true)
            .setContentIntent(launchAppIntent(context))
            .build()
        manager(context).notify(END_NOTIFICATION_ID, notification)
    }

    private fun notify(context: Context, notification: Notification) {
        ensureOngoingChannel(context)
        try {
            manager(context).notify(ONGOING_NOTIFICATION_ID, notification)
        } catch (_: SecurityException) {
            // POST_NOTIFICATIONS 미허용(Android 13+) — 알림 없이 타이머만 동작
        }
    }

    private fun buildOngoing(
        context: Context,
        running: Boolean,
        endDateMs: Long,
        remainingMs: Long,
    ): Notification {
        return NotificationCompat.Builder(context, ONGOING_CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setShowWhen(false)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setCategory(NotificationCompat.CATEGORY_PROGRESS)
            .setStyle(NotificationCompat.DecoratedCustomViewStyle())
            .setCustomContentView(buildViews(context, R.layout.notification_timer_collapsed, running, endDateMs, remainingMs, withButtons = false))
            .setCustomBigContentView(buildViews(context, R.layout.notification_timer_expanded, running, endDateMs, remainingMs, withButtons = true))
            .setContentIntent(launchAppIntent(context))
            .build()
    }

    private fun buildViews(
        context: Context,
        layoutId: Int,
        running: Boolean,
        endDateMs: Long,
        remainingMs: Long,
        withButtons: Boolean,
    ): RemoteViews {
        val prefs = TimerPrefs.get(context)
        val views = RemoteViews(context.packageName, layoutId)
        val totalLabel = prefs.getString(TimerPrefs.KEY_TOTAL_LABEL, "") ?: ""
        if (running) {
            views.setViewVisibility(R.id.timer_chrono, View.VISIBLE)
            views.setViewVisibility(R.id.timer_paused_text, View.GONE)
            views.setChronometerCountDown(R.id.timer_chrono, true)
            views.setChronometer(
                R.id.timer_chrono,
                SystemClock.elapsedRealtime() + (endDateMs - System.currentTimeMillis()),
                null,
                true,
            )
            val endTime = DateFormat.getTimeInstance(DateFormat.SHORT).format(Date(endDateMs))
            views.setTextViewText(R.id.timer_subtext, "$totalLabel / $endTime")
        } else {
            views.setViewVisibility(R.id.timer_chrono, View.GONE)
            views.setViewVisibility(R.id.timer_paused_text, View.VISIBLE)
            views.setTextViewText(R.id.timer_paused_text, formatMmSs(remainingMs))
            views.setTextViewText(R.id.timer_subtext, totalLabel)
        }
        if (withButtons) {
            views.setTextViewText(
                R.id.btn_cancel, prefs.getString(TimerPrefs.KEY_CANCEL_LABEL, "") ?: "")
            views.setOnClickPendingIntent(
                R.id.btn_cancel,
                TimerActionReceiver.pendingBroadcast(context, TimerActionReceiver.ACTION_CANCEL, 2),
            )
            if (running) {
                views.setTextViewText(
                    R.id.btn_toggle, prefs.getString(TimerPrefs.KEY_PAUSE_LABEL, "") ?: "")
                views.setOnClickPendingIntent(
                    R.id.btn_toggle,
                    TimerActionReceiver.pendingBroadcast(context, TimerActionReceiver.ACTION_PAUSE, 3),
                )
            } else {
                views.setTextViewText(
                    R.id.btn_toggle, prefs.getString(TimerPrefs.KEY_RESUME_LABEL, "") ?: "")
                views.setOnClickPendingIntent(
                    R.id.btn_toggle,
                    TimerActionReceiver.pendingBroadcast(context, TimerActionReceiver.ACTION_RESUME, 3),
                )
            }
        }
        return views
    }

    private fun formatMmSs(remainingMs: Long): String {
        val totalSec = (remainingMs + 999) / 1000 // 올림 — Dart의 (ms/1000).ceil()과 동일
        return "%02d:%02d".format(totalSec / 60, totalSec % 60)
    }

    private fun launchAppIntent(context: Context): PendingIntent {
        val intent = context.packageManager.getLaunchIntentForPackage(context.packageName)
        return PendingIntent.getActivity(
            context, 1, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    }

    private fun ensureOngoingChannel(context: Context) {
        val channel = NotificationChannel(
            ONGOING_CHANNEL_ID, "Timer", NotificationManager.IMPORTANCE_LOW,
        ).apply {
            setSound(null, null)
            enableVibration(false)
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            setShowBadge(false)
        }
        manager(context).createNotificationChannel(channel) // 이미 있으면 no-op
    }

    /// 플러그인(end_alarm 채널)이 아직 채널을 안 만들었을 때를 대비해 동일 규약으로 생성.
    private fun ensureEndChannel(context: Context) {
        val channel = NotificationChannel(
            END_CHANNEL_ID, "alarm", NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            setSound(
                Uri.parse("android.resource://${context.packageName}/raw/bip"),
                AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_ALARM).build(),
            )
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            setShowBadge(false)
        }
        manager(context).createNotificationChannel(channel)
    }

    private fun manager(context: Context): NotificationManager =
        context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
}
```

- [ ] **Step 4: 커밋** (컴파일 검증은 Task 5에서 Receiver까지 갖춰진 뒤 — 이 파일은 Task 5의 `TimerActionReceiver`/`TimerFinishReceiver`를 참조하므로 여기서는 커밋만 하고 빌드는 미루지 않으면 실패한다. Task 4와 5를 같은 세션에서 연달아 작업하는 경우 커밋을 Task 5와 합쳐도 된다)

```bash
git add android/app/src/main/kotlin/
git commit -m "feat: Android 진행형 알림 매니저·prefs·알람 헬퍼 추가

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 5: Kotlin — TimerActionReceiver + TimerFinishReceiver + 매니페스트

**Files:**
- Create: `android/app/src/main/kotlin/com/example/joguman_pomodoro/TimerActionReceiver.kt`
- Create: `android/app/src/main/kotlin/com/example/joguman_pomodoro/TimerFinishReceiver.kt`
- Modify: `android/app/src/main/AndroidManifest.xml` (receiver 2개 등록)

**Interfaces:**
- Consumes: Task 4 전부 (`TimerPrefs`, `TimerNotificationManager`, `TimerAlarm`)
- Produces: `TimerActionReceiver.ACTION_PAUSE/ACTION_RESUME/ACTION_CANCEL` 상수, `TimerActionReceiver.pendingBroadcast(context, action: String, requestCode: Int): PendingIntent`, `MainActivity.pingSync()` 호출(Task 6에서 정의 — Task 5 시점에는 컴파일을 위해 Task 6과 연달아 작업)

- [ ] **Step 1: TimerActionReceiver.kt 작성**

```kotlin
package com.joguman.pomodoro

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/// 알림 버튼 탭을 순수 네이티브로 완결한다(iOS AppIntent와 동일 역할).
/// 앱 프로세스·Flutter 엔진이 없어도 동작하며, Dart는 resumed 시 sync 스냅샷으로 정합을 맞춘다.
class TimerActionReceiver : BroadcastReceiver() {
    companion object {
        const val ACTION_PAUSE = "com.joguman.pomodoro.TIMER_PAUSE"
        const val ACTION_RESUME = "com.joguman.pomodoro.TIMER_RESUME"
        const val ACTION_CANCEL = "com.joguman.pomodoro.TIMER_CANCEL"

        fun pendingBroadcast(context: Context, action: String, requestCode: Int): PendingIntent =
            PendingIntent.getBroadcast(
                context,
                requestCode,
                Intent(context, TimerActionReceiver::class.java).setAction(action),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
    }

    override fun onReceive(context: Context, intent: Intent) {
        val prefs = TimerPrefs.get(context)
        val state = prefs.getString(TimerPrefs.KEY_STATE, "") ?: ""
        val now = System.currentTimeMillis()
        when (intent.action) {
            ACTION_PAUSE -> {
                val endMs = prefs.getLong(TimerPrefs.KEY_END_DATE_MS, 0)
                if (state != "running" || endMs <= now) return // 중복 탭·만료 가드
                val remaining = endMs - now
                prefs.edit()
                    .putString(TimerPrefs.KEY_STATE, "paused")
                    .putLong(TimerPrefs.KEY_REMAINING_MS, remaining)
                    .putLong(TimerPrefs.KEY_END_DATE_MS, 0)
                    .putString(TimerPrefs.KEY_SYNC_ACTION, "pause")
                    .putLong(TimerPrefs.KEY_SYNC_REMAINING_MS, remaining)
                    .apply()
                cancelPluginAlarm(context) // 앱 밖 시점 — 예외적으로 플러그인 알람을 네이티브가 취소
                TimerAlarm.cancel(context)
                TimerNotificationManager.showPaused(context, remaining)
                MainActivity.pingSync()
            }
            ACTION_RESUME -> {
                val remaining = prefs.getLong(TimerPrefs.KEY_REMAINING_MS, 0)
                if (state != "paused" || remaining <= 0) return
                val endMs = now + remaining
                prefs.edit()
                    .putString(TimerPrefs.KEY_STATE, "running")
                    .putLong(TimerPrefs.KEY_END_DATE_MS, endMs)
                    .putLong(TimerPrefs.KEY_REMAINING_MS, 0)
                    .putString(TimerPrefs.KEY_END_NOTIF_OWNER, "native")
                    .putString(TimerPrefs.KEY_SYNC_ACTION, "resume")
                    .putLong(TimerPrefs.KEY_SYNC_END_DATE_MS, endMs)
                    .apply()
                TimerAlarm.schedule(context, endMs)
                TimerNotificationManager.showRunning(context, endMs)
                MainActivity.pingSync()
            }
            ACTION_CANCEL -> {
                if (state.isEmpty()) return
                prefs.edit()
                    .putString(TimerPrefs.KEY_STATE, "")
                    .putString(TimerPrefs.KEY_SYNC_ACTION, "cancel")
                    .apply()
                cancelPluginAlarm(context)
                TimerAlarm.cancel(context)
                TimerNotificationManager.cancelOngoing(context)
                MainActivity.pingSync()
            }
        }
    }

    /// flutter_local_notifications가 예약한 종료 알람(id 0) 취소.
    /// 취소는 component+requestCode 매칭만 필요해 플러그인 내부 페이로드에 의존하지 않는다.
    private fun cancelPluginAlarm(context: Context) {
        val intent = Intent(
            context,
            com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver::class.java,
        )
        val pi = PendingIntent.getBroadcast(
            context, 0, intent,
            PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE,
        ) ?: return
        (context.getSystemService(Context.ALARM_SERVICE) as AlarmManager).cancel(pi)
        pi.cancel()
    }
}
```

- [ ] **Step 2: TimerFinishReceiver.kt 작성**

```kotlin
package com.joguman.pomodoro

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/// 네이티브 알람이 종료 시각에 발화 — 진행형 알림을 정리하고,
/// 잠금화면 재개 경로(endNotifOwner=native)라면 종료 알림도 게시한다.
/// sync 키는 지우지 않는다: 미소비 resume 스냅샷은 Dart가 finishedAway로 해석해야 한다.
class TimerFinishReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val prefs = TimerPrefs.get(context)
        if ((prefs.getString(TimerPrefs.KEY_STATE, "") ?: "") != "running") return
        TimerNotificationManager.cancelOngoing(context)
        if (prefs.getString(TimerPrefs.KEY_END_NOTIF_OWNER, "") == "native") {
            TimerNotificationManager.showFinished(context)
        }
        prefs.edit().putString(TimerPrefs.KEY_STATE, "").apply()
    }
}
```

- [ ] **Step 3: 매니페스트에 Receiver 등록** — `AndroidManifest.xml`의 기존 `ScheduledNotificationBootReceiver` 블록 아래에 추가:

```xml
        <!-- 진행형 타이머 알림 -->
        <receiver android:exported="false" android:name=".TimerActionReceiver" />
        <receiver android:exported="false" android:name=".TimerFinishReceiver" />
```

- [ ] **Step 4: 커밋**

```bash
git add android/app/src/main/kotlin/ android/app/src/main/AndroidManifest.xml
git commit -m "feat: 진행형 알림 버튼·종료 Receiver 추가

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 6: Kotlin — MainActivity MethodChannel + 빌드 검증

**Files:**
- Modify: `android/app/src/main/kotlin/com/example/joguman_pomodoro/MainActivity.kt` (전체 교체)

**Interfaces:**
- Consumes: Task 4·5 전부, Task 2가 정의한 채널 계약
- Produces: `MainActivity.pingSync()` (Task 5의 Receiver가 호출), MethodChannel `com.joguman.pomodoro/live_activity` 핸들러(`start`/`updatePaused`/`end`/`consumeSync`)

- [ ] **Step 1: MainActivity.kt 전체 교체**

```kotlin
package com.joguman.pomodoro

import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private var channel: MethodChannel? = null

        /// Receiver가 상태를 바꿨을 때 포그라운드 Dart에 알리는 핑(iOS NotificationCenter 옵저버 역할).
        /// 액티비티(엔진)가 없으면 no-op — resumed 시 consumeSync가 처리한다.
        fun pingSync() {
            Handler(Looper.getMainLooper()).post {
                channel?.invokeMethod("syncRequested", null)
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val ch = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.joguman.pomodoro/live_activity",
        )
        channel = ch
        ch.setMethodCallHandler { call, result ->
            val prefs = TimerPrefs.get(this)
            when (call.method) {
                "start" -> {
                    val endDateMs = call.argument<Number>("endDateMs")?.toLong()
                    if (endDateMs == null) {
                        result.error("BAD_ARGS", "endDateMs 누락", null)
                        return@setMethodCallHandler
                    }
                    prefs.edit()
                        .putString(TimerPrefs.KEY_STATE, "running")
                        .putLong(TimerPrefs.KEY_END_DATE_MS, endDateMs)
                        .putLong(TimerPrefs.KEY_REMAINING_MS, 0)
                        .putString(TimerPrefs.KEY_TOTAL_LABEL, call.argument("totalLabel") ?: "")
                        .putString(TimerPrefs.KEY_NOTIF_TITLE, call.argument("notifTitle") ?: "")
                        .putString(TimerPrefs.KEY_NOTIF_BODY, call.argument("notifBody") ?: "")
                        .putString(TimerPrefs.KEY_PAUSE_LABEL, call.argument("pauseLabel") ?: "")
                        .putString(TimerPrefs.KEY_RESUME_LABEL, call.argument("resumeLabel") ?: "")
                        .putString(TimerPrefs.KEY_CANCEL_LABEL, call.argument("cancelLabel") ?: "")
                        .putString(TimerPrefs.KEY_END_NOTIF_OWNER, "plugin") // 종료 알림은 Dart 예약분
                        .apply()
                    // 자체 알람은 진행형 알림 정리용으로 항상 예약(플러그인 알람은 Dart 소유 — 불가침)
                    TimerAlarm.cancel(this)
                    TimerAlarm.schedule(this, endDateMs)
                    TimerNotificationManager.showRunning(this, endDateMs)
                    result.success(null)
                }
                "updatePaused" -> {
                    val remainingSeconds = call.argument<Number>("remainingSeconds")?.toLong() ?: 0
                    val remainingMs = remainingSeconds * 1000
                    prefs.edit()
                        .putString(TimerPrefs.KEY_STATE, "paused")
                        .putLong(TimerPrefs.KEY_REMAINING_MS, remainingMs)
                        .putLong(TimerPrefs.KEY_END_DATE_MS, 0)
                        .apply()
                    TimerAlarm.cancel(this)
                    TimerNotificationManager.showPaused(this, remainingMs)
                    result.success(null)
                }
                "end" -> {
                    TimerAlarm.cancel(this)
                    TimerNotificationManager.cancelOngoing(this)
                    prefs.edit().putString(TimerPrefs.KEY_STATE, "").apply()
                    result.success(null)
                }
                "consumeSync" -> {
                    val action = prefs.getString(TimerPrefs.KEY_SYNC_ACTION, null)
                    if (action.isNullOrEmpty()) {
                        result.success(null)
                    } else {
                        val snapshot = mapOf(
                            "action" to action,
                            "endDateMs" to prefs.getLong(TimerPrefs.KEY_SYNC_END_DATE_MS, 0).toString(),
                            "remainingMs" to prefs.getLong(TimerPrefs.KEY_SYNC_REMAINING_MS, 0).toString(),
                        )
                        prefs.edit()
                            .remove(TimerPrefs.KEY_SYNC_ACTION)
                            .remove(TimerPrefs.KEY_SYNC_END_DATE_MS)
                            .remove(TimerPrefs.KEY_SYNC_REMAINING_MS)
                            .apply()
                        result.success(snapshot)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        channel = null
        super.onDestroy()
    }
}
```

- [ ] **Step 2: 디버그 빌드로 Kotlin·리소스 전체 검증**

Run: `flutter build apk --debug`
Expected: 성공(BUILD SUCCESSFUL). 실패 시 컴파일 에러를 고치고 재실행 — 알려진 가능성 두 가지:
- `com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver` 참조(Task 5)가 클래스패스에 없음 → `flutter pub get` 후 재시도
- `androidx.core.app.NotificationCompat` 미해결 → `android/app/build.gradle.kts`의 `dependencies`에 `implementation("androidx.core:core-ktx:1.13.1")` 추가

- [ ] **Step 3: Dart 전체 재검증**

Run: `flutter analyze && flutter test`
Expected: 이슈 0건, 전체 PASS

- [ ] **Step 4: 커밋**

```bash
git add android/app/src/main/kotlin/
git commit -m "feat: MainActivity에 진행형 알림 MethodChannel 핸들러 연결

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 7: 마무리 — 수동 E2E 체크리스트 정리

**Files:**
- Create: `_docs/version-update-note/next-android-ongoing-notification.md` (사용자 검증용 체크리스트)

**Interfaces:**
- Consumes: 전체 구현
- Produces: 사용자가 기기에서 확인할 시나리오 목록

- [ ] **Step 1: 체크리스트 작성**

```markdown
# Android 진행형 알림 수동 검증 체크리스트

빌드: `flutter run` (Android 실기기 권장 — 잠금화면·알람 동작은 에뮬레이터와 다를 수 있음)

## 기본 흐름
- [ ] 타이머 시작 → 알림창·잠금화면에 카운트다운 알림 표시(매초 자동 갱신)
- [ ] 서브텍스트 "N분 / 종료시각" 표시, 손글씨 폰트 적용 여부(기기별 폴백 가능)
- [ ] 알림 탭 → 앱 열림

## 잠금화면 버튼
- [ ] 일시정지 탭 → 카운트다운 고정, 버튼이 재개로 변경, 예약된 종료 알림이 울리지 않음
- [ ] 재개 탭 → 카운트다운 재시작, 종료 시 소리·진동 알림 정상
- [ ] 취소 탭 → 알림 제거, 앱 복귀 시 타이머가 시작값으로 리셋 + 다이얼 각도 복원
- [ ] 일시정지 후 앱 복귀 → 남은 시간·다이얼 각도 일치
- [ ] 재개 후 앱 복귀 → 타이머 이어서 동작

## 프로세스 생존
- [ ] 앱 스와이프 킬 후 잠금화면에서 일시정지/재개/취소 동작
- [ ] 스와이프 킬 상태로 자연 종료 → 종료 알림 울림 + 진행형 알림 사라짐

## 앱 내 조작 연동
- [ ] 앱에서 일시정지 → 알림도 일시정지 상태로 갱신
- [ ] 앱에서 취소/다이얼 드래그 → 알림 제거
- [ ] 포그라운드 자연 종료(00:00) → 진행형 알림 제거 + 종료 알림 1회만

## 기타
- [ ] Android 13+ 첫 실행 시 알림 권한 요청 표시
- [ ] 알림 스와이프로 지운 뒤에도 타이머·종료 알림 정상
- [ ] iOS 회귀 없음(Live Activity 기존 동작 그대로)
```

- [ ] **Step 2: 최종 검증 일괄 실행**

Run: `flutter analyze && flutter test && flutter build apk --debug`
Expected: 모두 성공

- [ ] **Step 3: 커밋**

```bash
git add _docs/version-update-note/next-android-ongoing-notification.md
git commit -m "docs: Android 진행형 알림 수동 검증 체크리스트

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```
