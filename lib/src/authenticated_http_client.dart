// Copyright (c) 2025, the Dart project authors. Use of this source code
// is governed by a MIT license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http_interceptor/http_interceptor.dart';
import 'package:universal_io/io.dart';
import 'package:extension_dart/utils.dart';
import 'http_error.dart';
import 'http_request_interceptor.dart';
import 'http_headers_interceptor.dart';
import 'http_request_task.dart';
import 'map_dot.dart';

/// Error handler for authenticated http request
typedef ErrorHttpResponseInterceptorHandler = void Function(
    {int? code,
    int? statusCode,
    bool silent,
    String? message,
    Exception? exception});

/// Example Usage
/// 1. AuthenticatedHttpClient.getInstance().init(url)
///    url some like "https://portal-api-test.company.com"
///
/// 2. var ajaxApis = AuthenticatedHttpClient.getInstance().factory({
///     "requestName"           : "POST /submit/plan",
///     "requestNameWithParams" : "POST /submit/plan/:id",
///     "mockRequest"           : "MOCK POST /api/task/config",
///     "silentRequest"         : "SILENT GET /api/message/check/unread"
///     });
///    ajaxApis.requestName().then().catchError().whenComplete()
///    ajaxApis.requestNameWithParams({"id": 9527}).then().catchError().whenComplete()
///
/// 3. AuthenticatedHttpClient.all(futures).then((List<dynamic> results){ /* print(results[0]) */}).catchError().whenComplete()
///
/// 4. AuthenticatedHttpClient.getInstance().get(uri).then().catchError().whenComplete()
///
class AuthenticatedHttpClient {
  static const String _authTokenCacheKey = "-cached-authorization";
  static String baseUrl = "";
  static String _host = "";
  static int _requestTimeout = 45; // timeout for http request in seconds
  static int _maxThrottlingNum = 10; // max throttling limit for requests
  static String _requestIdHeaderKey =
      "_REQUEST_ID_"; // inner request id in default
  Function? _responseHandler;
  String? _mockDirectory; // mock data directory
  final Queue<HttpRequestTask> _pendingRequestsOfThrottlingQueue = Queue();
  int _activeCount = 0;
  Map<String, Function> _httpMethodMapper = {};
  ErrorHttpResponseInterceptorHandler? _errorInterceptorHandler;
  final Future<SharedPreferences> _sharedPrefsFuture;
  late final http.Client _inner;
  bool _isInnerInitialized = false;

  AuthenticatedHttpClient._(this._sharedPrefsFuture);
  static final AuthenticatedHttpClient _instance =
      AuthenticatedHttpClient._(SharedPreferences.getInstance());

  factory AuthenticatedHttpClient.getInstance() => _instance;

  /// Initialize an authenticated HTTP client that adds a token as the `Authorization` header
  /// for every AJAX request afterwards.
  ///
  /// The `url` argument specifies base url of api service,
  /// which CAN NOT be empty
  ///
  /// The `responseHandler` optional argument specifies a custom Function for processing
  /// responses, such as logging, error handling, or modifying the response data.
  ///
  /// The `customHttpHeadersInterceptor` optional argument which implement
  /// HttpHeadersInterceptor specifies custom logic adding custom headers of all http request.
  ///
  /// The `mockDirectory` optional argument, defaulting to `/lib/mock`, specifies
  /// mocking json files' directory, which should be declared in pubspec.yaml under
  /// assets section.
  ///
  /// for example
  ///
  ///     flutter:
  ///        assets:
  ///          - lib/mock/       # for mock
  ///
  /// The timeoutSecs optional argument, defaulting to 45 seconds, specifies HTTP
  /// request timeout in seconds.
  ///
  void init(String origin,
      {Function? responseHandler,
      HttpHeadersInterceptor? customHttpHeadersInterceptor,
      ErrorHttpResponseInterceptorHandler? errorInterceptorHandler,
      String mockDirectory = "lib/mock",
      int maxThrottlingNum = 10,
      int? timeoutSecs,
      String? requestIdHeader}) {
    assert(origin.isNotEmpty, "url cannot be empty!");
    print("in AuthenticatedHttpClient base change to $origin ...");
    origin = origin.replaceAll(RegExp(r'\/$'), "");
    baseUrl = origin.startsWith('http://') || origin.startsWith('https://')
        ? origin
        : Uri.https(origin).origin;
    _host = Uri.parse(baseUrl).host;
    _maxThrottlingNum = maxThrottlingNum;

    if (!_isInnerInitialized) {
      List<InterceptorContract?> interceptors = [
        HttpRequestInterceptor(),
        customHttpHeadersInterceptor
      ];
      _responseHandler = responseHandler;
      _mockDirectory = mockDirectory;
      _requestTimeout = timeoutSecs ?? _requestTimeout;
      _errorInterceptorHandler = errorInterceptorHandler;
      _requestIdHeaderKey = (requestIdHeader == null || requestIdHeader.isEmpty)
          ? "_REQUEST_ID_"
          : requestIdHeader;
      _isInnerInitialized = true;
      _inner = InterceptedClient.build(
        interceptors: interceptors
            .where((inp) => inp != null)
            .cast<InterceptorContract>()
            .toList(),
        requestTimeout: Duration(seconds: _requestTimeout),
      );
    }
  }

