# authenticated_http_client

Use `AuthenticatedHttpClient.getInstance()` as the singleton. Initialize `RouterHelper` and `AuthenticatedHttpClient.init(baseUrl, customHttpHeadersInterceptor: ...)` before requests. Build API services with `factory({"name": "SILENT GET /api/:id"})`; supported declarations include `MOCK`, `SILENT`, `GET/POST`, `UP`, and `DOWN`.

```dart
final api = AuthenticatedHttpClient.getInstance().factory({
  "login": "POST /api/sign-in",
  "details": "GET /api/plan/:id/details",
});
final response = await api.details({"id": 9527});
```

Use `setAuthToken(...)` after login. Use `AuthenticatedHttpClient.all(...)` for batch futures. Use `throttling: true` for upload-heavy flows.
