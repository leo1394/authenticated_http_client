// Copyright (c) 2025, the Dart project authors. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'package:http_interceptor/http_interceptor.dart';

/// Abstract Class HttpHeadersInterceptor
/// extends InterceptorContract, allowing custom logic setting headers for
/// authenticated Http Client AJAX requests.
abstract class HttpHeadersInterceptor extends InterceptorContract {

  /// function intercepts headers for Http Client AJAX requests.
  Map<String, String> headersInterceptor(Map<String, String> headers);

  @override
  Future<RequestData> interceptRequest({required RequestData data}) async {
    RequestData request = data;
    try{
      request.headers = headersInterceptor(request.headers);
    }catch(e, stackTrace) {}
    return request;
  }

  @override
  Future<ResponseData> interceptResponse({required ResponseData data}) async {
    return data;
  }
}