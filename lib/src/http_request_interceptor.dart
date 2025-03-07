// Copyright (c) 2025, the Dart project authors. Use of this source code
// is governed by a MIT license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:math' as Math;
import 'package:http_interceptor/http_interceptor.dart';
import 'http_error.dart';
import 'router_helper.dart';

class HttpRequestInterceptor implements InterceptorContract {
  bool silent = false;
  String requestId = "";

  @override
  FutureOr<BaseRequest> interceptRequest({required BaseRequest request}) async {
    Request requestData = request as Request;
    try{
      request.headers["Content-Type"] = !_isJsonStr(request.body) && _isKeyValueQuery(request.body) ? "application/x-www-form-urlencoded" : "application/json";
      request = await naiveInterceptRequest(dataObj: requestData);
    }catch(e) {
      print("Exception Caught! $e");
    }
    return request;
  }

  @override
  FutureOr<BaseResponse> interceptResponse({required BaseResponse response}) async {
    return naiveInterceptResponse(responseObj: response);
  }

  Future<dynamic> naiveInterceptRequest({BaseRequest? requestObj, Request? dataObj}) async {
    dynamic request = requestObj ?? dataObj;
    request.headers["charset"] = "UTF-8";
    // symbol silent == true means no underMaintenance and unauthorized login implied by response
    silent = request.headers["_SILENT_"] != null && request.headers["_SILENT_"] == "true";
    request.headers.remove("_SILENT_");
    // unique request id
    requestId = request.headers["X-Request-Id"] ?? request.headers["_REQUEST_ID_"] ?? "";
    request.headers.remove("_REQUEST_ID_");

    print("in interceptRequest[$requestId]${silent ? '[silent]' : ''}[${request?.url}] ====> Headers: ${request.toString()} \n Body: ${request is MultipartRequest ? request.headers : request?.body }");
    return request;
  }

  dynamic naiveInterceptResponse({BaseResponse? responseObj, Response? dataObj}) {
    // statusCode 200 401 .etc
    dynamic response = responseObj ?? dataObj;
    try{
      // read/readBytes method directly return response
      utf8.decode(response.bodyBytes);
    }catch(e) {
      return response;
    }

    String bodyUtf8Decoded = utf8.decode(response.bodyBytes);
    print("in interceptResponse[$requestId]${silent ? '[silent]' : ''}[${response?.request?.url}] ====> statusCode: ${response.statusCode} Body: $bodyUtf8Decoded");

    if (response.statusCode == 200 && _isJsonStr(bodyUtf8Decoded)) {
      var responseObj = json.decode(bodyUtf8Decoded);
      if (responseObj != null && responseObj is! List && responseObj?["code"] == RouterHelper.maintenanceCode && RouterHelper.maintenanceCode != null) {
        print("[silent: $silent] Gonna jump to maintenance page ... ");
        !silent ? RouterHelper.underMaintenance() : null;
        throw HttpError(responseObj["code"], responseObj["message"] ?? "Briefly Unavailable for Scheduled Maintenance. Check Back in a Minute!");
      }
      if (responseObj != null && responseObj is! List && (RouterHelper.unAuthCode as List<int>).contains(responseObj?["code"])){
        print("[silent: $silent] Gonna jump to login page ... ");
        !silent ? RouterHelper.unAuth(code: responseObj?["code"]) : null;
        throw HttpError(responseObj["code"], responseObj["message"] ?? "Unauthorized Error");
      }
      return response;
    } else if (response.statusCode == 200 && !_isJsonStr(bodyUtf8Decoded)) {
      String description = bodyUtf8Decoded.isNotEmpty ? bodyUtf8Decoded.substring(0, Math.min(55, bodyUtf8Decoded.length)).replaceAll("\n", "\t") : "Bad request, try it later! ";
      throw HttpError(HttpError.RESPONSE_FORMAT_ERROR, description);
    } else if (response.statusCode == RouterHelper.unAuthStatusCode) {
      print("[silent: $silent] Gonna jump to login page ... ");
      !silent ? RouterHelper.unAuth(statusCode: response.statusCode) : null;
      throw HttpError(response.statusCode, "Unauthorized Error");
    }
    String description = bodyUtf8Decoded.length > 100 ? "Bad request, try it later! " : bodyUtf8Decoded;
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