  /// A factory function that generates AJAX request functions by api URI name in WYSIWYG style,
  /// Request name definition supporting `method` `silent` `mock`, and dynamic path parameters.
  /// FORMAT:  `Modifier(s) /path/of/api/supports/param`
  ///
  /// Modifiers can be METHOD(GET POST PUT DELETE DOWN UP HEAD PATCH .etc)、MOCK、SILENT,
  /// AJAX METHOD defaulting to GET.
  ///
  ///     "requestInDefault"      : "/api/get/something",
  ///     "requestName"           : "POST /api/submit/plan",
  ///     "requestNameWithParams" : "GET /api/plan/:id/details",
  ///     "mockRequest"           : "MOCK POST /api/task/config",
  ///     "silentRequest"         : "SILENT GET /api/message/check/unread"
  ///
  /// - Request name with dynamic path params support both :id and {id} type
  /// - Mock from _post_api_task_config.json under mockDirectory /lib/mock, which declared under assets section in pubspec.yaml
  /// - Silent requests won't jump when response met unauthorized or under maintenance
  ///
  /// AJAX request functions can be accessed using dot notation on Map.
  ///
  ///     var ajaxApis = AuthenticatedHttpClient.getInstance().factory({"requestName": "/path/of/api"});
  ///     ajaxApis.requestName().then().catchError().whenComplete();
  ///
  dynamic factory(Map<String, String> requests) {
    dynamic requestFncs = MapDot();
    _httpMethodMapper = {
      "get": get,
      "post": post,
      "head": head,
      "put": put,
      "delete": delete,
      "patch": patch,
      "read": read,
      "readBytes": readBytes,
      "up": upload,
      "upload": upload,
      "down": download,
      "download": download,
    };
    requests.forEach((requestName, requestUri) {
      var stripped = requestUri.replaceAll(RegExp(r"\s+"), " ").trim();
      var parts = stripped.split(" ").reversed.toList();
      var method = (parts.length == 1 ||
              !_httpMethodMapper.keys.contains(parts[1].toLowerCase()))
          ? "get"
          : parts[1];
      var mock =
          RegExp(r'(^|\s)mock\s', caseSensitive: false).hasMatch(stripped);
      var silent =
          RegExp(r'(^|\s)silent\s', caseSensitive: false).hasMatch(stripped);
      var uu = parts.first;
      Future fnc(Map<dynamic, dynamic>? paramsUnnamed,
          {Map<String, String>? headers,
          Encoding? encoding,
          Map<dynamic, dynamic>? params,
          Map<String, String>? formFields,
          int? timeoutSecs,
          String? requestId,
          bool authenticate = true,
          String savePath = "",
          void Function(int received, int total)? onReceiveProgress,
          bool throttling = false}) async {
        // support mock data, response for mock request
        if (mock) {
          String filename =
              "_${method}_${uu.replaceAll("/", "_").replaceAll(RegExp(r'[{:}]'), "")}"
                  .replaceAll("__", "_");
          String filepath = [_mockDirectory, "$filename.json"].join("/");
          dynamic response;
          try {
            response = await _readJsonFile(filepath);
          } catch (e) {
            if (filename.startsWith("_GET_")) {
              response = await _readJsonFile(filepath.replaceAll("_GET_", "_"));
            } else {
              throw http.ClientException('An unexpected error occurred: $e');
            }
          }

          print(
              "in interceptRequest ==> $baseUrl$uu, $params $paramsUnnamed \t MOCK response from local json file: $filepath, response ==> $response");
          return response;
        }
        // allow Map parameters in default Map<dynamic, dynamic>
        Map<String, dynamic>? paramsUnnamedFormatted =
            (paramsUnnamed == null || paramsUnnamed.isEmpty)
                ? <String, dynamic>{}
                : paramsUnnamed
                    .map((key, value) => MapEntry(key.toString(), value));
        // Map<String, dynamic>? paramsFormatted = (params == null || params.isEmpty) ? <String, dynamic>{}  : params.map((key, value) => MapEntry(key.toString(), value));
        if (throttling == false) {
          return _send(method, uu,
              headers: headers,
              params: paramsUnnamedFormatted,
              encoding: encoding,
              formFields: formFields,
              timeoutSecs: timeoutSecs,
              requestId: requestId,
              onReceiveProgress: onReceiveProgress,
              savePath: savePath,
              authenticate: authenticate,
              silent: silent);
        }

        // url parameters options
        final completer = Completer<dynamic>();
        final requestTask = HttpRequestTask(completer, method, uu, headers,
            params: paramsUnnamedFormatted,
            encoding: encoding,
            formFields: formFields,
            timeoutSecs: timeoutSecs,
            requestId: requestId,
            authenticate: authenticate,
            savePath: savePath,
            onReceiveProgress: onReceiveProgress,
            silent: silent);
        if (_activeCount < _maxThrottlingNum) {
          _sendThrottlingQueue(requestTask);
        } else {
          _pendingRequestsOfThrottlingQueue.addLast(requestTask);
        }
        return completer.future;
      }

      requestFncs[requestName] = fnc;
    });
    return requestFncs;
  }

