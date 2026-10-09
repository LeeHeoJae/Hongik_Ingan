import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hongik_ingan/core/network/school_request_options.dart';
import 'package:hongik_ingan/core/network/school_transport.dart';
import 'package:hongik_ingan/features/attendance/application/attendance_controller.dart';
import 'package:hongik_ingan/features/attendance/application/attendance_overview_provider.dart';
import 'package:hongik_ingan/features/attendance/data/attendance_overview_service.dart';
import 'package:hongik_ingan/features/attendance/domain/attendance_overview.dart';
import 'package:hongik_ingan/features/attendance/domain/attendance_request_record.dart';
import 'package:hongik_ingan/features/home/application/home_controller.dart';

// Structure observed on stud04/stud05; names and results are test data.
const courseListHtml = '''
<h4>수강과목 출결현황</h4>
<table><thead><tr><th>수강학기</th><th>구분</th><th>학수번호</th><th>과목명</th></tr></thead>
<tbody><tr><td>2026-2</td><td>학부</td><td>123456-2</td><td>테스트 과목
<form method="post" action="stud05.jsp"><input name="yy"><input name="hakgi"><input name="haksu"><input name="bunban"></form>
</td></tr></tbody></table>''';
const publishedHtml = '''
<h4>수강과목 출결현황 - 테스트 과목</h4>
<table><thead><tr><th>요일/시간</th><th colspan="2">화2</th><th colspan="2">화3</th></tr>
<tr><th>주차</th><th>강의일자 / 교수</th><th>출결</th><th>강의일자 / 교수</th><th>출결</th></tr></thead>
<tbody><tr><td>1</td><td>09/08(화) / 테스트 교수</td><td><span>출석</span></td><td>미입력</td><td>-</td></tr>
<tr><td>2</td><td>09/15(화) / 테스트 교수</td><td>지각</td><td>09/15(화) / 테스트 교수</td><td>새로운 서버 표시</td></tr></tbody></table>''';
const privateHtml = '<h4>수강과목 출결현황 - 테스트 과목</h4><div>출석부가 공개되지 않았습니다.</div>';
const testCourse = AttendanceCourse(
  key: AttendanceCourseKey(
    year: '2026',
    semester: '2',
    courseCode: '123456',
    section: '2',
  ),
  name: '테스트 과목',
  category: '학부',
);

