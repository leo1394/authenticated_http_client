// Copyright (c) 2025, the Dart project authors. Use of this source code
// is governed by a MIT license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:authenticated_http_client/authenticated_http_client.dart';
import 'package:http_interceptor/http_interceptor.dart';
import 'package:extension_dart/extensions.dart';
import 'http_error.dart';
import 'router_helper.dart';

/// inner HttpRequestInterceptor
class HttpRequestInterceptor implements InterceptorContract {
  Map<int, Map<String, dynamic>> sessionsCached = {};

  @override
  FutureOr<BaseRequest> interceptRequest({required BaseRequest request}) async {
    Request requestData = request as Request;
    try {
      request.headers["Content-Type"] =
          !_isJsonStr(request.body) && _isKeyValueQuery(request.body)
              ? "application/x-www-form-urlencoded"
              : "application/json";
      request = await naiveInterceptRequest(dataObj: requestData);
    } catch (e) {
      print("Exception Caught! $e");
    }
    return request;
  }

  @override
  FutureOr<BaseResponse> interceptResponse(
      {required BaseResponse response}) async {
    return naiveInterceptResponse(responseObj: response);
  }

  Future<dynamic> naiveInterceptRequest(
      {BaseRequest? requestObj, Request? dataObj}) async {
    dynamic request = requestObj ?? dataObj;
    request.headers["charset"] = "UTF-8";
    // symbol silent == true means no underMaintenance and unauthorized login implied by response
    // intercepted == true means intercepted by AuthenticatedHttpClient interceptResponse
    // unique id for each request
    sessionsCached[request.hashCode] = Map<String, dynamic>.from({
      "silent": request.headers["_SILENT_"] == "true",
      "requestId": request.headers["X-Request-Id"] ??
          request.headers["_REQUEST_ID_"] ??
          "",
      "intercepted": request.headers["_ICP_REQUEST_"] == "true"
    });
    request.headers.remove("_SILENT_");
    request.headers.remove("_ICP_REQUEST_");
    request.headers.remove("_REQUEST_ID_");
    final {
      "requestId": requestId,
      "silent": silent,
      "intercepted": intercepted
    } = sessionsCached[request.hashCode].destructure();
    if (!intercepted) {
      request.headers['X-Skip-Headers'] = 'true';
    }
    String bodyUtf8Decoded = request is MultipartRequest
        ? request.headers.toString()
        : utf8.decode(request?.bodyBytes);
    print(
        "in interceptRequest[$requestId]${silent ? '[silent]' : ''} ====> Headers: ${request.toString()} ${bodyUtf8Decoded.isNotEmpty ? 'Body: $bodyUtf8Decoded' : ''}");
    return request;
  }

  dynamic naiveInterceptResponse(
      {BaseResponse? responseObj, Response? dataObj}) {
    // statusCode 200 401 .etc
    dynamic response = responseObj ?? dataObj;
    try {
      // read/readBytes method directly return response
      utf8.decode(response.bodyBytes);
    } catch (e) {
      return response;
    }
    Map<String, dynamic>? cached =
        sessionsCached[responseObj?.request.hashCode];
    String requestId = (cached?["requestId"] ?? "-") as String;
    bool silent = (cached?["silent"] ?? false) as bool;
    bool intercepted = (cached?["intercepted"] ?? false) as bool;
    sessionsCached.remove(responseObj?.request.hashCode);

    String bodyUtf8Decoded = utf8.decode(response.bodyBytes);
    print(
        "in interceptResponse[$requestId]${silent ? '[silent]' : ''} ====> Headers: ${response?.request.toString()} statusCode: ${response.statusCode} Body: $bodyUtf8Decoded");

    if (intercepted &&
        response.statusCode == 200 &&
        _isJsonStr(bodyUtf8Decoded)) {
      var responseObj = json.decode(bodyUtf8Decoded);
      if (responseObj != null &&
          responseObj is! List &&
          responseObj?["code"] == RouterHelper.maintenanceCode &&
          RouterHelper.maintenanceCode != null) {
        print("[silent: $silent] Gonna jump to maintenance page ... ");
        !silent ? RouterHelper.underMaintenance() : null;
        throw HttpError(
            responseObj["code"],
            responseObj["message"] ??
                "Briefly Unavailable for Scheduled Maintenance. Check Back in a Minute!");
      }
      if (responseObj != null &&
          responseObj is! List &&
          RouterHelper.unAuthCode.contains(responseObj?["code"])) {
        print("[silent: $silent] Gonna jump to login page ... ");
        !silent ? RouterHelper.unAuth(code: responseObj?["code"]) : null;
        throw HttpError(responseObj["code"],
            responseObj["message"] ?? "Unauthorized Error");
      }

      if (responseObj != null &&
          responseObj is! List &&
          responseObj?["code"] != RouterHelper.successCode) {
        print("[silent: $silent] Gonna handle failed response ... ");
        ErrorHttpResponseInterceptorHandler? errorHandler =
            AuthenticatedHttpClient.getInstance().errorInterceptorHandler;
        errorHandler != null
            ? errorHandler(
                code: responseObj?["code"],
                message: responseObj?["message"],
                silent: silent)
            : null;
        throw HttpError(responseObj["code"],
            responseObj["message"] ?? "Failed Request Error");
      }
      return response;
    } else if (intercepted &&
        response.statusCode == 200 &&
        !_isJsonStr(bodyUtf8Decoded)) {
      String description = bodyUtf8Decoded.isNotEmpty
          ? bodyUtf8Decoded
              .substring(0, min(55, bodyUtf8Decoded.length))
              .replaceAll("\n", "\t")
          : "Bad request, try it later! ";
      throw HttpError(HttpError.RESPONSE_FORMAT_ERROR, description);
    } else if (intercepted &&
        response.statusCode == RouterHelper.unAuthStatusCode) {
      print("[silent: $silent] Gonna jump to login page ... ");
      !silent ? RouterHelper.unAuth(statusCode: response.statusCode) : null;
      throw HttpError(response.statusCode, "Unauthorized Error");
    } else if (!intercepted && response.statusCode == 200) {
      return response;
    } else if (!intercepted) {
      return response;
    }
    String description = bodyUtf8Decoded.length > 100
        ? "Bad request, try it later! "
        : bodyUtf8Decoded;
    throw HttpError(response.statusCode, description);
  }

  bool _isJsonStr(String str) {
    try {
      json.decode(str);
      return true;
    } catch (e) {
      return false;
    }
  }

  bool _isKeyValueQuery(String str) {
    final keyValuePairs = str.split('&');
    for (final pair in keyValuePairs) {
      final parts = pair.split('=');
      if (parts.length != 2) {
        return false;
      }
    }
    return true;
  }

  @override
  FutureOr<bool> shouldInterceptRequest() {
    return true;
  }

  @override
  FutureOr<bool> shouldInterceptResponse() {
    return true;
  }
}
