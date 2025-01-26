// Copyright (c) 2025, the Dart project authors. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http_interceptor/http_interceptor.dart';
import 'package:universal_io/io.dart';
import 'http_error.dart';
import 'http_request_interceptor.dart';
import 'http_headers_interceptor.dart';
import 'map_dot.dart';

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
/// 3. AuthenticatedHttpClient.all(futures).then((results){ /* results['0'] */}).catchError().whenComplete()
///
/// 4. AuthenticatedHttpClient.getInstance().get(uri).then().catchError().whenComplete()
///
class AuthenticatedHttpClient {
  static const String _authTokenCacheKey = "-cached-authorization";
  static String baseUrl = "";
  static int _requestTimeout = 45; // timeout for http request in seconds
  Function? _responseHandler;
  String? _mockDirectory;  // mock data directory
  Map<String, Function> _httpMethodMapper = {};
  final Future<SharedPreferences> _sharedPrefsFuture;
  late final http.Client _inner;

  AuthenticatedHttpClient._(this._sharedPrefsFuture);
  static final AuthenticatedHttpClient _instance = AuthenticatedHttpClient._(SharedPreferences.getInstance());

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
  /// The timeoutInSecs optional argument, defaulting to 45 seconds, specifies HTTP
  /// request timeout in seconds.
  ///
  void init(String url,
      {
        Function? responseHandler,
        HttpHeadersInterceptor? customHttpHeadersInterceptor,
        String mockDirectory = "lib/mock",
        int? timeoutInSecs,
      }
  ) {
    assert(url.isNotEmpty, "url CAN NOT be empty !");

    if (url.isEmpty || url == baseUrl) {return ;}
    print("in AuthenticatedHttpClient base change to $url ...");
    baseUrl = url.replaceAll(RegExp(r'\/$'), "");
    List<InterceptorContract?> interceptors = [customHttpHeadersInterceptor, HttpRequestInterceptor()];
    _inner = InterceptedClient.build(interceptors: interceptors.where((inp) => inp != null).cast<InterceptorContract>().toList());
    _requestTimeout = timeoutInSecs ?? _requestTimeout;
    _responseHandler = responseHandler;
    _mockDirectory = mockDirectory;
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
      "down": readBytes,
    };
    requests.forEach((requestName, requestUri) {
      var stripped = requestUri.replaceAll(RegExp(r"\s+"), " ").trim();
      var parts = stripped.split(" ").reversed.toList();
      var method = (parts.length == 1 || ! _httpMethodMapper.keys.contains(parts[1].toLowerCase())) ? "get" : parts[1];
      var mock = RegExp(r'(^|\s)mock\s', caseSensitive: false).hasMatch(stripped);
      var silent = RegExp(r'(^|\s)silent\s', caseSensitive: false).hasMatch(stripped);
      var uu = parts.first;
      Future fnc(Map<dynamic, dynamic>? paramsUnnamed, {Map<String, String>? headers, Encoding? encoding, Map<dynamic, dynamic>? params, Map<String, String>? formFields, int? timeoutInSecs}) async  {
        // support mock data, response for mock request
        if (mock) {
          String filename = "_${method}_${uu.replaceAll("/", "_").replaceAll(RegExp(r'[{:}]'), "")}";
          String filepath = [_mockDirectory, "$filename.json"].join("/");
          final response = await _readJsonFile(filepath);
          print("in interceptRequest ==> ${baseUrl.startsWith("http://") ? Uri.http(baseUrl, uu) : Uri.https(baseUrl, uu)}, $params $paramsUnnamed \t MOCK response from local json file: $filepath, response ==> $response");
          return response;
        }
        // allow Map parameters in default Map<dynamic, dynamic>
        Map<String, dynamic>? paramsUnnamedFormatted = (paramsUnnamed == null || paramsUnnamed.isEmpty)? <String, dynamic>{} : paramsUnnamed.map((key, value) => MapEntry(key.toString(), value));
        Map<String, dynamic>? paramsFormatted = (params == null || params.isEmpty) ? <String, dynamic>{}  : params.map((key, value) => MapEntry(key.toString(), value));
        return _send(method, uu, headers: headers, params: paramsUnnamedFormatted, encoding: encoding, formFields: formFields, timeoutInSecs: timeoutInSecs, silent: silent);
      }
      requestFncs[requestName] = fnc;
    });
    return requestFncs;
  }

