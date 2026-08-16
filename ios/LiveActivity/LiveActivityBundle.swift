import SwiftUI
import WidgetKit

@main
struct LiveActivityBundle: WidgetBundle {
  var body: some Widget {
    JogumanTimerLiveActivity()
    alarmWidget()
  }

  // AlarmKit(iOS 26+) 카운트다운용 위젯 — 구버전에서는 빈 번들 항목
  @WidgetBundleBuilder
  private func alarmWidget() -> some Widget {
    if #available(iOS 26.0, *) {
      JogumanAlarmLiveActivity()
    }
  }
}
