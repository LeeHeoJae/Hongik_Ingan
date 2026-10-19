import 'dart:async';
import 'package:hongik_ingan/features/home/domain/session_recovery_result.dart';
import 'dart:convert';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hongik_ingan/core/network/school_request_options.dart';
import 'package:hongik_ingan/core/network/school_transport.dart';
import 'package:hongik_ingan/core/network/school_transport_provider.dart';
import 'package:hongik_ingan/core/time/campus_clock.dart';
import 'package:hongik_ingan/features/app_install/application/app_install_controller.dart';
import 'package:hongik_ingan/features/app_install/domain/app_install_state.dart';
import 'package:hongik_ingan/features/attendance/application/attendance_controller.dart';
import 'package:hongik_ingan/features/attendance/application/attendance_data_source.dart';
import 'package:hongik_ingan/features/attendance/application/attendance_history_provider.dart';
import 'package:hongik_ingan/features/attendance/data/attendance_history_repository.dart';
import 'package:hongik_ingan/features/attendance/debug/attendance_test_environment.dart';
import 'package:hongik_ingan/features/attendance/domain/attendance_request_record.dart';
import 'package:hongik_ingan/features/home/application/home_controller.dart';
import 'package:hongik_ingan/features/home/domain/login_result.dart';
import 'package:hongik_ingan/features/home/presentation/widgets/home_splash_brand.dart';

class AttendanceTestHost {
  AttendanceTestHost({Duration latency = Duration.zero, bool loggedIn = true}) {
    container = ProviderContainer(
      overrides: [
        schoolTransportProvider.overrideWithValue(realTransport),
        attendancePersistentHistoryRepositoryProvider.overrideWithValue(
          realHistory,
        ),
        attendanceTestLatencyProvider.overrideWithValue(latency),
        homeControllerProvider.overrideWith(
          () => TestHomeController(loggedIn: loggedIn),
        ),
        appInstallControllerProvider.overrideWith(_InstallController.new),
        campusClockProvider.overrideWithValue(() => sampleTime),
        homeSplashAnimationProvider.overrideWithValue(false),
      ],
    );
  }

  static const userId = 'ORIGINAL_USER';
  static final sampleTime = DateTime(2026, 10, 12, 10);
  final realTransport = TestSchoolTransport();
  final realHistory = TestHistoryRepository();
  late final ProviderContainer container;
  late AttendanceDataSource _source;
  AttendanceTestTransport get transport =>
      _source.transport as AttendanceTestTransport;
  AttendanceHistoryRepository get history => _source.historyRepository;

  Future<void> enable([
    AttendanceTestScenario scenario = AttendanceTestScenario.normal,
  ]) async {
    await container
        .read(attendanceTestControllerProvider.notifier)
        .enable(scenario);
    _source = container.read(attendanceDataSourceOverrideProvider)!;
  }

  Future<void> changeScenario(AttendanceTestScenario scenario) => container
      .read(attendanceTestControllerProvider.notifier)
      .changeScenario(scenario);

  void dispose() => container.dispose();
}

class TestHomeController extends HomeController {
  TestHomeController({this.loggedIn = true});

  final bool loggedIn;
  Completer<void>? loginGate;

  @override
  HomeState build() => loggedIn
      ? const HomeState(isLoggedIn: true, userId: AttendanceTestHost.userId)
      : const HomeState();

  void updateLoginOptions() => state = state.copyWith(rememberMe: true);
  @override
  Future<(String?, String?)> initializeApp() async => (null, null);
  @override
  Future<void> restoreInitialSession(String id, String pw) async {}
  @override
  Future<void> revalidateSessionOnResume(String id, String pw) async {}
  @override
  Future<SessionRecoveryResult> recoverAttendanceSession() async =>
      SessionRecoveryResult.temporarilyUnavailable;
  @override
  Future<LoginResult> login(
    String id,
    String pw, {
    bool isSessionRecovery = false,
  }) async {
    ref.read(attendanceProvider.notifier).resetSession();
    state = state.copyWith(
      isLoading: true,
      isLoggedIn: false,
      loginStatus: LoginStatus.loggingIn,
    );
    await loginGate?.future;
    state = state.copyWith(isLoading: false, isLoggedIn: true, userId: id);
    unawaited(
      ref.read(attendanceProvider.notifier).fetchLecture(forceRefresh: true),
    );
    return const LoginResult.success();
  }

