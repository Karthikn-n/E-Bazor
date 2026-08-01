import 'dart:developer';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class NetworkRequestInterseptor extends Interceptor {
  // Static so the counter is shared across all Dio instances
  static int _globalCallCount = 0;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (kDebugMode) {
      _globalCallCount++;
      final id = _globalCallCount;

      // Attach the ID to this request so we can use it in onResponse/onError
      options.extra['_req_id'] = id;

      final params = options.method == "POST"
          ? (options.data is FormData
              ? (options.data as FormData).fields
              : options.data)
          : options.queryParameters;

      log(
        '→ #$id ${options.method} ${options.path}'
        '${params != null && params.toString().isNotEmpty ? ' | params: $params' : ''}',
        name: 'API',
      );
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (kDebugMode) {
      final id = response.requestOptions.extra['_req_id'] ?? '?';
      final url = response.requestOptions.path;
      final status = response.statusCode;
      final hasError = response.data?['error'];
      final message = response.data?['message'];

      // Single summary line — always easy to find in logcat
      // log(
      //   '← #$id $status ${hasError == true ? "ERR" : "OK"} $url | $message',
      //   name: 'API',
      // );

      // Full body in labelled chunks so you always know which request it belongs to
      final body = response.data?.toString() ?? '';
      // We need to know full response to see what is actually happening in the response
      log("#$id | $status | $url | $body", name: "API-Res");
      // const chunkSize = 800;
      // for (var i = 0; i < body.length; i += chunkSize) {
      //   final end =
      //       (i + chunkSize < body.length) ? i + chunkSize : body.length;
      //   final chunk = i == 0 ? 1 : (i ~/ chunkSize) + 1;
      //   log(
      //     '#$id [$chunk] ${body.substring(i, end)}',
      //     name: 'API-Body',
      //   );
      // }
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (kDebugMode) {
      final id = err.requestOptions.extra['_req_id'] ?? '?';
      final url = err.requestOptions.path;
      log(
        '✗ #$id ${err.response?.statusCode ?? "net"} $url | ${err.message}',
        name: 'API-Error',
      );
    }
    handler.next(err);
  }
/*
  @override


  void onResponse(Response response, ResponseInterceptorHandler handler) {
    log({
      "URL": response.requestOptions.path,
      "Method": response.requestOptions.method,
      "status": response.statusCode,
      "statusMessage": response.statusMessage,
      "response": response.data,
    }.toString(),name: "Response-API");
    handler.next(response);
  }

 */
}
