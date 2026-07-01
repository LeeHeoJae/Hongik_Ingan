import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'school_transport.dart';

final schoolTransportProvider = Provider<SchoolTransport>((ref) {
  throw StateError('schoolTransportProvider must be overridden in main().');
});
