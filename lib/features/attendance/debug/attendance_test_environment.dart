import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hongik_ingan/core/network/school_request_options.dart';
import 'package:hongik_ingan/core/network/school_transport.dart';
import 'package:hongik_ingan/features/home/application/home_controller.dart';

import '../application/attendance_controller.dart';
import '../application/attendance_data_source.dart';
import '../application/attendance_overview_provider.dart';
import '../data/attendance_history_repository.dart';
import '../domain/attendance_request_record.dart';

final attendanceTestLatencyProvider = Provider<Duration>(
  (ref) => const Duration(milliseconds: 350),
);

final attendanceTestControllerProvider =
    NotifierProvider<AttendanceTestController, AttendanceTestScenario?>(
      AttendanceTestController.new,
    );

enum AttendanceTestScenario {
  normal('번호 입력'),
  empty('수업 없음'),
  fetchFailure('수업 조회 오류'),
  locationFailure('위치 확인 오류'),
  unconfirmed('제출 결과 확인 불가');

  const AttendanceTestScenario(this.label);
  final String label;
}

/// Switch only attendance dependencies in the existing application's container.
class AttendanceTestController extends Notifier<AttendanceTestScenario?> {
  @override
  AttendanceTestScenario? build() {
    ref.listen(homeControllerProvider, (previous, next) {
      if (state != null &&
          (!next.isLoggedIn || previous?.userId != next.userId)) {
        _clear();
      }
    });
    return null;
  }

  bool get _canChange => kDebugMode && !ref.read(attendanceProvider).isBusy;

  Future<void> enable([
    AttendanceTestScenario scenario = AttendanceTestScenario.normal,
  ]) async {
    if (!_canChange || !ref.read(homeControllerProvider).isLoggedIn) return;
    final latency = ref.read(attendanceTestLatencyProvider);
    final transport = AttendanceTestTransport(
      scenario: scenario,
      latency: latency,
    );
    final source = AttendanceDataSource(
      transport: transport,
      historyRepository: _MemoryHistoryRepository(),
      locationProvider: () async {
        if (latency > Duration.zero) await Future<void>.delayed(latency);
        if (transport.scenario == AttendanceTestScenario.locationFailure) {
          throw Exception('위치 권한이 거부됐어요.');
        }
        return Position(
          latitude: 37.551,
          longitude: 126.925,
          timestamp: DateTime.now(),
          accuracy: 1,
          altitude: 0,
          altitudeAccuracy: 0,
          heading: 0,
          headingAccuracy: 0,
          speed: 0,
          speedAccuracy: 0,
        );
      },
    );
    ref.read(attendanceDataSourceOverrideProvider.notifier).setSource(source);
    state = scenario;
    ref.invalidate(attendanceOverviewProvider);
    await _refresh();
  }

  Future<void> changeScenario(AttendanceTestScenario scenario) async {
    if (!_canChange || state == null) return;
    final source = ref.read(attendanceDataSourceOverrideProvider)!;
    (source.transport as AttendanceTestTransport).changeScenario(scenario);
    state = scenario;
    await _refresh();
  }

  Future<void> disable() async {
    if (!_canChange || state == null) return;
    _clear();
    if (ref.read(homeControllerProvider).isLoggedIn) {
      await ref
          .read(attendanceProvider.notifier)
          .fetchLecture(forceRefresh: true);
    }
  }

  void _clear() {
    ref.read(attendanceProvider.notifier).resetSession();
    state = null;
    ref.read(attendanceDataSourceOverrideProvider.notifier).setSource(null);
    ref.invalidate(attendanceOverviewProvider);
  }

  Future<void> _refresh() async {
    final controller = ref.read(attendanceProvider.notifier);
    controller.resetSession();
    await controller.fetchLecture(forceRefresh: true);
  }
}

/// Only fixture responses are supported. There is deliberately no network fallback.
class AttendanceTestTransport implements SchoolHttpTransport {
  AttendanceTestTransport({
    AttendanceTestScenario scenario = AttendanceTestScenario.normal,
    this.latency = const Duration(milliseconds: 350),
  }) : _scenario = scenario;

