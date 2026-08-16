import ActivityKit
import AlarmKit
import AppIntents
import SwiftUI
import WidgetKit

/// AlarmKit(iOS 26+) 카운트다운의 커스텀 Live Activity.
/// 레이아웃·상수는 기존 JogumanTimerLiveActivity와 동일하고, 상태는 App Group
/// UserDefaults 대신 시스템이 주는 context.state.mode에서 읽는다.
/// 0초 도달 시의 알럿 UI와 종료 정리는 시스템이 담당한다.
@available(iOS 26.0, *)
struct JogumanAlarmLiveActivity: Widget {
    typealias Context = ActivityViewContext<AlarmAttributes<JogumanAlarmMetadata>>

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AlarmAttributes<JogumanAlarmMetadata>.self) { context in
            lockScreenView(context)
                .activityBackgroundTint(Color("WidgetBackground"))
                .activitySystemActionForegroundColor(Color("WidgetLabel"))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    controlButtons(context)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    timerText(context)
                        .font(jogumanFont(size: TimerMetrics.islandExpandedTimeSize))
                        .foregroundColor(Color("TimerText"))
                }
            } compactLeading: {
                progressRing(context)
            } compactTrailing: {
                timerText(context)
                    .font(jogumanFont(size: TimerMetrics.islandCompactTimeSize))
                    .foregroundColor(Color("TimerText"))
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .frame(width: TimerMetrics.islandCompactTimeWidth)
            } minimal: {
                progressRing(context)
            }
        }
    }

    @ViewBuilder
    private func lockScreenView(_ context: Context) -> some View {
        let label = context.attributes.metadata?.label ?? ""
        HStack(alignment: .center) {
            HStack(alignment: .bottom, spacing: TimerMetrics.lockScreenLabelSpacing) {
                controlButtons(context)
                Text(label)
                    .font(jogumanFont(size: TimerMetrics.lockScreenLabelSize))
                    .foregroundColor(Color("WidgetLabel"))
                    .offset(y: TimerMetrics.lockScreenLabelYOffset)
            }
            Spacer()
            timerText(context)
                .font(jogumanFont(size: TimerMetrics.lockScreenTimeSize))
                .foregroundColor(Color("TimerText"))
                .multilineTextAlignment(.trailing)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(width: TimerMetrics.lockScreenTimeWidth, alignment: .trailing)
                .offset(y: TimerMetrics.lockScreenTimeYOffset)
        }
        .padding([.vertical, .leading])
        .padding(.trailing, TimerMetrics.lockScreenTrailingPadding)
        .overlay(
            ContainerRelativeShape()
                .strokeBorder(Color("WidgetBorder"), lineWidth: 4)
        )
    }

    @ViewBuilder
    private func timerText(_ context: Context) -> some View {
        switch context.state.mode {
        case .countdown(let countdown):
            let end = countdown.fireDate
            let start = min(Date(), end)
            Text(
                timerInterval: start...max(end, start.addingTimeInterval(1)),
                countsDown: true)
        case .paused(let paused):
            let remaining = Int(
                (paused.totalCountdownDuration - paused.previouslyElapsedDuration).rounded())
            Text(formatWidgetTime(max(0, remaining)))
        default:
            // 알럿 상태는 시스템 UI가 덮는다 — 도달 전 잠깐을 위한 폴백
            Text(formatWidgetTime(0))
        }
    }

    @ViewBuilder
    private func progressRing(_ context: Context) -> some View {
        Group {
            switch context.state.mode {
            case .countdown(let countdown):
                // 시작점을 fireDate − 전체 시간으로 두면 진행률 = 남은 시간/전체 시간
                let end = countdown.fireDate
                let start = end.addingTimeInterval(-max(countdown.totalCountdownDuration, 1))
                ProgressView(
                    timerInterval: start...max(end, start.addingTimeInterval(1)),
                    countsDown: true,
                    label: { EmptyView() },
                    currentValueLabel: { EmptyView() }
                )
                .progressViewStyle(.circular)
            case .paused(let paused):
                let total = max(paused.totalCountdownDuration, 1)
                let remaining = max(0, total - paused.previouslyElapsedDuration)
                ProgressView(value: min(remaining / total, 1))
                    .progressViewStyle(.circular)
            default:
                ProgressView(value: 0)
                    .progressViewStyle(.circular)
            }
        }
        .tint(Color("TimerText"))
        .frame(width: TimerMetrics.islandRingSize, height: TimerMetrics.islandRingSize)
    }

    @ViewBuilder
    private func controlButtons(_ context: Context) -> some View {
        HStack(spacing: 8) {
            switch context.state.mode {
            case .paused:
                Button(intent: AlarmKitResumeIntent()) {
                    widgetButtonImage("start")
                }
                .buttonStyle(.plain)
            default:
                Button(intent: AlarmKitPauseIntent()) {
                    widgetButtonImage("pause")
                }
                .buttonStyle(.plain)
            }
            Button(intent: AlarmKitCancelIntent()) {
                widgetButtonImage("clear")
            }
            .buttonStyle(.plain)
        }
    }
}