  /// Setter for the authentication token in an Authenticated HTTP Client
  void setAuthToken(String token) async {
    SharedPreferences prefs = await _sharedPrefsFuture;
    prefs.setString(_authTokenCacheKey, token);
  }

  /// A static function similar to Promise.all, which introduces a delay feature
  /// to prevent potential server concurrency issues
  ///
  /// The `futures` argument is a list Future requests
  ///
  /// The `anyCompleteCallback` optional argument specifies a custom Function for processing
  /// responses when any of `futures` requests completed
  ///
  /// The `anyErrorCallback` optional argument specifies a custom Function for processing
  /// responses when any of `futures` requests failed
  ///
  /// The `delayInMilliSecs` optional argument specifies a delay in milliseconds to prevent
  /// potential server concurrency issues. defaulting to `0`
  ///
  static Future<dynamic> all(List<dynamic> futures,
      {
        Function? anyCompleteCallback,
        Function? anyErrorCallback,
        int delayInMilliSecs = 0
      }
  ) {
    int taskCompleted = 0;
    Map<String, dynamic> results = {};
    var completer = Completer();
    for(int i = 0; i < futures.length; i ++) {
      futures[i].then((resp) {
        results[i.toString()] = resp;
      }).catchError((e, stackTrace) {
        try{
          anyErrorCallback != null ? anyErrorCallback(e, stackTrace) : null;
        }catch(e) { }
      }).whenComplete(() {
        taskCompleted ++ ;
        if (anyCompleteCallback != null) {
          try{
            anyCompleteCallback(results);
          }catch(e, stackTrace) {
            print("exception caught: $e \n $stackTrace");
          }
        }
        taskCompleted >= futures.length ? completer.complete(results) : null;
      });
      delayInMilliSecs >= 0 ? sleep(Duration(milliseconds: delayInMilliSecs)) : null; // Sleep for some milliseconds
    }
    return completer.future;
  }

  /// Note: http interceptors do not support send method currently.
  /// refer to https://pub.dev/documentation/http_interceptor/latest/http_intercepted_client/InterceptedClient-class.html
  /// so, we need to override ajax kinds of AJAX methods function.

  /// Sends an HTTP GET request with the given headers and body to the given URL.
  Future<http.Response> get(Uri url, {Map<String, String>? headers}) async {
    var authHeaders = await _auth(headers);
    return _inner.get(url, headers: authHeaders);
  }

  /// Sends an HTTP POST request with the given headers and body to the given URL.
  Future<http.Response> post(Uri url, {Map<String, String>? headers, Object? body, Encoding? encoding}) async {
    var authHeaders = await _auth(headers);
    // {"content-type": "application/json"}  jsonEncode(body) body accepted as String
    // {"content-type": "application/x-www-form-urlencoded"} body accepted as Map
    Object? bodyFormatted = authHeaders["content-type"]?.toLowerCase() == "application/x-www-form-urlencoded" ? body : jsonEncode(body);
    return _inner.post(url, headers: authHeaders, body: bodyFormatted, encoding: encoding);
  }

  /// Sends an HTTP PUT request with the given headers and body to the given URL.
  Future<http.Response> put(Uri url, {Map<String, String>? headers, Object? body, Encoding? encoding}) async {
    var authHeaders = await _auth(headers);
    // {"content-type": "application/json"}  jsonEncode(body) body accepted as String
    // {"content-type": "application/x-www-form-urlencoded"} body accepted as Map
    Object? bodyFormatted = authHeaders["content-type"]?.toLowerCase() == "application/x-www-form-urlencoded" ? body : jsonEncode(body);
    return _inner.put(url, headers: authHeaders, body: bodyFormatted, encoding: encoding);
  }

