<!-- 
This README describes the package. If you publish this package to pub.dev,
this README's contents appear on the landing page for your package.

For information about how to write a good package README, see the guide for
[writing package pages](https://dart.dev/tools/pub/writing-package-pages). 

For general information about developing packages, see the Dart guide for
[creating packages](https://dart.dev/guides/libraries/create-packages)
and the Flutter guide for
[developing packages and plugins](https://flutter.dev/to/develop-packages). 
-->

An advanced authenticated HTTP client introduces a `factory` feature that generates request functions based on API URI definitions in WYSIWYG style. 
Besides, it also supports `mock` and `silent` modes and other effective features for development.

- factory: generates AJAX request functions by api URI name in WYSIWYG style.
- mock: mocking data from a local JSON file for specified requests during development. 
- silent: suppress routing redirection for unauthorized or maintenance responses for specified request.
- request functions generated can be accessed by dot notation.

## Getting started
published on pub.dev, run this Flutter command
```shell
flutter pub add authenticated_http_client
```
## Steps for Usage in Dart
- initialize RouterHelper managing when and how authenticated http client to redirect login or under maintenance route if needed.
```dart
import 'package:authenticated_http_client/router_helper.dart';

RouterHelper.init(
    jump2LoginCallback: () { /* navigate to login route depends on your routing library */ },
    unAuthCode: "101|103"
);
// FluroRouter example
BuildContext context; // keep current build context
function jump2LoginCallback() {
    String? currentRoute = ModalRoute.of(context)?.settings.name;
    if(currentRoute?.split("?").first == "/login") { return ; }
    FluroRouter().navigateTo(context, "/login", clearStack: true);
}
// GoRouter example
function jump2LoginCallback() {
    String? currentRoute = GoRouter.of(context).location;
    if(currentRoute?.split("?").first == "/login") { return ; }
    GoRouter(routes: []).go("/login");
}
```

- Implement CustomHttpHeadersInterceptor needed in AuthenticatedHttpClient initialization afterwards
```dart
import 'package:authenticated_http_client/http_headers_interceptor.dart';

class Constants {
    static String appVersion = "1.0.1";
    static String appBuildNumber = "1394";
    static String systemCode = "e08f11c8-3b1c-4008-abba-045787e0b6c0";
    static String deviceMode = "Apple iPhone 15";
    static String channel = "Apple Store";
    static String os = "ios";
    static String osVersion = "18.0.2";
    static String udid = "357292741221214";
    static String language = "zh_CN";
}

class CustomHttpHeadersInterceptor extends HttpHeadersInterceptor {
    @override
    Map<String, String> headersInterceptor(Map<String, String> headers) {
        headers["device"] = Constants.deviceMode;
        headers["os"] = Constants.os;
        headers["os-version"] = Constants.osVersion;
        headers["udid"] = Constants.udid;
        headers["channel"] = Constants.channel;
        headers["version"] = Constants.appVersion;
        headers["lang"] = Constants.language;
        headers["system-code"] = Constants.systemCode;
        return headers;
    }
}
```

- Initialize an authenticated HTTP client that adds a token as the `Authorization` header for every AJAX request afterwards.  
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