  /// Setter for the authentication token in an Authenticated HTTP Client
  Future<void> setAuthToken(String token) async {
    SharedPreferences prefs = await _sharedPrefsFuture;
    prefs.setString(_authTokenCacheKey, token);
  }

  /// Getter for errorInterceptorHandler in an Authenticated HTTP Client
  ErrorHttpResponseInterceptorHandler? get errorInterceptorHandler =>
      _errorInterceptorHandler;

  /// A static function similar to Promise.all, which introduces a delay feature
  /// to prevent potential server concurrency issues
  ///
  /// The `futures` argument is a list Future requests
  ///
  /// The `anyCompleteCallback` optional argument specifies a custom Function for processing
  /// responses when any of `futures` requests completed
  ///
  /// The `anySuccessCallback` optional argument specifies a custom Function for processing
  /// responses when any of `futures` requests succeed
  ///
  /// The `anyErrorCallback` optional argument specifies a custom Function for processing
  /// responses when any of `futures` requests failed
  ///
  /// The `delayMillis` optional argument specifies a delay in milliseconds to prevent
  /// potential server concurrency issues. defaulting to `0`
  ///
  static Future<List<dynamic>> all(List<dynamic> futures,
      {Function? anyCompleteCallback,
      Function? anySuccessCallback,
      Function? anyErrorCallback,
      int delayMillis = 0}) {
    int taskCompleted = 0;
    Map<String, dynamic> results = {};
    var completer = Completer<List<dynamic>>();
    for (int i = 0; i < futures.length; i++) {
      futures[i].then((resp) {
        results[i.toString()] = resp;
        try {
          anySuccessCallback?.call(resp, results);
        } catch (e) {
          print("Exception Caught! $e");
        }
      }).catchError((e, stackTrace) {
        try {
          anyErrorCallback?.call(e, stackTrace);
        } catch (e) {
          print("Exception Caught! $e");
        }
      }).whenComplete(() {
        taskCompleted++;
        try {
          anyCompleteCallback?.call(results);
        } catch (e, stackTrace) {
          print("exception caught: $e \n $stackTrace");
        }
        if (taskCompleted >= futures.length) {
          completer.complete(
              List.generate(futures.length, (i) => results[i.toString()]));
        }
      });
      delayMillis >= 0
          ? sleep(Duration(milliseconds: delayMillis))
          : null; // Sleep for some milliseconds
    }
    return completer.future;
  }