  /// Sends an HTTP DELETE request with the given headers and body to the given URL.
  Future<http.Response> delete(Uri url, {Map<String, String>? headers, Object? body, Encoding? encoding}) async {
    var authHeaders = await _auth(headers);
    return _inner.delete(url, headers: authHeaders, body: body, encoding: encoding);
  }

  /// Sends an HTTP PATCH request with the given headers and body to the given URL.
  Future<http.Response> patch(Uri url, {Map<String, String>? headers, Object? body, Encoding? encoding}) async {
    var authHeaders = await _auth(headers);
    // {"content-type": "application/json"}  jsonEncode(body) body accepted as String
    // {"content-type": "application/x-www-form-urlencoded"} body accepted as Map
    Object? bodyFormatted = authHeaders["content-type"]?.toLowerCase() == "application/x-www-form-urlencoded" ? body : jsonEncode(body);
    return _inner.patch(url, headers: authHeaders, body: bodyFormatted, encoding: encoding);
  }

  /// Sends an HTTP HEAD request with the given headers and body to the given URL.
  Future<http.Response> head(Uri url, {Map<String, String>? headers}) async {
    var authHeaders = await _auth(headers);
    return _inner.head(url, headers: authHeaders);
  }

  /// Sends an HTTP GET request with the given headers to the given URL and
  /// returns a Future that completes to the body of the response as a String.
  Future<String> read(Uri url, {Map<String, String>? headers, Map<String, dynamic>? params}) async {
    // var authHeaders = await _auth(headers);
    return _inner.read(url, headers: headers);
  }

  /// Sends an HTTP GET request with the given headers to the given URL and
  /// returns a Future that completes to the body of the response as a list of
  /// bytes.
  Future<Uint8List> readBytes(Uri url, {Map<String, String>? headers, Map<String, dynamic>? params}) async {
    // var authHeaders = await _auth(headers);
    return _inner.readBytes(url, headers: headers);
  }

  /// Implementation for UPLOAD file request with the given params, headers, body and formFields
  /// to the given URL.
  ///
  /// The `params` argument is required, in format `{fileFieldName : pathOfFile}`
  ///
  Future<http.Response> upload(Uri url, {required Map<String, dynamic> params, Map<String, String>? headers, Map<String, String>? formFields}) async {
    http.Response? response;
    HttpRequestInterceptor interceptor = HttpRequestInterceptor();

    String fileFieldName = params.entries.first.key;
    String pathOfFile = params.entries.first.value as String;
    File file = File(pathOfFile);
    if (fileFieldName.isEmpty || pathOfFile.split(" ").length > 1 || !pathOfFile.startsWith("/") || !file.existsSync() ) {
      response = http.Response("Multipart file not found!", HttpError.MULTIFILE_NOT_FOUND);
      return await interceptor.naiveInterceptResponse(responseObj: response);
    }

    http.MultipartRequest request = http.MultipartRequest('POST', url);
    request = await interceptor.naiveInterceptRequest(requestObj: request);
    var authHeaders = await _auth(headers);
    request.headers.addAll(authHeaders);
    request.fields.addAll(formFields ?? {});
    for (var entry in params.entries) {
      String fileFieldName = entry.key;
      String pathOfFile = entry.value as String;
      request.files.add(await http.MultipartFile.fromPath(fileFieldName, pathOfFile));
    }
    var streamedResponse = await request.send();
    response = await http.Response.fromStream(streamedResponse);
    http.Response responseData = await interceptor.naiveInterceptResponse(responseObj: response);
    return responseData;
  }

  /// Closes the client and cleans up any resources associated with it.
  ///
  /// It's important to close each client when it's done being used; failing to
  /// do so can cause the Dart process to hang.
  void close() async {
    SharedPreferences prefs = await _sharedPrefsFuture;
    prefs.remove(_authTokenCacheKey);

    try{
      _inner.close();
    }catch(e, stackTrace) {
      print("exception caught: $e \n $stackTrace");
    }
  }