void main() {
  test(
    'list derives identifiers from visible cells, not empty hidden fields',
    () {
      final result = AttendanceOverviewService.parseCourses(courseListHtml);
      expect(result.single.key.toParams(), {
        'yy': '2026',
        'hakgi': '2',
        'haksu': '123456',
        'bunban': '2',
      });
      expect(result.single.name, '테스트 과목');
    },
  );

  test(
    'details preserve every period, unentered cells and unknown statuses',
    () {
      final result = AttendanceOverviewService.parseDetail(
        publishedHtml,
        testCourse,
      );
      expect(result.isPublished, true);
      expect(result.entries.map((e) => e.status), [
        '출석',
        '-',
        '지각',
        '새로운 서버 표시',
      ]);
      expect(result.entries[1].lectureLabel, '미입력');
      expect(result.entries.map((e) => e.schedule), ['화2', '화3', '화2', '화3']);
    },
  );

  test('private attendance is a valid result, not a network failure', () {
    expect(
      AttendanceOverviewService.parseDetail(
        privateHtml,
        testCourse,
      ).isPublished,
      false,
    );
  });

  test(
    'wrong course and malformed table cannot become an empty attendance result',
    () {
      expect(
        () => AttendanceOverviewService.parseDetail(
          publishedHtml.replaceAll('테스트 과목', '다른 과목'),
          testCourse,
        ),
        throwsA(isA<AttendanceOverviewException>()),
      );
      expect(
        () => AttendanceOverviewService.parseDetail(
          publishedHtml.replaceFirst('<td>-</td>', ''),
          testCourse,
        ),
        throwsA(isA<AttendanceOverviewException>()),
      );
      expect(
        () => AttendanceOverviewService.parseCourses(
          '<table><tbody></tbody></table>',
        ),
        throwsA(isA<AttendanceOverviewException>()),
      );
    },
  );

  test(
    'read-only detail POST sends exact course selection, without submission fields',
    () async {
      final transport = _Transport(publishedHtml);
      await AttendanceOverviewService(transport).fetchDetail(testCourse);
      expect(transport.target, 'https://at.hongik.ac.kr/stud05.jsp');
      expect(transport.payload, testCourse.key.toParams());
      expect(transport.options?.allowProxyRetry, false);
      expect(transport.options?.followRedirects, false);
    },
  );

  for (final body in [
    '<input name="USER_ID"><input name="PASSWD">',
    '<script>alert("장시간 사용이 없어 로그아웃 되었습니다.");</script>',
  ]) {
    test('HTTP 200 authentication page is recognized as expired', () async {
      await expectLater(
        AttendanceOverviewService(_Transport(body)).fetchCourses(),
        throwsA(
          isA<AttendanceOverviewException>().having(
            (e) => e.sessionExpired,
            'expired',
            true,
          ),
        ),
      );
    });
  }

  test('redirect is recognized before HTML parsing', () async {
    await expectLater(
      AttendanceOverviewService(_Transport('', status: 302)).fetchCourses(),
      throwsA(
        isA<AttendanceOverviewException>().having(
          (e) => e.sessionExpired,
          'expired',
          true,
        ),
      ),
    );
  });

  test(
    'old records still deserialize; new course identity survives result storage',
    () {
      final record = AttendanceRequestRecord(
        id: '1',
        lectureName: '테스트 과목',
        requestedAt: DateTime.utc(2026, 10, 9),
        authCode: '0123',
        courseKey: testCourse.key,
      );
      expect(
        AttendanceRequestRecord.fromJson(record.toJson()).courseKey?.id,
        testCourse.key.id,
      );
      final old = record.toJson()
        ..remove('courseKey')
        ..remove('isUnconfirmed');
      expect(AttendanceRequestRecord.fromJson(old).courseKey, null);
      expect(AttendanceRequestRecord.fromJson(old).authCode, '0123');
    },
  );

  test(
    'provider deduplicates and caches detail requests until explicit refresh',
    () async {
      final service = _Service();
      final container = _container(service);
      container.listen(attendanceOverviewProvider, (_, _) {});
      final controller = container.read(attendanceOverviewProvider.notifier);
      await controller.loadCourses();
      final first = controller.loadDetail(testCourse);
      final second = controller.loadDetail(testCourse);
      expect(identical(first, second), true);
      await first;
      await controller.loadDetail(testCourse);
      expect(service.detailReads, 1);
      await controller.loadDetail(testCourse, refresh: true);
      expect(service.detailReads, 2);
      expect(service.courseReads, 1);
    },
  );

  test(
    'session recovery retries a read once and stops on repeated expiration',
    () async {
      final service = _Service()..expire = true;
      final home = _Home();
      final container = _container(service, home: home);
      container.listen(attendanceOverviewProvider, (_, _) {});
      await container.read(attendanceOverviewProvider.notifier).loadCourses();
      expect(home.recoveries, 1);
      expect(service.courseReads, 2);
      expect(container.read(attendanceOverviewProvider).courses.hasError, true);
    },
  );

  test('late response is discarded after account switch', () async {
    final pending = Completer<List<AttendanceCourse>>();
    final service = _Service()..pending = pending;
    final home = _Home();
    final container = _container(service, home: home);
    container.listen(attendanceOverviewProvider, (_, _) {});
    final oldRequest = container
        .read(attendanceOverviewProvider.notifier)
        .loadCourses();
    home.show(const HomeState());
    await container.pump();
    pending.complete([testCourse]);
    await oldRequest;
    expect(container.read(attendanceOverviewProvider).courses.hasValue, false);
  });

  test(
    'attendance entry blocks school reads until the submission ends',
    () async {
      final service = _Service();
      final home = _Home();
      final container = _container(service, home: home);
      final attendance =
          container.read(attendanceProvider.notifier) as _Attendance;
      attendance.show(
        const AttendanceState(phase: AttendancePhase.enteringCode),
      );
      container.listen(attendanceOverviewProvider, (_, _) {});
      final controller = container.read(attendanceOverviewProvider.notifier);
      await controller.loadCourses();
      expect(service.courseReads, 0);
      expect(home.recoveries, 0);
      expect(container.read(attendanceOverviewProvider).courses.hasError, true);

      attendance.show(const AttendanceState());
      await controller.loadCourses(refresh: true);
      expect(service.courseReads, 1);
      expect(container.read(attendanceOverviewProvider).courses.hasValue, true);
    },
  );

  test(
    'late expiration after logout does not recover the old session',
    () async {
      final pending = Completer<List<AttendanceCourse>>();
      final service = _Service()..pending = pending;
      final home = _Home();
      final container = _container(service, home: home);
      container.listen(attendanceOverviewProvider, (_, _) {});
      final request = container
          .read(attendanceOverviewProvider.notifier)
          .loadCourses();
      home.show(const HomeState());
      await container.pump();
      pending.completeError(
        const AttendanceOverviewException('expired', sessionExpired: true),
      );
      await request;
      expect(home.recoveries, 0);
      expect(
        container.read(attendanceOverviewProvider).courses.hasValue,
        false,
      );
    },
  );

  test(
    'manual refresh keeps the previous courses until it completes',
    () async {
      final service = _Service();
      final container = _container(service);
      container.listen(attendanceOverviewProvider, (_, _) {});
      final controller = container.read(attendanceOverviewProvider.notifier);
      await controller.loadCourses();
      final pending = Completer<List<AttendanceCourse>>();
      service.pending = pending;
      final refresh = controller.loadCourses(refresh: true);
      final duringRefresh = container.read(attendanceOverviewProvider);
      expect(
        duringRefresh.courses.requireValue.single.key.id,
        testCourse.key.id,
      );
      expect(duringRefresh.refreshingCourses, true);
      pending.complete([]);
      await refresh;
      final completed = container.read(attendanceOverviewProvider);
      expect(completed.courses.requireValue, isEmpty);
      expect(completed.refreshingCourses, false);
    },
  );
}