  /// Note: http interceptors do not support send method currently.
  /// refer to https://pub.dev/documentation/http_interceptor/latest/http_intercepted_client/InterceptedClient-class.html
  /// so, we need to override ajax kinds of AJAX methods function.

  /// Sends an HTTP GET request with the given headers and body to the given URL.
  Future<http.Response> get(Uri url,
      {Map<String, String>? headers, bool authenticate = false}) async {
    var authHeaders = authenticate ? await _auth(headers) : headers;
    authHeaders ??= <String, String>{};
    return _inner.get(url, headers: authHeaders);
  }

  /// Sends an HTTP POST request with the given headers and body to the given URL.
  Future<http.Response> post(Uri url,
      {Map<String, String>? headers,
      Object? body,
      Encoding? encoding,
      bool authenticate = false}) async {
    var authHeaders = authenticate ? await _auth(headers) : headers;
    authHeaders ??= <String, String>{};
    // {"content-type": "application/json"}  jsonEncode(body) body accepted as String
    // {"content-type": "application/x-www-form-urlencoded"} body accepted as Map
    Object? bodyFormatted = authHeaders["content-type"]?.toLowerCase() ==
            "application/x-www-form-urlencoded"
        ? body
        : jsonEncode(body);
    return _inner.post(url,
        headers: authHeaders, body: bodyFormatted, encoding: encoding);
  }

  /// Sends an HTTP PUT request with the given headers and body to the given URL.
  Future<http.Response> put(Uri url,
      {Map<String, String>? headers,
      Object? body,
      Encoding? encoding,
      bool authenticate = false}) async {
    var authHeaders = authenticate ? await _auth(headers) : headers;
    authHeaders ??= <String, String>{};
    // {"content-type": "application/json"}  jsonEncode(body) body accepted as String
    // {"content-type": "application/x-www-form-urlencoded"} body accepted as Map
    Object? bodyFormatted = authHeaders["content-type"]?.toLowerCase() ==
            "application/x-www-form-urlencoded"
        ? body
        : jsonEncode(body);
    return _inner.put(url,
        headers: authHeaders, body: bodyFormatted, encoding: encoding);
  }

  /// Sends an HTTP DELETE request with the given headers and body to the given URL.
  Future<http.Response> delete(Uri url,
      {Map<String, String>? headers,
      Object? body,
      Encoding? encoding,
      bool authenticate = false}) async {
    var authHeaders = authenticate ? await _auth(headers) : headers;
    authHeaders ??= <String, String>{};
    return _inner.delete(url,
        headers: authHeaders, body: body, encoding: encoding);
  }

  /// Sends an HTTP PATCH request with the given headers and body to the given URL.
  Future<http.Response> patch(Uri url,
      {Map<String, String>? headers,
      Object? body,
      Encoding? encoding,
      bool authenticate = false}) async {
    var authHeaders = authenticate ? await _auth(headers) : headers;
    authHeaders ??= <String, String>{};
    // {"content-type": "application/json"}  jsonEncode(body) body accepted as String
    // {"content-type": "application/x-www-form-urlencoded"} body accepted as Map
    Object? bodyFormatted = authHeaders["content-type"]?.toLowerCase() ==
            "application/x-www-form-urlencoded"
        ? body
        : jsonEncode(body);
    return _inner.patch(url,
        headers: authHeaders, body: bodyFormatted, encoding: encoding);
  }

  /// Sends an HTTP HEAD request with the given headers and body to the given URL.
  Future<http.Response> head(Uri url,
      {Map<String, String>? headers, bool authenticate = false}) async {
    var authHeaders = authenticate ? await _auth(headers) : headers;
    authHeaders ??= <String, String>{};
    return _inner.head(url, headers: authHeaders);
  }

