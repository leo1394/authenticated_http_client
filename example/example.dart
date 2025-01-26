import 'package:authenticated_http_client/authenticated_http_client.dart';
import 'package:authenticated_http_client/http_headers_interceptor.dart';
import 'package:authenticated_http_client/router_helper.dart';

class Constants {
  static const bool isDeBug = true;
  static String appVersion = "1.0.1";
  static String appBuildNumber = "1394";
  static String systemCode = "f08511c8-3b1c-4008-abba-045787f0b6c0";
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

void main() {
  RouterHelper.init(unAuthCode: "101|103", jump2LoginCallback: () { /* navigate to login route */ });

  AuthenticatedHttpClient.getInstance().init("https://api.company.com", customHttpHeadersInterceptor: CustomHttpHeadersInterceptor());

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

}
