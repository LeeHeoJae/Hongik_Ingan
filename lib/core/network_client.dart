import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter/foundation.dart';

class NetworkClient {
  static final NetworkClient instance = NetworkClient._internal();

  factory NetworkClient() => instance;

  late Dio dio;
  late CookieJar cookieJar;

  NetworkClient._internal() {
    cookieJar = CookieJar();
    dio = Dio(
      BaseOptions(
        connectTimeout: Duration(seconds: 5),
        receiveTimeout: Duration(seconds: 5),
        headers: {
          'Accept': '*/*',
          'Connection': 'keep-alive',
          'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
          'Origin': 'https://my.hongik.ac.kr',
          'Referer': 'https://my.hongik.ac.kr/',
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36',
        },
      ),
    );
    dio.interceptors.add(CookieManager(cookieJar));
    if (kDebugMode) {
      dio.interceptors.add(
        LogInterceptor(
          requestBody: true,
          responseBody: true,
          responseHeader: true,
        ),
      );
    }
  }
}
