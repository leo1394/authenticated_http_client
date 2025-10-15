import 'dart:async';
import 'dart:convert';
import 'dart:core';

// String method, String uu, String headers {FormData? parameters, Options? options}
class HttpRequestTask {
  final String method;
  final String uu;
  final Map<String, dynamic>? params;
  final Map<String, String>? headers;
  final Encoding? encoding;
  final Map<String, String>? formFields;
  final bool silent;
  final bool authenticate;
  final int? timeoutSecs;
  final String? requestId;
  final String? savePath;
  final Completer<dynamic> completer;
  final void Function(int received, int total)? onReceiveProgress;

  HttpRequestTask(this.completer, this.method, this.uu, this.headers,
      {this.params,
      this.encoding,
      this.formFields,
      this.timeoutSecs,
      this.requestId,
      this.onReceiveProgress,
      this.savePath = "",
      this.authenticate = true,
      this.silent = false});
}
