import SwiftUI

// 기존(live_activities) 위젯과 AlarmKit(iOS 26+) 위젯이 공유하는 폰트·크기 상수·버튼 이미지.

func jogumanFont(size: CGFloat) -> Font {
    Font.custom("JogumanHandwriting-Regular", size: size)
}

// 시간 표시부 미세조정용 상수 — 숫자만 바꿔서 튜닝
enum TimerMetrics {
    static let lockScreenTimeSize: CGFloat = 48  // 잠금화면 시간 폰트 크기
    static let lockScreenTimeWidth: CGFloat = 150  // 잠금화면 시간 고정 폭 (숫자는 이 안에서 우측정렬)
    static let lockScreenLabelSize: CGFloat = 28  // 잠금화면 '타이머' 라벨 폰트 크기
    static let islandExpandedTimeSize: CGFloat = 40  // 아일랜드 확장 뷰 시간 폰트 크기
    static let islandCompactTimeSize: CGFloat = 20  // 아일랜드 컴팩트 시간 폰트 크기
    static let islandCompactTimeWidth: CGFloat = 64  // 아일랜드 컴팩트 시간 고정 폭
    static let lockScreenLabelSpacing: CGFloat = 12  // 버튼과 '타이머' 라벨 사이 간격
    static let islandRingSize: CGFloat = 22  // 아일랜드 컴팩트/미니멀 진행률 링 크기
    static let lockScreenTrailingPadding: CGFloat = 20  // 잠금화면 시간 오른쪽 여백 (기본 패딩 16 대체)
    static let lockScreenLabelYOffset: CGFloat = 3  // '타이머' 라벨 세로 오프셋 (양수 = 아래로)
    static let lockScreenTimeYOffset: CGFloat = 3  // 시간 텍스트 세로 오프셋 (양수 = 아래로)
}

func widgetButtonImage(_ name: String) -> some View {
    Image(name)
        .resizable()
        .scaledToFit()
        .frame(width: 44, height: 44)
}

func formatWidgetTime(_ seconds: Int) -> String {
    let m = seconds / 60
    let s = seconds % 60
    return String(format: "%d:%02d", m, s)
}
