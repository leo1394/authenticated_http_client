
## authenticated_http_client
[![pub package](https://img.shields.io/pub/v/authenticated_http_client.svg)](https://pub.dev/packages/authenticated_http_client)
[![pub points](https://img.shields.io/pub/points/authenticated_http_client?color=2E8B57&label=pub%20points)](https://pub.dev/packages/authenticated_http_client/score)
[![Coverage Status](https://github.com/leo1394/authenticated_http_client/badge.svg?branch=master)](https://coveralls.io/github/leo1394/authenticated_http_client?branch=master)
[![GitHub Issues](https://img.shields.io/github/issues/leo1394/authenticated_http_client.svg?branch=master)](https://github.com/leo1394/authenticated_http_client/issues)
[![GitHub Forks](https://img.shields.io/github/forks/leo1394/authenticated_http_client.svg?branch=master)](https://github.com/leo1394/authenticated_http_client/network)
[![GitHub Stars](https://img.shields.io/github/stars/leo1394/authenticated_http_client.svg?branch=master)](https://github.com/leo1394/authenticated_http_client/stargazers)
[![GitHub License](https://img.shields.io/badge/license-Apache%202-blue.svg)](https://raw.githubusercontent.com/leo1394/authenticated_http_client/master/LICENSE)

An advanced authenticated HTTP client introduces a `factory` feature that generates request futures based on API definitions in a WYSIWYG style, 
with additional supports for `mock` and `silent` modes during development.

- `factory`: generates AJAX request functions by api URI name in WYSIWYG style.
- `mock`: mocking data from a local JSON file for specified requests during development. 
- `silent`: suppress routing redirection for unauthorized or maintenance responses for specified request.
- request futures functions generated can be accessed by dot notation.

## Platform Support

| Android | iOS | MacOS | Web | Linux | Windows |
| :-----: | :-: | :---: |:---:| :---: | :-----: |
|   ✅    | ✅  |  ✅   |  x  |  ✅   |   ✅    |

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
## Steps for Usage in Dart
- initialize RouterHelper managing when and how authenticated http client to redirect login or under maintenance route if needed.
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

- Implement CustomHttpHeadersInterceptor needed in AuthenticatedHttpClient initialization afterwards
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
