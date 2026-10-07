import 'package:dio/dio.dart';

/// Keeps binary response bodies out of text logs without changing the response.
class SchoolLogInterceptor extends Interceptor {
  SchoolLogInterceptor({
    required bool responseHeader,
    required void Function(Object) logPrint,
  }) : _textLogger = LogInterceptor(
         requestBody: true,
         responseBody: true,
         responseHeader: responseHeader,
         logPrint: logPrint,
       ),
       _binaryLogger = LogInterceptor(
         requestBody: true,
         responseBody: false,
         responseHeader: responseHeader,
         logPrint: logPrint,
       );

  final LogInterceptor _textLogger;
  final LogInterceptor _binaryLogger;

  LogInterceptor _loggerFor(RequestOptions options) {
    return options.responseType == ResponseType.bytes ||
            options.responseType == ResponseType.stream
        ? _binaryLogger
        : _textLogger;
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    _textLogger.onRequest(options, handler);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    _loggerFor(response.requestOptions).onResponse(response, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _loggerFor(err.requestOptions).onError(err, handler);
  }
}
