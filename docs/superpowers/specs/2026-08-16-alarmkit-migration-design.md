# AlarmKit 마이그레이션 설계 (iOS 26 분기)

2026-08-16 승인. 목표: 타이머 0초 자연종료 시 잠금화면 위젯·다이내믹 아일랜드가 스스로 사라지지 않는 문제를 iOS 26+ AlarmKit으로 해결. '끝!' 문구 표기는 제거.

## 배경

- ActivityKit Live Activity는 앱 코드 실행 또는 서버 푸시로만 end() 가능. staleDate는 만료 순간 재렌더링을 보장하지 않음(iOS 알려진 한계) → '끝!' 표시 방식 폐기.
- AlarmKit(iOS 26+)은 시스템이 카운트다운 Live Activity를 관리하고, 0초에 시스템 알람 알럿(소리 + 중지)을 띄우며, 중지 시 위젯·아일랜드를 함께 제거.

## 결정 사항

- iOS 26+ 및 AlarmKit 권한 허용 시: AlarmKit 경로. 그 외(iOS <26, 권한 거부): 기존 live_activities 경로 유지.
- iOS 26+에서는 기존 flutter_local_notifications 종료 알림 예약과 무음모드 진동 특례를 건너뜀 — 종료 알림은 AlarmKit 알럿이 전담.
- 종료음은 커스텀 사운드 `.named("bip.wav")` 지정 → 반복 없이 1회 재생(기본음은 반복됨, 커스텀 사운드는 파일 길이만큼 재생 — Apple Forums thread 807752).
- '끝!' 표시 관련 코드 전부 제거: 위젯 isStale 분기, doneLabel payload, setStaleDate 채널 메서드, TimerControlIntents의 staleDate, 번역 키 la_done.
- AlarmKit 알럿은 무음모드를 관통(시계 앱과 동일) — iOS 26+에서 "진동 모드면 무음+진동" 동작은 사라짐(수용).

## 아키텍처

### 분기 지점 (Dart, 단일)

- `LiveActivityService.init()`에서 채널로 `alarmkitAvailable`(iOS 26+) 조회.
- 타이머 첫 시작 시 `alarmkitEnsureAuth`로 권한 요청. 거부 → 이후 기존 경로 폴백.
- `startOrUpdateRunning`은 "네이티브가 종료 알럿을 전담하는지" bool 반환. `DataProvider.setMyTimer`가 이 값으로 로컬 알림 예약·진동 특례를 건너뜀.
- AlarmKit 경로 라우팅: start → `alarmkitStart`(기존 알람 cancel 후 재스케줄), pause → `alarmkitPause`, resume/재시작 → `alarmkitStart`, 취소 → `alarmkitCancel`.
- 자연종료(0초)와 사용자 취소 구분: 자연종료 시 AlarmKit 경로에서는 알람을 건드리지 않음(알럿이 울려야 함). 기존 경로는 지금처럼 활동 end().

### 네이티브 (iOS)

- `ios/Shared/AlarmKitSupport.swift` (Runner + LiveActivityExtension 양쪽 타깃):
  - `JogumanAlarmMetadata: AlarmMetadata` — 위젯 라벨('타이머' 번역) 문자열 보유.
  - `@available(iOS 26.0, *)` 제어 핸들러: AlarmManager pause/resume/cancel + 기존 `la_sync_*` 스냅샷 기록 + 앱 핑(기존 메커니즘 재사용). 알람 id·endDateMs 북키핑은 App Group defaults `ak_*` 키.
  - LiveActivityIntent 3종(AlarmKit용 pause/resume/cancel) — 위젯 버튼용.
- `ios/Runner/AlarmKitBridge.swift`: 채널 메서드 `alarmkitAvailable` / `alarmkitEnsureAuth` / `alarmkitStart` / `alarmkitPause` / `alarmkitCancel`. schedule은 `AlarmManager.AlarmConfiguration.timer(duration:attributes:sound: .named("bip.wav"))`. 알럿 제목·중지 버튼 문구는 Dart가 넘긴 번역 문자열.
- `ios/Runner/Info.plist`: `NSAlarmKitUsageDescription` 추가(누락 시 schedule 실패).
- 위젯: `ios/LiveActivity/JogumanAlarmLiveActivity.swift` — `ActivityConfiguration(for: AlarmAttributes<JogumanAlarmMetadata>.self)`. 디자인은 현행 그대로(손글씨 폰트, PNG 버튼, 진행률 링, TimerMetrics). 시간·진행률·일시정지 상태는 `context.state.mode`(.countdown/.paused)에서 읽음(App Group defaults 불필요). 알럿 상태 UI는 시스템 관리. `LiveActivityBundle`에 `#available(iOS 26)` 조건으로 등록. TimerMetrics 등 공용 요소는 위젯 타깃 내 공유 파일로 추출.

### 번역

- `la_done` 제거(5개 언어), 알람 중지 버튼용 `la_stop` 추가(5개 언어). 알럿 제목은 기존 `end_message` 재사용.

## 검증

- flutter analyze / flutter test (payload 테스트에서 doneLabel 제거 반영).
- Xcode 26 SDK로 iOS 빌드 통과.
- 실기기 E2E(사용자): iOS 26 — 권한 프롬프트, 카운트다운 위젯, 위젯·앱 양쪽 일시정지/재개 동기화, 0초 알럿(bip 1회), 중지 시 위젯 소멸. iOS <26 — 기존 경로 회귀(0:00 정지, 종료 알림, 앱 복귀 시 제거).

## 제약

- 알럿 UI(중지 버튼 스타일 등)는 시스템 렌더링 — 제목·버튼 문구·틴트만 지정 가능.
- 커스텀 사운드 1회 재생은 현행 OS 동작 기반(추후 변경 가능성 있음).
- iOS 26 Live Activity 다크 고정 버그는 별개 이슈로 계속 적용됨.