  /// Sends an HTTP GET request with the given headers to the given URL and
  /// returns a Future that completes to the body of the response as a Uint8List.
  Future<Uint8List> download(Uri url,
      {Map<String, String>? headers,
      Map<String, dynamic>? params,
      String savePath = "",
      bool authenticate = false,
      void Function(int, int)? onReceiveProgress}) async {
    // Make a GET request and get a streamed response
    final request = http.Request('GET', url);
    var authHeaders = authenticate ? await _auth(headers) : headers;
    request.headers.addAll(authHeaders ?? {});
    final streamedResponse = await _inner.send(request);

    // Get the total content length (if available)
    final total = streamedResponse.contentLength ?? -1;

    // Accumulate the received bytes
    final bytes = <int>[];
    int received = 0;

    // Listen to the stream of bytes and update progress
    await for (final chunk in streamedResponse.stream) {
      bytes.addAll(chunk);
      received += chunk.length;
      if (onReceiveProgress != null) {
        onReceiveProgress(received, total);
      }
    }
    // Convert to Uint8List
    final result = Uint8List.fromList(bytes);

    // Save to file if savePath is provided
    if (savePath.isNotEmpty) {
      final file = File(savePath);
      if (!file.existsSync()) {
        file.createSync(recursive: true);
      }
      await file.writeAsBytes(result);
    }

    return result;
  }

  /// Sends an HTTP GET request with the given headers to the given URL and
  /// returns a Future that completes to the body of the response as a String.
  Future<String> read(Uri url,
      {Map<String, String>? headers,
      Map<String, dynamic>? params,
      bool authenticate = false}) async {
    var authHeaders = authenticate ? await _auth(headers) : headers;
    return _inner.read(url, headers: authHeaders);
  }

  /// Sends an HTTP GET request with the given headers to the given URL and
  /// returns a Future that completes to the body of the response as a list of
  /// bytes.
  Future<Uint8List> readBytes(Uri url,
      {Map<String, String>? headers,
      Map<String, dynamic>? params,
      bool authenticate = false}) async {
    var authHeaders = authenticate ? await _auth(headers) : headers;
    return _inner.readBytes(url, headers: authHeaders);
  }

  /// Implementation for UPLOAD file request with the given params, headers, body and formFields
  /// to the given URL.
  ///
  /// The `params` argument is required, in format `{fileFieldName : pathOfFile}`
  ///
  Future<http.Response> upload(Uri url,
      {required Map<String, dynamic> params,
      bool authenticate = false,
      Map<String, String>? headers,
      Map<String, String>? formFields}) async {
    http.Response? response;
    HttpRequestInterceptor interceptor = HttpRequestInterceptor();

    String fileFieldName = params.entries.first.key;
    String pathOfFile = params.entries.first.value as String;
    File file = File(pathOfFile);
    if (fileFieldName.isEmpty ||
        pathOfFile.split(" ").length > 1 ||
        !pathOfFile.startsWith("/") ||
        !file.existsSync()) {
      response = http.Response(
          "Multipart file not found!", HttpError.MULTIFILE_NOT_FOUND);
      return await interceptor.naiveInterceptResponse(responseObj: response);
    }

    http.MultipartRequest request = http.MultipartRequest('POST', url);
    request = await interceptor.naiveInterceptRequest(requestObj: request);
    var authHeaders = authenticate ? await _auth(headers) : headers;
    request.headers.addAll(authHeaders ?? {});
    request.fields.addAll(formFields ?? {});
    for (var entry in params.entries) {
      String fileFieldName = entry.key;
      String pathOfFile = entry.value as String;
      request.files
          .add(await http.MultipartFile.fromPath(fileFieldName, pathOfFile));
    }
    var streamedResponse = await request.send();
    response = await http.Response.fromStream(streamedResponse);
    http.Response responseData =
        await interceptor.naiveInterceptResponse(responseObj: response);
    return responseData;
  }

  /// Closes the client and cleans up any resources associated with it.
  ///
  /// It's important to close each client when it's done being used; failing to
  /// do so can cause the Dart process to hang.
  void close() async {
    SharedPreferences prefs = await _sharedPrefsFuture;
    prefs.remove(_authTokenCacheKey);

    try {
      _inner.close();
    } catch (e, stackTrace) {
      print("exception caught: $e \n $stackTrace");
    }
  }

