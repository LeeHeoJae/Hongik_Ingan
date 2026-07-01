import 'school_transport.dart';
import 'school_transport_native.dart'
    if (dart.library.html) 'school_transport_web.dart'
    as platform;

Future<SchoolTransport> createSchoolTransport() {
  return platform.createSchoolTransport();
}