  @override
  Future<void> logout() async {
    ref.read(attendanceProvider.notifier).resetSession();
    state = const HomeState();
  }

  void switchAccount() {
    ref.read(attendanceProvider.notifier).resetSession();
    state = const HomeState(isLoggedIn: true, userId: 'OTHER_USER');
  }
}

class _InstallController extends AppInstallController {
  @override
  AppInstallState build() => const AppInstallState(
    target: AppInstallTarget.notWeb,
    preferenceLoaded: true,
  );
}

class TestHistoryRepository extends AttendanceHistoryRepository {
  final records = <String, List<AttendanceRequestRecord>>{};
  int writes = 0;
  @override
  Future<List<AttendanceRequestRecord>> load(String userId) async =>
      List.unmodifiable(records[userId] ?? []);
  @override
  Future<void> save(String userId, AttendanceRequestRecord record) async {
    writes++;
    final list = records.putIfAbsent(userId, () => []);
    list.removeWhere((old) => old.id == record.id);
    list.insert(0, record);
  }
}

class TestSchoolTransport implements SchoolTransport {
  final requests = <String>[];
  final attendance = AttendanceTestTransport(latency: Duration.zero);
  int get lectureRequests =>
      requests.where((target) => target.endsWith('index.jsp')).length;

  Response<T> _response<T>(String target, Object body) => Response<T>(
    data: body as T,
    statusCode: 200,
    requestOptions: RequestOptions(path: target),
  );

  @override
  Future<Response<T>> get<T>(
    String target, {
    Map<String, dynamic>? queryParameters,
    SchoolRequestOptions options = const SchoolRequestOptions(),
  }) async {
    requests.add(target);
    if (target == 'https://at.hongik.ac.kr/index.jsp') {
      final response = await attendance.get<String>(target);
      return _response(
        target,
        response.data!.replaceAll('모바일 앱 프로그래밍', '실제 수업'),
      );
    }
    if (target == 'https://at.hongik.ac.kr/stud04.jsp') {
      return attendance.get<T>(target);
    }
    if (target.startsWith('http://')) {
      return _response(target, utf8.encode(_seatHtml));
    }
    if (target == 'https://apps.hongik.ac.kr/food/food_m.php') {
      final page = int.parse(queryParameters!['p'].toString());
      final date = AttendanceTestHost.sampleTime.add(Duration(days: page - 1));
      return _response(target, '''<table><tbody>
<tr><td class="title">${date.month}월 ${date.day}일</td></tr>
<tr><td class="time"><strong>기숙사 식당</strong></td></tr>
<tr><th>중식 11:30~14:00</th><td>현재 학식 메뉴</td></tr>
</tbody></table>''');
    }
    throw UnsupportedError(target);
  }

  @override
  Future<Response<T>> post<T>(
    String target, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    SchoolRequestOptions options = const SchoolRequestOptions(),
  }) {
    requests.add(target);
    return attendance.post<T>(target, data: data, options: options);
  }

  @override
  Future<void> saveAuthCookies(List<Cookie> cookies) async {}
  @override
  Future<bool> hasAuthSession() async => true;
  @override
  Future<bool> hasCookie(Uri target, String name) async => false;
  @override
  Future<void> clearAuthSession() async {}
}

const _seatHtml = '''<table><tr>
<td class="table_title">&#50676;&#46988;&#49892;&#47749;</td>
<td class="table_title">&#51204;&#52404;&#51340;&#49437;</td>
<td class="table_title">&#49324;&#50857;&#51340;&#49437;</td>
<td class="table_title">&#51092;&#50668;&#51340;&#49437;</td>
<td class="table_title">&#51060;&#50857;&#47456;</td></tr>
<tr><td>3&#52789; &#45432;&#53944;&#48513;&#50676;&#46988;&#49892;</td>
<td>100</td><td>40</td><td>60</td><td>40%</td></tr>
<tr><td>&#44228;</td><td>100</td><td>40</td><td>60</td><td>40%</td></tr></table>''';