  /// private function sends an HTTP request and asynchronously returns the response.
  Future<dynamic> _send(String method, String uu,
      {Map<String, String>? headers,
      Map<String, dynamic>? params,
      Encoding? encoding,
      Map<String, String>? formFields,
      int? timeoutSecs,
      String? requestId,
      bool authenticate = true,
      String savePath = "",
      void Function(int received, int total)? onReceiveProgress,
      bool silent = false}) async {
    assert(baseUrl.isNotEmpty || uu.startsWith("http"),
        "AuthenticatedHttpClient must be initialized properly prior to use.");
    assert(_httpMethodMapper.containsKey(method.toLowerCase()),
        "$method is not supported yet!");

    method = method.toLowerCase();
    dynamic adequateConf = _pathParamsResolver(uu, params);
    uu = adequateConf["url"];
    params = adequateConf["params"];
    var url = uu.startsWith("http")
        ? Uri.parse(uu)
        : (baseUrl.startsWith("http://")
            ? Uri.http(_host, uu)
            : Uri.https(_host, uu));
    Function requestFnc = _httpMethodMapper[method]!;
    bool needIntercepted =
        authenticate || baseUrl.isEmpty || url.toString().startsWith(baseUrl);
    headers = headers ?? {};
    String requestIdValue = requestId ?? Utils.fastUUID();
    headers.putIfAbsent("_SILENT_", () => silent.toString());
    headers.putIfAbsent(
        "_REQUEST_ID_",
        () =>
            requestIdValue); // for temporary purpose and would be deleted before sent.
    if (_requestIdHeaderKey.isNotEmpty &&
        _requestIdHeaderKey != "_REQUEST_ID_") {
      headers.putIfAbsent(_requestIdHeaderKey, () => requestIdValue);
    }
    headers.putIfAbsent("_ICP_REQUEST_", () => needIntercepted.toString());
    Map<Symbol, dynamic> namedArguments = {
      const Symbol("headers"): headers,
      const Symbol("authenticate"): authenticate
    };
    if (method == "get" || method == "head") {
      Function resolveFnc =
          baseUrl.startsWith("http://") ? Uri.http : Uri.https;
      var paramsTmp = (params == null || params.isEmpty)
          ? null
          : params.map((key, value) => MapEntry(key, value.toString()));
      url = resolveFnc(url.host, url.path, paramsTmp);
    }
    if (method == "post" ||
        method == "put" ||
        method == "delete" ||
        method == "patch") {
      namedArguments[const Symbol("body")] = params;
      namedArguments[const Symbol("encoding")] = encoding;
    }
    if (method == "read" || method == "readBytes") {
      namedArguments[const Symbol("params")] = params;
    }
    if (method == "down" || method == "download") {
      namedArguments[const Symbol("params")] = params;
      namedArguments[const Symbol("savePath")] = savePath;
      namedArguments[const Symbol("onReceiveProgress")] = onReceiveProgress;
    }
    if (method == "up" || method == "upload") {
      namedArguments[const Symbol("params")] = params;
      namedArguments[const Symbol("formFields")] = formFields;
    }
    try {
      return Function.apply(requestFnc, [url], namedArguments)
          .timeout(Duration(seconds: timeoutSecs ?? _requestTimeout),
              onTimeout: () => throw TimeoutException('The request timed out.'))
          .then((response) =>
              _onSuccessCallback(response, needIntercepted: needIntercepted));
    } on TimeoutException catch (e) {
      print('Timeout Error: $e');
      if (_errorInterceptorHandler != null) {
        _errorInterceptorHandler!(exception: e, silent: silent);
      }
    } on SocketException catch (e) {
      print('Connection Error: $e');
      if (_errorInterceptorHandler != null) {
        _errorInterceptorHandler!(exception: e, silent: silent);
      }
    } catch (e) {
      throw http.ClientException('An unexpected error occurred: $e');
    } finally {}
  }

