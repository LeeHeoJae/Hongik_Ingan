import 'dart:async';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hongik_ingan/core/network/school_request_options.dart';
import 'package:hongik_ingan/core/network/school_transport.dart';
import 'package:hongik_ingan/core/network/school_transport_provider.dart';
import 'package:hongik_ingan/features/seat/application/seat_controller.dart';
import 'package:hongik_ingan/features/seat/domain/seat.dart';

void main() {
  for (final fails in [false, true]) {
    test(
      'completion after disposal does not access state (fails: $fails)',
      () async {
        final transport = _FakeSchoolTransport(holdRequests: true);
        final container = ProviderContainer.test(
          overrides: [schoolTransportProvider.overrideWithValue(transport)],
        );
        final request = container
            .read(seatControllerProvider.notifier)
            .fetchSelectedStatus();
        container.dispose();
        transport.completePendingRequest(fails: fails);
        await expectLater(request, completes);
      },
    );

    test(
      'old completion cannot clear a rebuilt request (fails: $fails)',
      () async {
        final oldTransport = _FakeSchoolTransport(holdRequests: true);
        final newTransport = _FakeSchoolTransport(holdRequests: true);
        final container = ProviderContainer.test(
          overrides: [schoolTransportProvider.overrideWithValue(oldTransport)],
        );
        final controller = container.read(seatControllerProvider.notifier);
        final oldRequest = controller.fetchSelectedStatus();
        container.updateOverrides([
          schoolTransportProvider.overrideWithValue(newTransport),
        ]);
        await container.pump();
        expect(
          container.read(seatControllerProvider.notifier),
          same(controller),
        );
        final newRequest = controller.fetchSelectedStatus();
        oldTransport.completePendingRequest(fails: fails);
        await oldRequest;
        expect(container.read(seatControllerProvider).statuses, isEmpty);
        expect(
          container.read(seatControllerProvider).isSelectedLocationLoading,
          isTrue,
        );
        newTransport.completePendingRequest();
        await newRequest;
        expect(container.read(seatControllerProvider).status, isNotNull);
        expect(container.read(seatControllerProvider).error, isNull);
        expect(container.read(seatControllerProvider).isLoading, isFalse);
      },
    );
  }

  test(
    'concurrent buildings preserve each other when completed in reverse order',
    () async {
      final transport = _FakeSchoolTransport(holdRequests: true);
      final container = ProviderContainer.test(
        overrides: [schoolTransportProvider.overrideWithValue(transport)],
      );
      final controller = container.read(seatControllerProvider.notifier);
      final first = controller.fetchStatusForLocation(SeatLocation.tBuilding);
      final second = controller.fetchStatusForLocation(SeatLocation.rBuilding);
      transport.completePendingRequest(index: 1);
      await second;
      expect(container.read(seatControllerProvider).loadingLocations, {
        SeatLocation.tBuilding,
      });
      transport.completePendingRequest();
      await first;
      final state = container.read(seatControllerProvider);
      expect(
        state.statuses.keys,
        containsAll([SeatLocation.tBuilding, SeatLocation.rBuilding]),
      );
      expect(state.selectedLocation, SeatLocation.tBuilding);
      expect(state.isLoading, isFalse);
    },
  );

  test('보조 카드의 T동 조회는 상세 화면의 선택 건물을 유지한다', () async {
    final transport = _FakeSchoolTransport();
    final container = ProviderContainer.test(
      overrides: [schoolTransportProvider.overrideWithValue(transport)],
    );
    addTearDown(container.dispose);
    final controller = container.read(seatControllerProvider.notifier);
    controller.selectLocation(SeatLocation.rBuilding);
    await controller.fetchSelectedStatus();
    await controller.fetchStatusForLocation(SeatLocation.tBuilding);
    expect(transport.targets, [
      'http://223.194.83.66/',
      'http://203.249.65.81/',
    ]);
    expect(
      container.read(seatControllerProvider).selectedLocation,
      SeatLocation.rBuilding,
    );
    expect(
      container.read(seatControllerProvider).statuses.keys,
      containsAll([SeatLocation.rBuilding, SeatLocation.tBuilding]),
    );
  });

  test('자동 조회는 선택 건물만 캐시 허용으로 요청하고 수동 갱신은 재검증한다', () async {
    final transport = _FakeSchoolTransport();
    final container = ProviderContainer.test(
      overrides: [schoolTransportProvider.overrideWithValue(transport)],
    );
    addTearDown(container.dispose);
    final controller = container.read(seatControllerProvider.notifier);

    await controller.fetchSelectedStatus();

    expect(transport.targets, ['http://203.249.65.81/']);
    expect(transport.options.single.cacheMode, NetworkCacheMode.preferCache);

    controller.selectLocation(SeatLocation.rBuilding);
    await controller.fetchSelectedStatus();

    expect(transport.targets, [
      'http://203.249.65.81/',
      'http://223.194.83.66/',
    ]);
    expect(transport.options.last.cacheMode, NetworkCacheMode.preferCache);

    await controller.refresh();

    expect(transport.targets.last, 'http://223.194.83.66/');
    expect(transport.options.last.cacheMode, NetworkCacheMode.revalidate);
  });

  test('선택 건물의 진행 중 요청은 공유한다', () async {
    final transport = _FakeSchoolTransport(holdRequests: true);
    final container = ProviderContainer.test(
      overrides: [schoolTransportProvider.overrideWithValue(transport)],
    );
    addTearDown(container.dispose);
    final controller = container.read(seatControllerProvider.notifier);

    final first = controller.fetchSelectedStatus();
    final second = controller.fetchSelectedStatus();

    expect(transport.targets, ['http://203.249.65.81/']);

    transport.completePendingRequest();
    await Future.wait([first, second]);

    expect(transport.targets, hasLength(1));
  });

  test('이전 정보 갱신 재시도 중에는 오류를 유지하고 성공 후 지운다', () async {
    final transport = _FakeSchoolTransport();
    final container = ProviderContainer.test(
      overrides: [schoolTransportProvider.overrideWithValue(transport)],
    );
    addTearDown(container.dispose);
    final controller = container.read(seatControllerProvider.notifier);

    await controller.fetchSelectedStatus();
    final previousStatus = container.read(seatControllerProvider).status;
    expect(previousStatus, isNotNull);

    transport.failRequests = true;
    await controller.refresh();

    final failedState = container.read(seatControllerProvider);
    expect(failedState.status, same(previousStatus));
    expect(failedState.error, isNotNull);

    transport
      ..failRequests = false
      ..holdRequests = true;
    final retry = controller.refresh();

    final retryingState = container.read(seatControllerProvider);
    expect(retryingState.isSelectedLocationLoading, isTrue);
    expect(retryingState.status, same(previousStatus));
    expect(retryingState.error, failedState.error);

    transport.completePendingRequest();
    await retry;

    final recoveredState = container.read(seatControllerProvider);
    expect(recoveredState.isSelectedLocationLoading, isFalse);
    expect(recoveredState.error, isNull);
  });
}

