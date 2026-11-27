import 'logger.dart';

/// 앱 실행(main 진입)부터 수업이 화면에 나올 때까지 단계별 경과 시간을 기록한다.
///
/// 각 단계는 처음 한 번만 기록하고, 수업이 표시되거나 [_window]가 지나면
/// 기록을 멈춘다. [start]를 부르지 않은 환경(테스트 등)에서는 아무것도 하지 않는다.
abstract final class StartupTimeline {
  static const _window = Duration(seconds: 30);

  static final Stopwatch _clock = Stopwatch();
  static final Map<String, int> _marks = {};
  static bool _closed = false;

  static void start() {
    if (_clock.isRunning || _closed) return;
    _clock.start();
  }

  /// [step] 단계에 도달한 시점을 기록한다.
  static void mark(String step) {
    if (!_clock.isRunning || _closed || _marks.containsKey(step)) return;
    final elapsed = _clock.elapsed;
    if (elapsed > _window) {
      _close();
      return;
    }
    _marks[step] = elapsed.inMilliseconds;
    logMsg(
      'startup step=$step elapsedMs=${elapsed.inMilliseconds}',
      level: LogLevel.info,
    );
  }

  /// 마지막 단계를 기록하고 전체 요약을 남긴다.
  static void finish(String step) {
    mark(step);
    if (_closed || !_clock.isRunning) return;
    final summary = _marks.entries
        .map((entry) => '${entry.key}=${entry.value}')
        .join(' ');
    logMsg('startup summary $summary', level: LogLevel.info);
    _close();
  }

  static void _close() {
    _closed = true;
    _clock.stop();
  }
}