  Future<dynamic> _onSuccessCallback(response,
      {bool needIntercepted = true}) async {
    // http response statusCode == 200
    // utf-8 support: https://pub.dev/documentation/http/latest/
    // for read/readbytes method directly return Uint8List
    if (response is Uint8List) {
      return response;
    }

    dynamic jsonObj;
    try {
      jsonObj = json.decode(utf8.decode(response.bodyBytes));
    } catch (ignored) {
      // non-intercepted request if not Map return bodyBytes
      if (!needIntercepted) {
        return utf8.decode(response.bodyBytes);
      }
    }

    if (jsonObj is! Map) {
      return jsonObj;
    }
    var code = jsonObj["code"];
    if (code == 0 || !jsonObj.containsKey("code")) {
      try {
        return _responseHandler != null ? _responseHandler!(jsonObj) : jsonObj;
      } catch (e, stackTrace) {
        print("exception caught: $e \n $stackTrace");
      }
      return jsonObj;
    }
    // Throw an exception if code equals RouterHelper.code means to terminate the future chain
    throw HttpError(code, jsonObj["message"]);
  }

  /// Add the Authorization header from SharedPreferences to HTTP requests
  Future<Map<String, String>> _auth(Map<String, String>? headers) async {
    SharedPreferences prefs = await _sharedPrefsFuture;
    final String userAccessToken = prefs.getString(_authTokenCacheKey) ?? '';
    var headersTmp = headers ?? <String, String>{};
    if (userAccessToken.isNotEmpty) {
      headersTmp.putIfAbsent('Authorization', () => userAccessToken);
    }
    return headersTmp;
  }

  /// Path parameters support resolution of identifiers like :id and {id}
  Map<String, dynamic> _pathParamsResolver(
      String uu, Map<String, dynamic>? params) {
    // 判断uu中是否存在:id 或 {id}格式
    var adequateConf = {"url": uu, "params": params};
    if (params == null ||
        !uu.split("/").any((path) =>
            path.isNotEmpty &&
            (path.startsWith(":") || RegExp(r'\{.*?\}').hasMatch(path)))) {
      return adequateConf;
    }

    var paramsCopy = Map<String, dynamic>.from(params);
    uu = uu.split("/").map((path) {
      String keyTmp = path.replaceAll(RegExp(r'[:{}]'), '');
      if (path.isEmpty ||
          !(path.startsWith(":") || RegExp(r'\{.*?\}').hasMatch(path)) ||
          !params.containsKey(keyTmp) ||
          params[keyTmp] == null ||
          params[keyTmp] is! String && params[keyTmp] is! int) {
        return path;
      }
      paramsCopy.remove(keyTmp);
      return params[keyTmp].toString();
    }).join("/");
    adequateConf["url"] =
        uu.startsWith(RegExp(r'^(/|http[s]?:\/\/)')) ? uu : "/$uu";
    adequateConf["params"] = paramsCopy;
    return adequateConf;
  }

  /// send request in throttling control pool
  void _sendThrottlingQueue(HttpRequestTask request) async {
    _activeCount++;
    try {
      print(
          "[Throttling Queue Status] Active: $_activeCount Pending: ${_pendingRequestsOfThrottlingQueue.length}");
      dynamic response = await _send(request.method, request.uu,
          headers: request.headers,
          params: request.params,
          encoding: request.encoding,
          formFields: request.formFields,
          timeoutSecs: request.timeoutSecs,
          authenticate: request.authenticate,
          onReceiveProgress: request.onReceiveProgress,
          silent: request.silent);
      !request.completer.isCompleted
          ? request.completer.complete(response)
          : null;
    } catch (e) {
      !request.completer.isCompleted
          ? request.completer.completeError(e)
          : null;
    } finally {
      _activeCount--;
      _processThrottlingQueue();
    }
  }

  /// move on fetch next request in throttling queue
  void _processThrottlingQueue() {
    if (_pendingRequestsOfThrottlingQueue.isNotEmpty &&
        _activeCount < _maxThrottlingNum) {
      final nextRequest = _pendingRequestsOfThrottlingQueue.removeFirst();
      _sendThrottlingQueue(nextRequest);
    }
  }

  /// Mocking requests by reading from a local JSON file
  Future<Map<String, dynamic>> _readJsonFile(String filePath) async {
    final content = await rootBundle.loadString(filePath);
    return jsonDecode(content);
  }
}