ProviderContainer _container(_Service service, {_Home? home}) =>
    ProviderContainer.test(
      overrides: [
        homeControllerProvider.overrideWith(() => home ?? _Home()),
        attendanceProvider.overrideWith(_Attendance.new),
        attendanceOverviewServiceProvider.overrideWithValue(service),
      ],
    );

class _Home extends HomeController {
  int recoveries = 0;
  @override
  HomeState build() => const HomeState(isLoggedIn: true, userId: 'student');
  void show(HomeState value) => state = value;
  @override
  Future<bool> recoverAttendanceSession() async {
    recoveries++;
    return true;
  }
}

class _Attendance extends AttendanceController {
  @override
  AttendanceState build() => const AttendanceState();
  void show(AttendanceState value) => state = value;
}

class _Service extends AttendanceOverviewService {
  _Service() : super(_Transport(''));
  int courseReads = 0;
  int detailReads = 0;
  bool expire = false;
  Completer<List<AttendanceCourse>>? pending;
  @override
  Future<List<AttendanceCourse>> fetchCourses() async {
    courseReads++;
    if (expire) {
      throw const AttendanceOverviewException('expired', sessionExpired: true);
    }
    return pending == null ? [testCourse] : pending!.future;
  }

  @override
  Future<SchoolAttendanceDetail> fetchDetail(AttendanceCourse course) async {
    detailReads++;
    return AttendanceOverviewService.parseDetail(publishedHtml, course);
  }
}

class _Transport implements SchoolHttpTransport {
  _Transport(this.body, {this.status = 200});
  final String body;
  final int status;
  String? target;
  Object? payload;
  SchoolRequestOptions? options;
  @override
  Future<Response<T>> get<T>(
    String target, {
    Map<String, dynamic>? queryParameters,
    SchoolRequestOptions options = const SchoolRequestOptions(),
  }) async {
    this.target = target;
    this.options = options;
    return Response<T>(
      data: body as T,
      statusCode: status,
      requestOptions: RequestOptions(path: target),
    );
  }

  @override
  Future<Response<T>> post<T>(
    String target, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    SchoolRequestOptions options = const SchoolRequestOptions(),
  }) {
    payload = data;
    return get<T>(target, options: options);
  }
}
