import 'package:dio/dio.dart';

enum NetworkTimeoutProfile {
  standard, // 일반 요청
  seatStatus, // 열람실 좌석 현황
  sessionCheck, // 세션 확인.
  loginPage, // 로그인 페이지 요청
  loginPost, // 로그인 시도
  attendanceSession, // 출결 세션
  lectureFetch, // 강의 Fetch
  attendanceSubmit, // 출석 번호 제출
}

enum NetworkCacheMode { preferCache, revalidate }

class SchoolRequestOptions {
  const SchoolRequestOptions({
    this.timeoutProfile = NetworkTimeoutProfile.standard,
    this.headers = const {},
    this.contentType,
    this.responseType,
    this.followRedirects,
    this.validateStatus,
    this.cacheMode = NetworkCacheMode.preferCache,
    this.cacheDay,
  });

  final NetworkTimeoutProfile timeoutProfile;
  final Map<String, dynamic> headers;
  final String? contentType;
  final ResponseType? responseType;
  final bool? followRedirects;
  final ValidateStatus? validateStatus;
  final NetworkCacheMode cacheMode;
  final String? cacheDay;
}
