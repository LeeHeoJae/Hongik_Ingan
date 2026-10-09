import 'package:dio/dio.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html;
import 'package:hongik_ingan/core/network/attendance_session_response.dart';
import 'package:hongik_ingan/core/network/school_request_options.dart';
import 'package:hongik_ingan/core/network/school_transport.dart';
import '../domain/attendance_overview.dart';

class AttendanceOverviewException implements Exception {
  const AttendanceOverviewException(
    this.message, {
    this.sessionExpired = false,
    this.integrationError = false,
  });

  final String message;
  final bool sessionExpired;
  final bool integrationError;
  @override
  String toString() => message;
}

class AttendanceOverviewService {
  const AttendanceOverviewService(this.transport);
  final SchoolHttpTransport transport;
  static const _base = 'https://at.hongik.ac.kr/';
  static const _options = SchoolRequestOptions(
    timeoutProfile: NetworkTimeoutProfile.lectureFetch,
    responseType: ResponseType.plain,
    followRedirects: false,
    validateStatus: _acceptStatus,
    allowProxyRetry: false,
    headers: {'Referer': '${_base}stud04.jsp'},
  );

  static bool _acceptStatus(int? status) => status != null;

  Future<List<AttendanceCourse>> fetchCourses() async {
    try {
      final response = await transport.get<String>(
        '${_base}stud04.jsp',
        options: _options,
      );
      return _parseCoursesDocument(_validatedDocument(response));
    } on DioException {
      throw const AttendanceOverviewException('학교 출결 현황에 연결하지 못했어요.');
    }
  }

  Future<SchoolAttendanceDetail> fetchDetail(AttendanceCourse course) async {
    try {
      final response = await transport.post<String>(
        '${_base}stud05.jsp',
        data: course.key.toParams(),
        options: SchoolRequestOptions(
          timeoutProfile: _options.timeoutProfile,
          responseType: _options.responseType,
          followRedirects: false,
          validateStatus: _acceptStatus,
          allowProxyRetry: false,
          contentType: Headers.formUrlEncodedContentType,
          headers: _options.headers,
        ),
      );
      return _parseDetailDocument(_validatedDocument(response), course);
    } on DioException {
      throw const AttendanceOverviewException('학교 출결 현황에 연결하지 못했어요.');
    }
  }

  Document _validatedDocument(Response<String> response) {
    final body = response.data ?? '';
    final inspected = AttendanceSessionResponse(body);
    if (inspected.sessionExpired ||
        response.statusCode == 401 ||
        response.statusCode == 403 ||
        (response.statusCode != null &&
            response.statusCode! >= 300 &&
            response.statusCode! < 400)) {
      throw const AttendanceOverviewException(
        '학교 출결 세션이 만료됐어요. 다시 로그인해 주세요.',
        sessionExpired: true,
      );
    }
    if (inspected.integrationError) {
      throw const AttendanceOverviewException(
        '학교 출결 시스템 연동을 확인하지 못했어요.',
        integrationError: true,
      );
    }
    if (response.statusCode != 200 || body.trim().isEmpty) {
      throw const AttendanceOverviewException('학교 출결 현황을 불러오지 못했어요.');
    }
    return inspected.document;
  }

  static String _text(Element element) =>
      element.text.trim().replaceAll(RegExp(r'\s+'), ' ');

  static List<AttendanceCourse> parseCourses(String body) {
    return _parseCoursesDocument(html.parse(body));
  }

  static List<AttendanceCourse> _parseCoursesDocument(Document document) {
    final heading = document.querySelector('h4');
    final table = document.querySelector('table');
    if (heading == null ||
        _text(heading) != '수강과목 출결현황' ||
        table == null ||
        !table.text.contains('학수번호')) {
      throw const AttendanceOverviewException('수강과목 목록 형식을 확인하지 못했어요.');
    }
    final courses = <AttendanceCourse>[];
    for (final row in table.querySelectorAll('tbody > tr')) {
      final cells = row.querySelectorAll('td');
      if (cells.isEmpty) continue;
      if (cells.length == 1 &&
          RegExp(r'(없습니다|없어요)').hasMatch(_text(cells.single))) {
        continue;
      }
      if (cells.length != 4 ||
          row.querySelector('form[action="stud05.jsp"]') == null) {
        throw const AttendanceOverviewException('수강과목 정보를 확인하지 못했어요.');
      }
      // The school populates empty hidden fields from these cells on click.
      final term = RegExp(r'^(\d{4})-(.+)$').firstMatch(_text(cells[0]));
      final code = RegExp(r'^(\d+)-(\d+)$').firstMatch(_text(cells[2]));
      if (term == null || code == null || _text(cells[3]).isEmpty) {
        throw const AttendanceOverviewException('수강과목 식별 정보를 확인하지 못했어요.');
      }
      courses.add(
        AttendanceCourse(
          key: AttendanceCourseKey(
            year: term[1]!,
            semester: term[2]!,
            courseCode: code[1]!,
            section: code[2]!,
          ),
          name: _text(cells[3]),
          category: _text(cells[1]),
        ),
      );
    }
    return List.unmodifiable(courses);
  }

  static SchoolAttendanceDetail parseDetail(
    String body,
    AttendanceCourse course,
  ) {
    return _parseDetailDocument(html.parse(body), course);
  }

  static SchoolAttendanceDetail _parseDetailDocument(
    Document document,
    AttendanceCourse course,
  ) {
    final heading = document.querySelector('h4');
    if (heading == null || _text(heading) != '수강과목 출결현황 - ${course.name}') {
      throw const AttendanceOverviewException('선택한 과목의 출결 현황을 확인하지 못했어요.');
    }
    if (document.body?.text.contains('출석부가 공개되지 않았습니다.') == true) {
      return SchoolAttendanceDetail(course: course, isPublished: false);
    }
    final table = document.querySelector('table');
    final schedules =
        table
            ?.querySelectorAll('thead tr:first-child th[colspan="2"]')
            .map(_text)
            .toList() ??
        [];
    if (table == null || schedules.isEmpty || !table.text.contains('출결')) {
      throw const AttendanceOverviewException('학교 출결표 형식을 확인하지 못했어요.');
    }
    final entries = <SchoolAttendanceEntry>[];
    for (final row in table.querySelectorAll('tbody > tr')) {
      final cells = row.querySelectorAll('td');
      final week = cells.isEmpty ? null : int.tryParse(_text(cells[0]));
      if (week == null || cells.length != 1 + schedules.length * 2) {
        throw const AttendanceOverviewException('학교 출결표 내용을 확인하지 못했어요.');
      }
      for (var index = 0; index < schedules.length; index++) {
        entries.add(
          SchoolAttendanceEntry(
            week: week,
            schedule: schedules[index],
            lectureLabel: _text(cells[1 + index * 2]),
            status: _text(cells[2 + index * 2]),
          ),
        );
      }
    }
    return SchoolAttendanceDetail(
      course: course,
      isPublished: true,
      entries: List.unmodifiable(entries),
    );
  }
}
