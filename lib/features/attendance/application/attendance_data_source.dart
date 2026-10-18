import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hongik_ingan/core/network/school_request_options.dart';
import 'package:hongik_ingan/core/network/school_transport.dart';
import 'package:hongik_ingan/core/network/school_transport_provider.dart';

import '../data/attendance_history_repository.dart';

class AttendanceDataSource {
  const AttendanceDataSource({
    required this.transport,
    required this.locationProvider,
    required this.historyRepository,
  });

  final SchoolHttpTransport transport;
  final Future<Position> Function() locationProvider;
  final AttendanceHistoryRepository historyRepository;
}

final attendanceDataSourceOverrideProvider =
    NotifierProvider<AttendanceDataSourceOverride, AttendanceDataSource?>(
      AttendanceDataSourceOverride.new,
    );

class AttendanceDataSourceOverride extends Notifier<AttendanceDataSource?> {
  @override
  AttendanceDataSource? build() => null;

  void setSource(AttendanceDataSource? source) => state = source;
}

/// Resolve the source per request without rebuilding the attendance controller.
final attendanceTransportProvider = Provider<SchoolHttpTransport>(
  (ref) => _AttendanceTransport(
    ref.watch(schoolTransportProvider),
    () => ref.read(attendanceDataSourceOverrideProvider)?.transport,
  ),
);

class _AttendanceTransport implements SchoolHttpTransport {
  const _AttendanceTransport(this.realTransport, this.selectedTransport);

  final SchoolHttpTransport realTransport;
  final SchoolHttpTransport? Function() selectedTransport;

  @override
  Future<Response<T>> get<T>(
    String target, {
    Map<String, dynamic>? queryParameters,
    SchoolRequestOptions options = const SchoolRequestOptions(),
  }) => (selectedTransport() ?? realTransport).get<T>(
    target,
    queryParameters: queryParameters,
    options: options,
  );

  @override
  Future<Response<T>> post<T>(
    String target, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    SchoolRequestOptions options = const SchoolRequestOptions(),
  }) => (selectedTransport() ?? realTransport).post<T>(
    target,
    data: data,
    queryParameters: queryParameters,
    options: options,
  );
}
