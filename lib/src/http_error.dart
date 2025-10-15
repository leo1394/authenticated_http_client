// Copyright (c) 2025, the Dart project authors. Use of this source code
// is governed by a MIT license that can be found in the LICENSE file.

/// default enumerate error for http response
class HttpError extends Error {
  static const int RESPONSE_FORMAT_ERROR = 102;
  static const int UNAUTHORIZED = 401;
  static const int FORBIDDEN = 403;
  static const int NOT_FOUND = 404;
  static const int REQUEST_TIMEOUT = 408;
  static const int MULTIFILE_NOT_FOUND = 416;
  static const int INTERNAL_SERVER_ERROR = 500;
  static const int BAD_GATEWAY = 502;
  static const int SERVICE_UNAVAILABLE = 503;
  static const int GATEWAY_TIMEOUT = 504;
  static const Map<String, int> RuntimeTypeMapper = {
    "TimeoutException": GATEWAY_TIMEOUT,
    "_ClientSocketException": INTERNAL_SERVER_ERROR,
  };

  /// unknown error
  static const String UNKNOWN = "UNKNOWN";

  /// parse error
  static const String PARSE_ERROR = "PARSE_ERROR";

  /// network error
  static const String NETWORK_ERROR = "NETWORK_ERROR";

  /// http error
  static const String HTTP_ERROR = "HTTP_ERROR";

  /// ssl certificate error
  static const String SSL_ERROR = "SSL_ERROR";

  /// http request connect timeout error
  static const String CONNECT_TIMEOUT = "CONNECT_TIMEOUT";

  /// http response timeout error
  static const String RECEIVE_TIMEOUT = "RECEIVE_TIMEOUT";

  /// send in queuing timeout error
  static const String SEND_TIMEOUT = "SEND_TIMEOUT";

  /// cancel error
  static const String CANCEL = "CANCEL";

  int? code;
  String? message;
  HttpError(this.code, this.message);

  @override
  String toString() {
    String messageTmp = message ?? helper(errorType: code);
    return "[Error:$code] $messageTmp";
  }

  static String helper({int? errorType, Error? error}) {
    if (errorType == null && error == null) {
      return "";
    }
    String message = "Request failed, please try again later !";
    String type = "$errorType";
    if (errorType == null && error != null) {
      type = error is HttpError ? "${error.code}" : "${error.runtimeType}";
      message =
          error is HttpError ? error.message ?? message : error.toString();
      errorType ??= RuntimeTypeMapper[type];
    }
    switch (errorType) {
      case RESPONSE_FORMAT_ERROR:
        message = "Bad Response Format!";
        break;
      case MULTIFILE_NOT_FOUND:
        message = "Multipart file not found!";
        break;
      case BAD_GATEWAY:
        message = "Something wrong on Server!";
        break;
      case GATEWAY_TIMEOUT:
        message = "Request timed out, please checkout network connection!";
        break;
      case INTERNAL_SERVER_ERROR:
        message = "Internal Server Error!";
        break;
      case NOT_FOUND:
        message = "Bad Request uri not found!";
        break;
    }
    return "[Error:$type] $message";
  }
}