class _FakeSchoolTransport implements SchoolTransport {
  _FakeSchoolTransport({this.holdRequests = false});

  bool holdRequests;
  bool failRequests = false;
  final List<String> targets = [];
  final List<SchoolRequestOptions> options = [];
  final _pendingRequests =
      <({String target, Completer<Response<List<int>>> response})>[];

  @override
  Future<Response<T>> get<T>(
    String target, {
    Map<String, dynamic>? queryParameters,
    SchoolRequestOptions options = const SchoolRequestOptions(),
  }) {
    targets.add(target);
    this.options.add(options);
    if (failRequests) {
      return Future.error(
        DioException(
          requestOptions: RequestOptions(path: target),
          message: 'request failed',
        ),
      );
    }
    if (holdRequests) {
      final response = Completer<Response<List<int>>>();
      _pendingRequests.add((target: target, response: response));
      return response.future.then((response) => response as Response<T>);
    }
    return Future.value(_response(target) as Response<T>);
  }

  void completePendingRequest({int index = 0, bool fails = false}) {
    final pending = _pendingRequests.removeAt(index);
    if (fails) {
      pending.response.completeError(
        DioException(requestOptions: RequestOptions(path: pending.target)),
      );
    } else {
      pending.response.complete(_response(pending.target));
    }
  }

  Response<List<int>> _response(String target) {
    const html = '''
      <table>
        <tr>
          <td class="table_title">&#50676;&#46988;&#49892;&#47749;</td>
          <td class="table_title">&#51204;&#52404;&#51340;&#49437;</td>
          <td class="table_title">&#49324;&#50857;&#51340;&#49437;</td>
          <td class="table_title">&#51092;&#50668;&#51340;&#49437;</td>
          <td class="table_title">&#51060;&#50857;&#47456;</td>
        </tr>
        <tr><td>&#44228;</td><td>10</td><td>4</td><td>6</td><td>40%</td></tr>
      </table>
    ''';
    return Response<List<int>>(
      data: html.codeUnits,
      statusCode: 200,
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
    throw UnimplementedError();
  }

  @override
  Future<void> clearAuthSession() async {}

  @override
  Future<bool> hasAuthSession() async => false;

  @override
  Future<bool> hasCookie(Uri target, String name) async => false;

  @override
  Future<void> saveAuthCookies(List<Cookie> cookies) async {}
}