  /// private function sends an HTTP request and asynchronously returns the response.
  Future<dynamic> _send(String method, String uu,
      {
        Map<String, String>? headers,
        Map<String, dynamic>? params,
        Encoding? encoding,
        Map<String, String>? formFields,
        int? timeoutInSecs,
        bool silent = false
      }
      ) async {
    assert(baseUrl.isNotEmpty || uu.startsWith("http"), "baseUrl is empty, please init AuthenticatedHttpClient with baseUrl !");
    assert(_httpMethodMapper.containsKey(method.toLowerCase()), "$method is not supported yet!");

    method = method.toLowerCase();
    dynamic adequateConf = _pathParamsResolver(uu, params);
    uu = adequateConf["url"];
    params = adequateConf["params"];
    var url = uu.startsWith("http") ? Uri.parse(uu) : (baseUrl.startsWith("http://") ? Uri.http(baseUrl, uu) : Uri.https(baseUrl, uu));
    Function requestFnc = _httpMethodMapper[method]!;

    headers = headers ?? {};
    headers.putIfAbsent("_SILENT_", () => silent.toString());
    Map<Symbol, dynamic> namedArguments = {
      const Symbol("headers"): headers
    };
    if (method == "get" || method == "head") {
      url = Uri.https(baseUrl, uu, params?.map((key, value) => MapEntry(key, value.toString())));
    }
    if (method == "post" || method == "put" || method == "delete" || method == "patch") {
      namedArguments[const Symbol("body")] = params;
      namedArguments[const Symbol("encoding")] = encoding;
    }
    if (method == "read" || method == "readBytes" || method == "down" || method == "download") {
      namedArguments[const Symbol("params")] = params;
    }
    if (method == "up" || method == "upload") {
      namedArguments[const Symbol("params")] = params;
      namedArguments[const Symbol("formFields")] = formFields;
    }
    return Function.apply(requestFnc, [url], namedArguments).timeout(Duration(seconds: timeoutInSecs ?? _requestTimeout)).then((response) async {
      // http response statusCode == 200
      // utf-8 support: https://pub.dev/documentation/http/latest/
      // for read/readbytes method directly return Uint8List
      if (response is Uint8List) { return response; }
      var jsonObj = json.decode(utf8.decode(response.bodyBytes));
      if (jsonObj is! Map) {
        return jsonObj;
      }
      var code = jsonObj["code"];
      if (code == 0 || !jsonObj.containsKey("code")) {
        try{
          return _responseHandler != null ? _responseHandler!(jsonObj) : jsonObj;
        }catch(e, stackTrace) {
          print("exception caught: $e \n $stackTrace");
        }
        return jsonObj;
      }
      // Throw an exception if code equals RouterHelper.code means to terminate the future chain
      throw HttpError(code, jsonObj["message"]);
    });
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
  Map<String, dynamic> _pathParamsResolver(String uu, Map<String, dynamic>? params) {
    // 判断uu中是否存在:id 或 {id}格式
    var adequateConf = {"url": uu, "params": params};
    if (! uu.split("/").any((path) => path.isNotEmpty && (path.startsWith(":") || RegExp(r'\{.*?\}').hasMatch(path))) || params == null) {
      return adequateConf;
    }
    var paramsCopy = Map<String, dynamic>.from(params);
    uu = uu.split("/").map((path) {
      String keyTmp = path.replaceAll(":", "");
      if (path.isEmpty || ! (path.startsWith(":") || RegExp(r'\{.*?\}').hasMatch(path)) || ! params.containsKey(keyTmp)
          || params[keyTmp] == null || params[keyTmp] is! String && params[keyTmp] is! int ) {
        return path;
      }
      paramsCopy.remove(keyTmp);
      return params[keyTmp].toString();
    }).join("/");
    adequateConf["url"] = uu;
    adequateConf["params"] = paramsCopy;
    return adequateConf;
  }

  /// Mocking requests by reading from a local JSON file
  Future<Map<String, dynamic>> _readJsonFile(String filePath) async {
    try {
      final content = await rootBundle.loadString(filePath);
      return jsonDecode(content);
    } catch (e, stackTrace) {
      print('Error reading JSON file: $e \n $stackTrace');
      return <String, dynamic>{}; // Return an empty JSON object in case of an error
    }
  }
}