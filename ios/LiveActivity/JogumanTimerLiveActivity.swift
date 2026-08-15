import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

private let sharedDefault = UserDefaults(suiteName: "group.com.joguman.pomodoro")!

struct JogumanTimerLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: LiveActivitiesAppAttributes.self) { context in
      lockScreenView(context)
        .activityBackgroundTint(Color.black.opacity(0.85))
        .activitySystemActionForegroundColor(Color.white)
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          controlButtons(context)
        }
        DynamicIslandExpandedRegion(.trailing) {
          timerText(context)
            .font(.title2).monospacedDigit()
            .foregroundColor(.orange)
        }
      } compactLeading: {
        Image(systemName: "timer").foregroundColor(.orange)
      } compactTrailing: {
        timerText(context)
          .monospacedDigit()
          .foregroundColor(.orange)
          .frame(maxWidth: 60)
      } minimal: {
        Image(systemName: "timer").foregroundColor(.orange)
      }
    }
  }

  @ViewBuilder
  private func lockScreenView(_ context: ActivityViewContext<LiveActivitiesAppAttributes>) -> some View {
    let label = sharedDefault.string(forKey: context.attributes.prefixedKey("label")) ?? ""
    HStack {
      controlButtons(context)
      Spacer()
      VStack(alignment: .trailing, spacing: 2) {
        Text(label)
          .font(.caption)
          .foregroundColor(.orange.opacity(0.9))
        timerText(context)
          .font(.system(size: 40, weight: .semibold))
          .monospacedDigit()
          .foregroundColor(.orange)
      }
    }
    .padding()
  }

  @ViewBuilder
  private func timerText(_ context: ActivityViewContext<LiveActivitiesAppAttributes>) -> some View {
    let isPaused = (sharedDefault.string(forKey: context.attributes.prefixedKey("isPaused")) ?? "false") == "true"
    if isPaused {
      let remaining = Int(sharedDefault.string(forKey: context.attributes.prefixedKey("remainingSeconds")) ?? "0") ?? 0
      Text(formatTime(remaining))
    } else {
      let endMs = Double(sharedDefault.string(forKey: context.attributes.prefixedKey("endDateMs")) ?? "0") ?? 0
      let endDate = Date(timeIntervalSince1970: endMs / 1000.0)
      let start = min(Date(), endDate)
      Text(timerInterval: start...max(endDate, start.addingTimeInterval(1)), countsDown: true)
    }
  }

  @ViewBuilder
  private func controlButtons(_ context: ActivityViewContext<LiveActivitiesAppAttributes>) -> some View {
    if #available(iOS 17.0, *) {
      let isPaused = (sharedDefault.string(forKey: context.attributes.prefixedKey("isPaused")) ?? "false") == "true"
      HStack(spacing: 12) {
        if isPaused {
          Button(intent: ResumeTimerIntent()) {
            Image(systemName: "play.fill")
              .foregroundColor(.white)
              .frame(width: 44, height: 44)
              .background(Color.orange)
              .clipShape(Circle())
          }
          .buttonStyle(.plain)
        } else {
          Button(intent: PauseTimerIntent()) {
            Image(systemName: "pause.fill")
              .foregroundColor(.white)
              .frame(width: 44, height: 44)
              .background(Color.orange)
              .clipShape(Circle())
          }
          .buttonStyle(.plain)
        }
        Button(intent: CancelTimerIntent()) {
          Image(systemName: "xmark")
            .foregroundColor(.white)
            .frame(width: 44, height: 44)
            .background(Color.gray.opacity(0.5))
            .clipShape(Circle())
        }
        .buttonStyle(.plain)
      }
    }
  }

  private func formatTime(_ seconds: Int) -> String {
    let m = seconds / 60
    let s = seconds % 60
    return String(format: "%02d:%02d", m, s)
  }
}
