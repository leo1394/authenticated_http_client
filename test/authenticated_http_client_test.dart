import 'dart:convert';
import 'dart:io';

import 'package:authenticated_http_client/authenticated_http_client.dart';
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
    final api = client
        .factory({"localRequest": "GET /health?source=origin&retained=yes"});

    final response = await api
        .localRequest({"source": "local", "added": "new"}, authenticate: false);

    expect(response["data"], {
      "port": server.port,
      "path": "/health",
      "query": {"source": "local", "retained": "yes", "added": "new"}
    });
  });
}