  AttendanceTestScenario _scenario;
  AttendanceTestScenario get scenario => _scenario;
  final Duration latency;
  int lectureRequests = 0;
  final List<Map<String, dynamic>> submissions = [];
  bool _accepted = false;

  void changeScenario(AttendanceTestScenario scenario) {
    _scenario = scenario;
    _accepted = false;
  }

  Future<void> _wait() async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
  }

  Response<T> _response<T>(String target, Object body, {int status = 200}) =>
      Response<T>(
        data: body as T,
        statusCode: status,
        requestOptions: RequestOptions(path: target),
      );

  @override
  Future<Response<T>> get<T>(
    String target, {
    Map<String, dynamic>? queryParameters,
    SchoolRequestOptions options = const SchoolRequestOptions(),
  }) async {
    if (target == 'https://at.hongik.ac.kr/index.jsp') {
      lectureRequests++;
      await _wait();
      if (scenario == AttendanceTestScenario.fetchFailure) {
        return _response(target, 'Test server unavailable', status: 503);
      }
      return _response(
        target,
        scenario == AttendanceTestScenario.empty || _accepted
            ? '<table><tbody></tbody></table>'
            : _lectureHtml,
      );
    }
    if (target == 'https://at.hongik.ac.kr/stud04.jsp') {
      return _response(target, _coursesHtml);
    }
    throw UnsupportedError('Unsupported attendance test GET: $target');
  }

  @override
  Future<Response<T>> post<T>(
    String target, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    SchoolRequestOptions options = const SchoolRequestOptions(),
  }) async {
    if (target == 'https://at.hongik.ac.kr/stud05.jsp') {
      return _response(target, '''<h4>수강과목 출결현황 - 모바일 앱 프로그래밍</h4>
<div>출석부가 공개되지 않았습니다.</div>''');
    }
    if (target != 'https://at.hongik.ac.kr/stud02_proc.jsp') {
      throw UnsupportedError('Unsupported attendance test POST: $target');
    }
    final payload = Map<String, dynamic>.from(data! as Map);
    submissions.add(payload);
    await _wait();
    if (scenario == AttendanceTestScenario.unconfirmed) {
      throw DioException(
        requestOptions: RequestOptions(path: target),
        type: DioExceptionType.receiveTimeout,
      );
    }
    _accepted = payload['key'] == '1234';
    return _response(
      target,
      _accepted
          ? "<script>alert('출석이 완료됐어요.');</script>"
          : "<script>alert('인증번호가 올바르지 않아요.');</script>",
    );
  }
}

class _MemoryHistoryRepository extends AttendanceHistoryRepository {
  final Map<String, List<AttendanceRequestRecord>> _records = {};

  @override
  Future<List<AttendanceRequestRecord>> load(String userId) async =>
      List.unmodifiable(_records[userId] ?? []);

  @override
  Future<void> save(String userId, AttendanceRequestRecord record) async {
    final records = _records.putIfAbsent(userId, () => []);
    records.removeWhere((previous) => previous.id == record.id);
    records.insert(0, record);
    if (records.length > AttendanceHistoryRepository.maxRecords) {
      records.removeLast();
    }
  }
}

const _lectureHtml = '''<table><tbody><tr>
<td>1</td><td>학부</td><td>모바일 앱 프로그래밍</td><td>강의실</td>
<td>월 10:00 - 11:50</td><td><form action="stud02.jsp">
<input name="yy" value="2026"><input name="hakgi" value="2">
<input name="haksu" value="123456"><input name="bunban" value="1">
</form></td></tr></tbody></table>''';

const _coursesHtml = '''<h4>수강과목 출결현황</h4>
<table><thead><tr><th>수강학기</th><th>구분</th><th>학수번호</th><th>과목명</th></tr></thead>
<tbody><tr><td>2026-2</td><td>학부</td><td>123456-1</td><td>모바일 앱 프로그래밍
<form action="stud05.jsp"><input name="yy"><input name="hakgi">
<input name="haksu"><input name="bunban"></form></td></tr></tbody></table>''';
