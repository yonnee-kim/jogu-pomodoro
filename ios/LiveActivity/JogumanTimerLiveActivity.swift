import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

private let sharedDefault = UserDefaults(suiteName: "group.com.joguman.pomodoro")!

struct JogumanTimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LiveActivitiesAppAttributes.self) { context in
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

    /// 남은 시간 비율을 표시하는 진행률 링. 진행 중에는 시스템이 자동 갱신하는
    /// timerInterval ProgressView(내장 circular 스타일만 실시간 갱신 지원)를 쓴다.
    @ViewBuilder
    private func progressRing(_ context: ActivityViewContext<LiveActivitiesAppAttributes>)
        -> some View
    {
        let isPaused =
            (sharedDefault.string(forKey: context.attributes.prefixedKey("isPaused")) ?? "false")
            == "true"
        let total =
            Double(
                sharedDefault.string(forKey: context.attributes.prefixedKey("totalSeconds")) ?? "0")
            ?? 0
        Group {
            if isPaused || total <= 0 {
                let remaining =
                    Double(
                        sharedDefault.string(
                            forKey: context.attributes.prefixedKey("remainingSeconds")) ?? "0") ?? 0
                ProgressView(value: total > 0 ? min(max(remaining / total, 0), 1) : 1)
                    .progressViewStyle(.circular)
            } else {
                let endMs =
                    Double(
                        sharedDefault.string(forKey: context.attributes.prefixedKey("endDateMs"))
                            ?? "0")
                    ?? 0
                let endDate = Date(timeIntervalSince1970: endMs / 1000.0)
                let start = endDate.addingTimeInterval(-total)
                ProgressView(
                    timerInterval: start...max(endDate, start.addingTimeInterval(1)),
                    countsDown: true,
                    label: { EmptyView() },
                    currentValueLabel: { EmptyView() }
                )
                .progressViewStyle(.circular)
            }
        }
        .tint(Color("TimerText"))
        .frame(width: TimerMetrics.islandRingSize, height: TimerMetrics.islandRingSize)
    }

    @ViewBuilder
    private func lockScreenView(_ context: ActivityViewContext<LiveActivitiesAppAttributes>)
        -> some View
    {
        let label = sharedDefault.string(forKey: context.attributes.prefixedKey("label")) ?? ""
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
    private func timerText(_ context: ActivityViewContext<LiveActivitiesAppAttributes>) -> some View
    {
        let isPaused =
            (sharedDefault.string(forKey: context.attributes.prefixedKey("isPaused")) ?? "false")
            == "true"
        if isPaused {
            let remaining =
                Int(
                    sharedDefault.string(forKey: context.attributes.prefixedKey("remainingSeconds"))
                        ?? "0") ?? 0
            Text(formatWidgetTime(remaining))
        } else {
            let endMs =
                Double(
                    sharedDefault.string(forKey: context.attributes.prefixedKey("endDateMs")) ?? "0"
                ) ?? 0
            let endDate = Date(timeIntervalSince1970: endMs / 1000.0)
            let start = min(Date(), endDate)
            Text(
                timerInterval: start...max(endDate, start.addingTimeInterval(1)),
                countsDown: true)
        }
    }

    @ViewBuilder
    private func controlButtons(_ context: ActivityViewContext<LiveActivitiesAppAttributes>)
        -> some View
    {
        if #available(iOS 17.0, *) {
            let isPaused =
                (sharedDefault.string(forKey: context.attributes.prefixedKey("isPaused")) ?? "false")
                == "true"
            HStack(spacing: 8) {
                if isPaused {
                    Button(intent: ResumeTimerIntent()) {
                        widgetButtonImage("start")
                    }
                    .buttonStyle(.plain)
                } else {
                    Button(intent: PauseTimerIntent()) {
                        widgetButtonImage("pause")
                    }
                    .buttonStyle(.plain)
                }
                Button(intent: CancelTimerIntent()) {
                    widgetButtonImage("clear")
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Xcode Preview (캔버스 전용 — 상수 튜닝 시 실시간 확인용)
// 뷰가 App Group UserDefaults에서 상태를 읽으므로, 프리뷰용 attributes를 만들 때
// 같은 프로세스의 defaults에 시드 값을 심어 둔다.
#if DEBUG
    @available(iOS 16.2, *)
    extension LiveActivitiesAppAttributes {
        fileprivate static func preview(paused: Bool) -> LiveActivitiesAppAttributes {
            let attributes = LiveActivitiesAppAttributes()
            let end = Date().addingTimeInterval(45 * 60)
            sharedDefault.set("타이머", forKey: attributes.prefixedKey("label"))
            sharedDefault.set(paused ? "true" : "false", forKey: attributes.prefixedKey("isPaused"))
            sharedDefault.set(
                String(Int(end.timeIntervalSince1970 * 1000)),
                forKey: attributes.prefixedKey("endDateMs"))
            sharedDefault.set("2700", forKey: attributes.prefixedKey("totalSeconds"))
            sharedDefault.set("1520", forKey: attributes.prefixedKey("remainingSeconds"))
            return attributes
        }
    }

    @available(iOS 17.0, *)
    #Preview("잠금화면·진행", as: .content, using: LiveActivitiesAppAttributes.preview(paused: false)) {
        JogumanTimerLiveActivity()
    } contentStates: {
        LiveActivitiesAppAttributes.ContentState(appGroupId: "group.com.joguman.pomodoro")
    }

    @available(iOS 17.0, *)
    #Preview("잠금화면·일시정지", as: .content, using: LiveActivitiesAppAttributes.preview(paused: true)) {
        JogumanTimerLiveActivity()
    } contentStates: {
        LiveActivitiesAppAttributes.ContentState(appGroupId: "group.com.joguman.pomodoro")
    }

    @available(iOS 17.0, *)
    #Preview(
        "아일랜드·컴팩트", as: .dynamicIsland(.compact),
        using: LiveActivitiesAppAttributes.preview(paused: false)
    ) {
        JogumanTimerLiveActivity()
    } contentStates: {
        LiveActivitiesAppAttributes.ContentState(appGroupId: "group.com.joguman.pomodoro")
    }

    @available(iOS 17.0, *)
    #Preview(
        "아일랜드·확장", as: .dynamicIsland(.expanded),
        using: LiveActivitiesAppAttributes.preview(paused: false)
    ) {
        JogumanTimerLiveActivity()
    } contentStates: {
        LiveActivitiesAppAttributes.ContentState(appGroupId: "group.com.joguman.pomodoro")
    }
#endif
