
## authenticated_http_client
[![pub package](https://img.shields.io/pub/v/authenticated_http_client.svg)](https://pub.dev/packages/authenticated_http_client)
[![pub points](https://img.shields.io/pub/points/authenticated_http_client?color=2E8B57&label=pub%20points)](https://pub.dev/packages/authenticated_http_client/score)
[![GitHub Issues](https://img.shields.io/github/issues/leo1394/authenticated_http_client.svg?branch=master)](https://github.com/leo1394/authenticated_http_client/issues)
[![GitHub Forks](https://img.shields.io/github/forks/leo1394/authenticated_http_client.svg?branch=master)](https://github.com/leo1394/authenticated_http_client/network)
[![GitHub Stars](https://img.shields.io/github/stars/leo1394/authenticated_http_client.svg?branch=master)](https://github.com/leo1394/authenticated_http_client/stargazers)
[![GitHub License](https://img.shields.io/badge/license-MIT%20-blue.svg)](https://raw.githubusercontent.com/leo1394/authenticated_http_client/master/LICENSE)

An advanced authenticated HTTP client introduces a `factory` feature that generates request futures based on API definitions in a WYSIWYG style, 
with additional supports for `mock` and `silent` modes during development.

It all began with the forging pattern — `[mock] [silent] [method] /api/plan/{id}/details` — a skeletal incantation that would simplify every thing.

- `factory`: generates AJAX request functions by api URI declaration in WYSIWYG style.
- `mock`: mocking data from a local JSON file for specified requests during development. 
- `silent`: suppress routing redirection for unauthorized or maintenance responses for specified request.
- `throttling`: queues excess requests using async/await for controlled upload pacing.
- request futures functions generated can be accessed by dot notation.

## Platform Support

| Android | iOS | MacOS | Web | Linux | Windows |
| :-----: | :-: | :---: |:---:| :---: | :-----: |
|   ✅    | ✅  |  ✅   |  ❌️  |  ✅   |   ✅    |

## Requirements

- Flutter >=3.0.0 <4.0.0
- Dart: ^2.17.0
- http: ^1.3.0
- http_interceptor: ^2.0.0

## Getting started
published on pub.dev, run this Flutter command
```shell
flutter pub add authenticated_http_client
```

## Usage showcase
- Retrieve the auth_token and store it in the AuthenticatedHttpClient cache.
```dart
    var apiService = AuthenticatedHttpClient.getInstance().factory({ "login"  : "POST /api/sign-in" });
    
    apiService.login({"username": "demo", "passwords": "test123"}).then((response) {
        // response here in format {code, message, data}
        final {"auth_token": authToken, "expired_at": expiredAt} = response["data"];
        AuthenticatedHttpClient.getInstance().setAuthToken(authToken);
    });
```

- Create request futures with support for path parameters.
```dart
    var apiService = AuthenticatedHttpClient.getInstance().factory({
        "requestName"                : "POST /api/submit/plan",
        "requestNameWithColonParams" : "GET /api/plan/:id/details", 
        "requestNameWithBraceParams" : "GET /api/plan/{id}/details"
    });
    apiService.requestName().then((response) {/* success */}).catchError((e, stackTrace){ /* fail */ }).whenComplete((){ /* finally */ });
    apiService.requestNameWithColonParams({"id": 9527}).then((response) {/* success */}).catchError((e, stackTrace){ /* fail */ }).whenComplete((){ /* finally */ });
    apiService.requestNameWithBraceParams({"id": 9527}).then((response) {/* success */}).catchError((e, stackTrace){ /* fail */ }).whenComplete((){ /* finally */ });
```

- Mock requests are served from JSON files in the mockDirectory (defaulting to /lib/mock), which can be configured via AuthenticatedHttpClient.getInstance().init() and need to be declared under assets section in pubspec.yaml.
```dart
    var apiService = AuthenticatedHttpClient.getInstance().factory({
        "mockRequest"           : "MOCK POST /api/task/config", 
    });

    // mock from _post_api_task_config.json under mockDirectory /lib/mock
    apiService.mockRequest().then((response) {/* success */}).catchError((e, stackTrace){ /* fail */ }).whenComplete((){ /* finally */ });
```

- Silent requests skip redirection for unauthorized responses or during maintenance.
```dart
    var apiService = AuthenticatedHttpClient.getInstance().factory({
        "silentRequest"         : "SILENT GET /api/message/check/unread" 
    });

    // Even http status 401 won't redirect to login   
    apiService.silentRequest().then((response) {/* success */}).catchError((e, stackTrace){ /* fail */ }).whenComplete((){ /* finally */ });
```

- Throttling control, queue excess requests.
```dart
    var apiService = AuthenticatedHttpClient.getInstance().factory({
        "request"         : "SILENT POST /api/upload" 
    });

    apiService.request(throttling: true).then((response) {/* success */}).catchError((e, stackTrace){ /* fail */ }).whenComplete((){ /* finally */ });
```

- AuthenticatedHttpClient.all is a static function, like Promise.all, with a delay feature to prevent potential server concurrency issues.
```dart
    var apiService = AuthenticatedHttpClient.getInstance().factory({
        "requestName"           : "POST /api/submit/plan",
        "requestNameWithParams" : "GET /api/plan/:id/details",
    });

    List<Future> futures = [apiService.requestName(), apiService.requestNameWithParams({"id": 9528})];
    AuthenticatedHttpClient.all(futures, delayInMilliSecs: 350).then((results){
        print(results['0']); // response of No.1 request
        print(results['1']); // response of No.2 request
    });
```

## Steps for Usage in Dart
- Initialize a RouterHelper to manage when and how the authenticated HTTP client redirects to the login or maintenance route, if necessary.
```dart
    import 'package:authenticated_http_client/router_helper.dart';
    
    RouterHelper.init(
        jump2LoginCallback: () { /* navigate to login route depends on routing library */ },
        unAuthCode: "101|103"
    );
```
<details>
  <summary>`jump2LoginCallback` examples using different routing library</summary>

```dart
    // FluroRouter example
    BuildContext context; // keep current build context
    function jump2LoginCallback() {
        String? currentRoute = ModalRoute.of(context)?.settings.name;
        if(currentRoute?.split("?").first == "/login") { return ; }
        FluroRouter().navigateTo(context, "/login", clearStack: true);
    }
```

```dart
    // GoRouter example
    BuildContext context; // keep current build context
    function jump2LoginCallback() {
        String? currentRoute = GoRouter.of(context).location;
        if(currentRoute?.split("?").first == "/login") { return ; }
        GoRouter(routes: []).go("/login");
    }
```

</details>

- Implement the CustomHttpHeadersInterceptor required for initializing the AuthenticatedHttpClient later.
```dart
    import 'package:authenticated_http_client/http_headers_interceptor.dart';
    
    class Constants {
        static String udid = "357292741221214";
        static String appVersion = "1.0.1";
        static String appBuildNumber = "1394";
        static String systemCode = "e08f11c8-3b1c-4008-abba-045787e0b6c0";
    }
    
    class CustomHttpHeadersInterceptor extends HttpHeadersInterceptor {
        @override
        Map<String, String> headersInterceptor(Map<String, String> headers) {
            headers["udid"] = Constants.udid;
            headers["version"] = Constants.appVersion;
            headers["system-code"] = Constants.systemCode;
            return headers;
        }
    }
```

- Initialize an authenticated HTTP client that appends a token to the Authorization header for every subsequent AJAX request.  
```dart
    import 'package:authenticated_http_client/authenticated_http_client.dart';
    
    AuthenticatedHttpClient.getInstance().init(
        "https://api.company.com", 
        customHttpHeadersInterceptor: CustomHttpHeadersInterceptor()
    );
```

- Ultimately, use any feature at your convenience.
```dart
    var apiService = AuthenticatedHttpClient.getInstance().factory({
        "login"                 : "POST /api/sign-in",
        "requestName"           : "POST /api/submit/plan",
        "requestNameWithParams" : "GET /api/plan/:id/details", // or "GET /api/plan/{id}/details"
        "mockRequest"           : "MOCK POST /api/task/config", // mock from _post_api_task_config.json under mockDirectory /lib/mock
        "silentRequest"         : "SILENT GET /api/message/check/unread" // silent request won't jump when response met unauthorized or under maintenance
    });
    
    apiService.login({"username": "demo", "passwords": "test123"}).then((response) {
        // response here in format {code, message, data}
        final {"auth_token": authToken, "expired_at": expiredAt} = response["data"];
        AuthenticatedHttpClient.getInstance().setAuthToken(authToken);
    });
    apiService.requestName().then((response) {/* success */}).catchError((e, stackTrace){ /* fail */ }).whenComplete((){ /* finally */ });
    apiService.requestNameWithParams({"id": 9527}).then((response) {/* success */}).catchError((e, stackTrace){ /* fail */ }).whenComplete((){ /* finally */ });
    
    /// AuthenticatedHttpClient.all is a static function,similar to Promise.all,
    /// which introduces a delay feature to prevent potential server concurrency issues
    List<Future> futures = [apiService.requestName(), apiService.requestNameWithParams({"id": 9528})];
    AuthenticatedHttpClient.all(futures, delayInMilliSecs: 350).then((results){
        print(results['0']); // response of No.1 request
        print(results['1']); // response of No.2 request
    });
```

## Additional information
Feel free to file an issue if you have any problem.
