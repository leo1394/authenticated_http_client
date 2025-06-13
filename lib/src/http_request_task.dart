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
  final int? timeoutSecs;
  final String? requestId;
  final Completer<dynamic> completer;

  HttpRequestTask(this.completer, this.method, this.uu, this.headers,
      {this.params,
      this.encoding,
      this.formFields,
      this.timeoutSecs,
      this.requestId,
      this.silent = false});
}
