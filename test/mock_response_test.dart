import 'dart:convert';
import 'dart:typed_data';

import 'package:authenticated_http_client/authenticated_http_client.dart';
import 'package:authenticated_http_client/http_error.dart';
import 'package:authenticated_http_client/router_helper.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  final assetPayloads = <String, String>{
    "test/mock/_GET_failure.json":
        jsonEncode({"code": 123, "message": "diagnostic"}),
    "test/mock/_GET_unauthorized.json":
        jsonEncode({"code": 101, "message": "unauthorized"}),
    "test/mock/_GET_success.json": jsonEncode({"code": 0, "data": "mocked"}),
    "test/mock/_GET_invalid.json": "not-json"
  };
  final errors = <Map<String, dynamic>>[];
  late dynamic api;
  int loginJumps = 0;

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler("flutter/assets", (message) async {
      if (message == null) {
        return null;
      }
      final assetKey = utf8.decode(message.buffer
          .asUint8List(message.offsetInBytes, message.lengthInBytes));
      final payload = assetPayloads[assetKey];
      if (payload == null) {
        return null;
      }
      final bytes = Uint8List.fromList(utf8.encode(payload));
      return ByteData.view(bytes.buffer);
    });
    RouterHelper.init(
        unAuthCode: 101,
        jump2LoginCallback: () {
          loginJumps++;
        });
    final client = AuthenticatedHttpClient.getInstance();
    client.init("http://127.0.0.1:8080",
        mockDirectory: "test/mock",
        responseHandler: (response) => {"handled": response},
        errorInterceptorHandler: (
            {code, statusCode, silent = false, message, exception}) {
          errors.add({
            "code": code,
            "statusCode": statusCode,
            "silent": silent,
            "message": message,
            "exception": exception
          });
        });
    api = client.factory({
      "mockFailure": "MOCK GET /failure",
      "silentMockFailure": "SILENT MOCK GET /failure",
      "mockUnauthorized": "MOCK GET /unauthorized",
      "silentMockUnauthorized": "SILENT MOCK GET /unauthorized",
      "mockSuccess": "MOCK GET /success",
      "missingMock": "MOCK GET /missing",
      "invalidMock": "MOCK GET /invalid"
    });
  });

  setUp(() {
    errors.clear();
    loginJumps = 0;
  });

  tearDownAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler("flutter/assets", null);
  });

  Future<HttpError> captureHttpError(Future<dynamic> request) async {
    try {
      await request;
    } catch (error) {
      expect(error, isA<HttpError>());
      return error as HttpError;
    }
    throw StateError("Expected HttpError");
  }

  test('resource mock throws the same HttpError as real HTTP', () async {
    final mockError =
        await captureHttpError(api.mockFailure(null, authenticate: false));

    expect(mockError.code, 123);
    expect(mockError.message, "diagnostic");
    expect(errors, [
      {
        "code": 123,
        "statusCode": null,
        "silent": false,
        "message": "diagnostic",
        "exception": null
      }
    ]);
  });

  test('resource mock preserves unauthorized and silent behavior', () async {
    await captureHttpError(api.mockUnauthorized(null, authenticate: false));
    await captureHttpError(
        api.silentMockUnauthorized(null, authenticate: false));

    expect(loginJumps, 1);
    expect(errors, isEmpty);
  });

  test('resource mock passes silent to the error handler', () async {
    await captureHttpError(api.silentMockFailure(null, authenticate: false));

    expect(errors.single["silent"], true);
  });

  test('successful resource mock uses the response handler', () async {
    final response = await api.mockSuccess(null, authenticate: false);

    expect(response, {
      "handled": {"code": 0, "data": "mocked"}
    });
  });

  test('missing and invalid resources remain ClientException failures', () {
    expect(api.missingMock(null, authenticate: false),
        throwsA(isA<http.ClientException>()));
    expect(api.invalidMock(null, authenticate: false),
        throwsA(isA<http.ClientException>()));
  });
}
