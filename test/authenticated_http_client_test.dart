import 'dart:convert';
import 'dart:io';

import 'package:authenticated_http_client/authenticated_http_client.dart';
import 'package:authenticated_http_client/http_error.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test/test.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  test('preserves the base URL port and merges query parameters', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      request.response.headers.contentType = ContentType.json;
      if (request.requestedUri.path == "/failure") {
        request.response
            .write(jsonEncode({"code": 123, "message": "diagnostic"}));
        await request.response.close();
        return;
      }
      request.response.write(jsonEncode({
        "code": 0,
        "data": {
          "port": request.requestedUri.port,
          "path": request.requestedUri.path,
          "query": request.requestedUri.queryParameters
        }
      }));
      await request.response.close();
    });

    final client = AuthenticatedHttpClient.getInstance();
    client.init("http://127.0.0.1:${server.port}");
    final api = client.factory({
      "localRequest": "GET /health?source=origin&retained=yes",
      "failureRequest": "GET /failure"
    });

    final response = await api
        .localRequest({"source": "local", "added": "new"}, authenticate: false);

    expect(response["data"], {
      "port": server.port,
      "path": "/health",
      "query": {"source": "local", "retained": "yes", "added": "new"}
    });

    await expectLater(
        api.failureRequest(null, authenticate: false),
        throwsA(isA<HttpError>()
            .having((error) => error.code, "code", 123)
            .having((error) => error.message, "message", "diagnostic")));
  });
}
