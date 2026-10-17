import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hongik_ingan/core/network/school_transport.dart';
import 'package:hongik_ingan/core/network/school_transport_native.dart';
import 'package:hongik_ingan/core/network/school_transport_web.dart';

void main() {
  for (final web in [true, false]) {
    test(
      'vote verification exposes only the attendance session and clears on logout (web=$web)',
      () async {
        final attendance = Uri.parse('https://at.hongik.ac.kr/index.jsp');
        final portal = Uri.parse('https://my.hongik.ac.kr/');
        final dio = Dio();
        addTearDown(dio.close);
        late SchoolTransport transport;
        if (web) {
          final store = WebAuthCookieStore();
          store.save(
            attendance,
            Cookie('JSESSIONID', 'attendance-session')..path = '/',
          );
          store.save(attendance, Cookie('SSO', 'private-sso')..path = '/');
          store.save(
            portal,
            Cookie('JSESSIONID', 'portal-session')..path = '/',
          );
          transport = SchoolTransportWeb(dio, store);
        } else {
          final jar = CookieJar();
          await jar.saveFromResponse(attendance, [
            Cookie('JSESSIONID', 'attendance-session')..path = '/',
            Cookie('SSO', 'private-sso')..path = '/',
          ]);
          await jar.saveFromResponse(portal, [
            Cookie('JSESSIONID', 'portal-session')..path = '/',
          ]);
          transport = SchoolTransportNative(dio, jar);
        }
        final sessions = transport as SchoolVoteSessionStore;
        expect(await sessions.readVoteSession(), 'attendance-session');
        await transport.clearAuthSession();
        expect(await sessions.readVoteSession(), isNull);
      },
    );
  }
}
