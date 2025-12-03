
## authenticated_http_client
[![pub package](https://img.shields.io/pub/v/authenticated_http_client.svg)](https://pub.dev/packages/authenticated_http_client)
[![pub points](https://img.shields.io/pub/points/authenticated_http_client?color=2E8B57&label=pub%20points)](https://pub.dev/packages/authenticated_http_client/score)
[![GitHub Issues](https://img.shields.io/github/issues/leo1394/authenticated_http_client.svg?branch=master)](https://github.com/leo1394/authenticated_http_client/issues)
[![GitHub Forks](https://img.shields.io/github/forks/leo1394/authenticated_http_client.svg?branch=master)](https://github.com/leo1394/authenticated_http_client/network)
[![GitHub Stars](https://img.shields.io/github/stars/leo1394/authenticated_http_client.svg?branch=master)](https://github.com/leo1394/authenticated_http_client/stargazers)
[![GitHub License](https://img.shields.io/badge/license-MIT%20-blue.svg)](https://raw.githubusercontent.com/leo1394/authenticated_http_client/master/LICENSE)

一个支持登陆态管理的 HTTP 客户端，提供 `factory` 生产方法，可按 API 声明以所见即所得（WYSIWYG）的方式生成请求 Future，同时在开发阶段额外支持 `mock` 与 `silent` 模式。

一切从如下简洁的范式约定开始 —— `[mock] [silent] [method] /api/plan/{id}/details` —— 让HTTP请求变得简单可见。

- `factory`：按 API URI 声明以所见即所得方式生成 AJAX 请求函数。
- `mock`：在开发阶段，为指定请求从本地 JSON 文件返回模拟数据。
- `silent`：为指定请求在遇到未授权或维护响应时抑制路由跳转。
- `throttling`：当开启限流时，超量请求将排队（基于 async/await）以控制上传节奏。
- 生成的请求 Future 函数可以通过链式访问。

语言: 中文 | [English](README-EN.md)
## 平台支持

| Android | iOS | MacOS | Web | Linux | Windows |
| :-----: | :-: | :---: |:---:| :---: | :-----: |
|   ✅    | ✅  |  ✅   |  ❌️  |  ✅   |   ✅    |

## 依赖要求

- Flutter >=3.0.0 <4.0.0
- Dart: ^2.17.0
- http: ^1.3.0
- http_interceptor: ^2.0.0

## 开始使用
该库已发布在 pub.dev，运行以下 Flutter 命令安装：
```shell
flutter pub add authenticated_http_client
```

## 快速上手
- 获取 `auth_token` 并将其保存到 `AuthenticatedHttpClient` 的缓存中。
```dart
    var apiService = AuthenticatedHttpClient.getInstance().factory({ "login"  : "POST /api/sign-in" });
    
    apiService.login({"username": "demo", "passwords": "test123"}).then((response) {
        // 响应体格式：{code, message, data}
        final {"auth_token": authToken, "expired_at": expiredAt} = response["data"];
        AuthenticatedHttpClient.getInstance().setAuthToken(authToken);
    });
```

- 创建支持路径参数的请求 Future。
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

- 上传文件请求
```dart
    var apiService = AuthenticatedHttpClient.getInstance().factory({
        "uploadFile"         : "UP /api/file" 
    });
    String localPath = "/local/path/for/upload";
    apiService.uploadFile({"file": localPath}, throttling: true).then((response) {/* success */}).catchError((e, stackTrace){ /* fail */ }).whenComplete((){ /* finally */ });
```

- 下载文件请求
```dart
    String url = "https://assets.xxx.com/path/of/file"; // 或者 /static/file

    var apiService = AuthenticatedHttpClient.getInstance().factory({
        "download"         : "DOWN $downloadUrl" 
    });
    void onReceiveProgress(int received, int total) {
      print("Downloading Progress $received/$total");
    }
    String savePath = "/local/path/for/download";
    // 如果不需要身份校验，可以设置authed: false
    apiService.download(null, savePath: savePath, authenticate: false, onReceiveProgress: onReceiveProgress).then((bytes) {/* success */}).catchError((e, stackTrace){ /* fail */ }).whenComplete((){ /* finally */ });
```

- `mock` 请求将从 `mockDirectory`（默认 `/lib/mock`）中的 JSON 文件加载。可通过 `AuthenticatedHttpClient.getInstance().init()` 配置 `mockDirectory`，并需在 `pubspec.yaml` 的 assets 段落中声明。
```dart
    var apiService = AuthenticatedHttpClient.getInstance().factory({
        "mockRequest"           : "MOCK POST /api/task/config", 
    });

    // 将从 mockDirectory /lib/mock 下的 _POST_api_task_config.json 读取模拟数据
    apiService.mockRequest().then((response) {/* success */}).catchError((e, stackTrace){ /* fail */ }).whenComplete((){ /* finally */ });
```

- `silent` 静默请求在遇到未授权响应或维护中时不会触发路由跳转。
```dart
    var apiService = AuthenticatedHttpClient.getInstance().factory({
        "silentRequest"         : "SILENT GET /api/message/check/unread" 
    });

    // 即便返回 401 也不会跳转到登录页
    apiService.silentRequest().then((response) {/* success */}).catchError((e, stackTrace){ /* fail */ }).whenComplete((){ /* finally */ });
```

- 限流控制：当请求过多时进行排队。
```dart
    var apiService = AuthenticatedHttpClient.getInstance().factory({
        "request"         : "SILENT POST /api/upload" 
    });

    apiService.request(throttling: true).then((response) {/* success */}).catchError((e, stackTrace){ /* fail */ }).whenComplete((){ /* finally */ });
```

- 每个请求都会被标记一个唯一 ID（如 `requestId`）用于追踪，也可通过命名参数传入。
```dart
    var apiService = AuthenticatedHttpClient.getInstance().factory({
        "request"         : "SILENT POST /api/upload" 
    });
    String requestId = Uuid().v1();
    print("gonna send request with unique id : $requestId");
    apiService.request(requestId: requestId).then((response) {/* success */}).catchError((e, stackTrace){ /* fail */ }).whenComplete((){ /* finally */ });
    
```

- `AuthenticatedHttpClient.all` 为一个静态函数，类似 Promise.all，并带有可选延迟功能以避免服务器并发导致的潜在问题。
```dart
    var apiService = AuthenticatedHttpClient.getInstance().factory({
        "requestName"           : "POST /api/submit/plan",
        "requestNameWithParams" : "GET /api/plan/:id/details",
    });

    List<Future> futures = [apiService.requestName(), apiService.requestNameWithParams({"id": 9528})];
    AuthenticatedHttpClient.all(futures, delayInMilliSecs: 350).then((List<dynamic> results){
        print(results[0]); // 第 1 个请求的响应
        print(results[1]); // 第 2 个请求的响应
    });
```

## 在 Dart 中的使用步骤
- 初始化一个 `RouterHelper`，用于在必要时控制何时以及如何跳转至登录页或维护页。
```dart
    import 'package:authenticated_http_client/router_helper.dart';
    
    RouterHelper.init(
        jump2LoginCallback: () { /* 依据你的路由库跳转到登录页 */ },
        unAuthCode: "101|103"
    );
```
<details>
  <summary>使用不同路由库实现 `jump2LoginCallback` 的示例</summary>

```dart
    // FluroRouter 示例
    BuildContext context; // 保存当前构建上下文
    function jump2LoginCallback() {
        String? currentRoute = ModalRoute.of(context)?.settings.name;
        if(currentRoute?.split("?").first == "/login") { return ; }
        FluroRouter().navigateTo(context, "/login", clearStack: true);
    }
```

```dart
    // GoRouter 示例
    BuildContext context; // 保存当前构建上下文
    function jump2LoginCallback() {
        String? currentRoute = GoRouter.of(context).location;
        if(currentRoute?.split("?").first == "/login") { return ; }
        GoRouter(routes: []).go("/login");
    }
```

</details>

- 实现 `CustomHttpHeadersInterceptor`，稍后初始化 `AuthenticatedHttpClient` 时会用到。
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

- 初始化已认证 HTTP 客户端，之后每个 AJAX 请求都会在 Authorization 头中附带 token。
```dart
    import 'package:authenticated_http_client/authenticated_http_client.dart';
    
    AuthenticatedHttpClient.getInstance().init(
        "https://api.company.com", 
        customHttpHeadersInterceptor: CustomHttpHeadersInterceptor()
    );
```

- 最终，你可以按需使用任意功能。
```dart
    var apiService = AuthenticatedHttpClient.getInstance().factory({
        "login"                 : "POST /api/sign-in",
        "requestName"           : "POST /api/submit/plan",
        "requestNameWithParams" : "GET /api/plan/:id/details", // 或 "GET /api/plan/{id}/details"
        "mockRequest"           : "MOCK POST /api/task/config", // 将从 mockDirectory /lib/mock 下的 _post_api_task_config.json 读取模拟数据
        "silentRequest"         : "SILENT GET /api/message/check/unread" // 静默请求在未授权或维护时不跳转
    });
    
    apiService.login({"username": "demo", "passwords": "test123"}).then((response) {
        // 响应体格式：{code, message, data}
        final {"auth_token": authToken, "expired_at": expiredAt} = response["data"];
        AuthenticatedHttpClient.getInstance().setAuthToken(authToken);
    });
    apiService.requestName().then((response) {/* success */}).catchError((e, stackTrace){ /* fail */ }).whenComplete((){ /* finally */ });
    apiService.requestNameWithParams({"id": 9527}).then((response) {/* success */}).catchError((e, stackTrace){ /* fail */ }).whenComplete((){ /* finally */ });
    
    /// AuthenticatedHttpClient.all 是一个静态函数，类似 Promise.all，
    /// 并引入了延迟功能以避免潜在的服务器并发问题
    List<Future> futures = [apiService.requestName(), apiService.requestNameWithParams({"id": 9528})];
    AuthenticatedHttpClient.all(futures, delayInMilliSecs: 350).then((results){
        print(results['0']); // 第 1 个请求的响应
        print(results['1']); // 第 2 个请求的响应
    });
```

## 其他信息
如有问题，欢迎提交 Issue。
