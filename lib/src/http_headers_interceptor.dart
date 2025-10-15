// Copyright (c) 2025, the Dart project authors. Use of this source code
// is governed by a MIT license that can be found in the LICENSE file.

import 'dart:async';
import 'package:http_interceptor/http_interceptor.dart';

/// Abstract Class HttpHeadersInterceptor
/// extends InterceptorContract, allowing custom logic setting headers for
/// authenticated Http Client AJAX requests.
abstract class HttpHeadersInterceptor extends InterceptorContract {
  /// function intercepts headers for Http Client AJAX requests.
  Map<String, String> headersInterceptor(Map<String, String> headers);

  @override
  FutureOr<BaseRequest> interceptRequest({required BaseRequest request}) async {
    try {
      // Check for the skip header interceptor
      if (request.headers['X-Skip-Headers'] == 'true') {
        request.headers.remove("X-Skip-Headers");
        print('Skipping headers InterceptRequest for ${request.url}');
        return request; // Skip processing, pass request unchanged
      }

      Map<String, String> headers = headersInterceptor(request.headers);
      for (var entry in headers.entries) {
        request.headers[entry.key] = entry.value;
      }
    } catch (e) {
      print("Exception Caught: $e");
    }
    return request;
  }

  @override
  FutureOr<BaseResponse> interceptResponse(
      {required BaseResponse response}) async {
    return response;
  }
}
