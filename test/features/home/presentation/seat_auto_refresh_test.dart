import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hongik_ingan/features/seat/presentation/seat_auto_refresh.dart';

void main() {
  test('웹은 30초, 네이티브는 15초 간격을 사용한다', () {
    expect(seatAutoRefreshInterval(isWeb: true), seatWebAutoRefreshInterval);
    expect(
      seatAutoRefreshInterval(isWeb: false),
      seatNativeAutoRefreshInterval,
    );
  });

  testWidgets('진입 즉시 조회하고 설정한 주기로 자동 갱신한다', (tester) async {
    var refreshCount = 0;

    await tester.pumpWidget(
      _frame(
        SeatAutoRefresh(
          interval: const Duration(seconds: 15),
          onRefresh: () async => refreshCount++,
          child: const SizedBox(),
        ),
      ),
    );
    await tester.pump();

    expect(refreshCount, 1);

    await tester.pump(const Duration(seconds: 14));
    expect(refreshCount, 1);

    await tester.pump(const Duration(seconds: 1));
    expect(refreshCount, 2);
  });

  testWidgets('백그라운드에서는 중단하고 포그라운드 복귀 시 즉시 조회한다', (tester) async {
    var refreshCount = 0;

    await tester.pumpWidget(
      _frame(
        SeatAutoRefresh(
          interval: const Duration(seconds: 15),
          onRefresh: () async => refreshCount++,
          child: const SizedBox(),
        ),
      ),
    );
    await tester.pump();
    expect(refreshCount, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 30));
    expect(refreshCount, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(refreshCount, 2);

    await tester.pump(const Duration(seconds: 15));
    expect(refreshCount, 3);
  });

  testWidgets('화면이 보이지 않으면 중단하고 다시 보일 때 즉시 조회한다', (tester) async {
    var refreshCount = 0;

    Widget subject(bool enabled) {
      return _frame(
        TickerMode(
          enabled: enabled,
          child: SeatAutoRefresh(
            interval: const Duration(seconds: 15),
            onRefresh: () async => refreshCount++,
            child: const SizedBox(),
          ),
        ),
      );
    }

    await tester.pumpWidget(subject(true));
    await tester.pump();
    expect(refreshCount, 1);

    await tester.pumpWidget(subject(false));
    await tester.pump(const Duration(seconds: 30));
    expect(refreshCount, 1);

    await tester.pumpWidget(subject(true));
    await tester.pump();
    expect(refreshCount, 2);
  });

  testWidgets('enabled 재활성화 조회는 빌드가 끝난 뒤 실행한다', (tester) async {
    final refreshPhases = <SchedulerPhase>[];

    Widget subject(bool enabled) {
      return _frame(
        SeatAutoRefresh(
          enabled: enabled,
          interval: const Duration(seconds: 15),
          onRefresh: () async {
            refreshPhases.add(SchedulerBinding.instance.schedulerPhase);
          },
          child: const SizedBox(),
        ),
      );
    }

    await tester.pumpWidget(subject(false));
    expect(refreshPhases, isEmpty);

    await tester.pumpWidget(subject(true));

    expect(refreshPhases, [SchedulerPhase.postFrameCallbacks]);
  });
}

Widget _frame(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}
