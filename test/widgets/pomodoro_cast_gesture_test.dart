import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:joguman_pomodoro/providers/angle_provider.dart';
import 'package:joguman_pomodoro/providers/data_provider.dart';
import 'package:joguman_pomodoro/widgets/pomodoro_cast.dart';
import 'package:provider/provider.dart';

/// 테스트 환경에는 플러그인 구현체가 등록되지 않아 DataProvider.cancleTimer()가
/// LateInitializationError를 던진다. 무동작 구현으로 대체하고 호출 횟수를 센다.
class _NoopNotificationsPlatform extends FlutterLocalNotificationsPlatform {
  static int cancelCount = 0;

  @override
  Future<void> cancel(int id) async => cancelCount++;
}

Widget _wrap({
  required double regionWidth,
  required double regionHeight,
  required double clockSize,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => AngleProvider()),
      ChangeNotifierProvider(create: (_) => DataProvider()),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: regionWidth,
            height: regionHeight,
            child: Center(
              child: PomodoroCast(
                clockSize: clockSize,
                clockHandWidth: 5,
                clockHandHeight: clockSize * 0.39,
                clockHandFoot: const SizedBox(width: 20, height: 20),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// 다이얼 중심에서 [degrees](12시=0°, 시계방향) 방향으로 [radius]만큼 떨어진 지점까지
/// 드래그하고, 그때 AngleProvider에 설정된 각도를 돌려준다.
/// (손을 떼면 분 단위로 스냅되므로 떼기 전 값을 읽는다)
Future<double> _angleAfterDragTo(
  WidgetTester tester,
  double degrees, {
  double radius = 100,
}) async {
  final BuildContext ctx = tester.element(find.byType(PomodoroCast));
  final Offset dialCenter = tester.getCenter(find.byType(GestureDetector));
  final double rad = degrees * pi / 180;

  final TestGesture gesture = await tester.startGesture(dialCenter);
  await gesture
      .moveTo(dialCenter + Offset(sin(rad) * radius, -cos(rad) * radius));
  await tester.pump();
  final double angle = ctx.read<AngleProvider>().angle;

  await gesture.up();
  await tester.pump();
  return angle;
}

void main() {
  setUpAll(() {
    FlutterLocalNotificationsPlatform.instance = _NoopNotificationsPlatform();
  });

  // 가로모드: 다이얼 영역(leftRegion)이 clockSize보다 훨씬 넓어,
  // 제스처 박스 중심과 clockSize/2 가 크게 어긋난다.
  group('가로모드 다이얼 영역 (leftRegion 506 × clockSize 350)', () {
    Future<void> pump(WidgetTester tester) async {
      tester.view.physicalSize = const Size(844, 390);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
          _wrap(regionWidth: 506, regionHeight: 369, clockSize: 350));
    }

    testWidgets('30° 터치 방향과 다이얼 각도가 일치한다', (WidgetTester tester) async {
      await pump(tester);
      expect(await _angleAfterDragTo(tester, 30), closeTo(pi / 6, 0.01));
    });

    testWidgets('45° 터치 방향과 다이얼 각도가 일치한다', (WidgetTester tester) async {
      await pump(tester);
      expect(await _angleAfterDragTo(tester, 45), closeTo(pi / 4, 0.01));
    });
  });

  group('세로모드 다이얼 영역 (화면폭 390 × clockSize 351)', () {
    Future<void> pump(WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
          _wrap(regionWidth: 390, regionHeight: 700, clockSize: 351));
    }

    testWidgets('10° 터치 방향과 다이얼 각도가 일치한다', (WidgetTester tester) async {
      await pump(tester);
      expect(await _angleAfterDragTo(tester, 10), closeTo(pi / 18, 0.01));
    });

    testWidgets('30° 터치 방향과 다이얼 각도가 일치한다', (WidgetTester tester) async {
      await pump(tester);
      expect(await _angleAfterDragTo(tester, 30), closeTo(pi / 6, 0.01));
    });
  });

  // 타이머 취소는 예약 알림 취소(플랫폼 채널 왕복)를 동반하므로
  // 포인터 이벤트마다 부르면 드래그가 버벅인다.
  testWidgets('타이머 취소는 포인터 이벤트마다가 아니라 드래그당 한 번만 호출된다',
      (WidgetTester tester) async {
    // android 타겟에서는 android 전용 구현체로만 위임되어 무동작 구현이 호출되지 않는다.
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

    await tester.pumpWidget(
        _wrap(regionWidth: 390, regionHeight: 700, clockSize: 351));

    final Offset dialCenter = tester.getCenter(find.byType(GestureDetector));
    _NoopNotificationsPlatform.cancelCount = 0;

    final TestGesture gesture =
        await tester.startGesture(dialCenter + const Offset(0, -120));
    for (int i = 1; i <= 10; i++) {
      final double rad = i * 2 * pi / 180;
      await gesture
          .moveTo(dialCenter + Offset(sin(rad) * 120, -cos(rad) * 120));
      await tester.pump();
    }
    await gesture.up();
    await tester.pump();

    final int cancelCount = _NoopNotificationsPlatform.cancelCount;
    debugDefaultTargetPlatformOverride = null; // 테스트 종료 전에 복구해야 한다
    expect(cancelCount, 1);
  });
}
