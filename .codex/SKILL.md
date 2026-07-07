---
name: authenticated_http_client
description: Use when coding with the authenticated_http_client package: authenticated HTTP setup, WYSIWYG API factories, token storage, mock/silent requests, uploads/downloads, throttling, RouterHelper, and custom headers.
---

# authenticated_http_client Agent Context

Use this package for Flutter/Dart HTTP requests that need auth-token management, request declarations, mock JSON responses, silent unauthorized handling, upload/download helpers, and request throttling.

## Imports

```dart
import 'package:authenticated_http_client/authenticated_http_client.dart';
import 'package:authenticated_http_client/http_headers_interceptor.dart';
import 'package:authenticated_http_client/router_helper.dart';
```

## Setup Pattern

Initialize routing behavior first, then initialize the singleton client.

```dart
RouterHelper.init(
  jump2LoginCallback: () {
    // Navigate to login with the app router.
  },
  unAuthCode: "101|103",
);

class AppHeadersInterceptor extends HttpHeadersInterceptor {
  @override
  Map<String, String> headersInterceptor(Map<String, String> headers) {
    headers["version"] = "1.0.0";
    headers["system-code"] = "app-system";
    return headers;
  }
}

AuthenticatedHttpClient.getInstance().init(
  "https://api.example.com",
  customHttpHeadersInterceptor: AppHeadersInterceptor(),
);
```

## API Factory

Declare APIs as strings: `[MOCK] [SILENT] METHOD /path/:id` or `/path/{id}`.

```dart
final api = AuthenticatedHttpClient.getInstance().factory({
  "login": "POST /api/sign-in",
  "details": "GET /api/plan/:id/details",
  "silentUnread": "SILENT GET /api/message/check/unread",
  "mockConfig": "MOCK POST /api/task/config",
  "uploadFile": "UP /api/file",
});

final loginResp = await api.login({
  "username": "demo",
  "password": "test123",
});
AuthenticatedHttpClient.getInstance()
    .setAuthToken(loginResp["data"]["auth_token"]);

final details = await api.details({"id": 9527});
```

## Upload, Download, Throttling

```dart
await api.uploadFile({"file": "/local/path/file.jpg"}, throttling: true);

await api.download(
  null,
  savePath: "/tmp/file.zip",
  authenticate: false,
  onReceiveProgress: (received, total) {
    print("$received/$total");
  },
);
```

Use `AuthenticatedHttpClient.all(futures, delayInMilliSecs: 350)` for Promise.all-style batching with optional staggered delay.

## Notes for Agents

- Prefer `AuthenticatedHttpClient.getInstance()`; it is used as a singleton.
- Use `SILENT` for background polling where unauthorized/maintenance should not navigate.
- Use `MOCK` only when mock JSON assets exist under the configured mock directory and are declared in `pubspec.yaml`.
- Path params may be `:id` or `{id}` and are filled from the argument map.
- Store auth tokens with `setAuthToken`; custom headers belong in `HttpHeadersInterceptor`, not per-call duplication.
