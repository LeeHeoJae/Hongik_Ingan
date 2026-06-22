import 'package:flutter/foundation.dart';

import 'logging/logger.dart';

String webProxyUrl(String url, [Map<String, String>? queryParameters]) {
  if (!kIsWeb) {
    return url;
  }

  final targetUri = Uri.parse(url);
  final mergedQuery = <String, String>{
    ...targetUri.queryParameters,
    if (queryParameters != null) ...queryParameters,
  };
  final targetWithQuery = targetUri.replace(queryParameters: mergedQuery);
  logMsg(
    'Web proxy URL created: ${_safeUri(targetWithQuery)}',
    level: LogLevel.info,
  );

  return Uri(
    path: '/api/proxy',
    queryParameters: {'url': targetWithQuery.toString()},
  ).toString();
}

String _safeUri(Uri uri) {
  final redactedQuery = <String, String>{};
  for (final entry in uri.queryParameters.entries) {
    final key = entry.key.toLowerCase();
    redactedQuery[entry.key] = key.contains('pass') ||
            key.contains('pwd') ||
            key.contains('token') ||
            key.contains('key')
        ? '***'
        : entry.value;
  }
  return uri.replace(queryParameters: redactedQuery).toString();
}
