// Copyright (c) 2025, the Dart project authors. Use of this source code
// is governed by a MIT license that can be found in the LICENSE file.

/// An util Class managing when and how authenticated http client to redirect
/// login or under maintenance route if needed.
class RouterHelper {
  static const int _unAuthStatusCode = 401;
  static List<int> _unAuthCode = [101];  // Unauthorized code approved by backend developers.
  static int? _maintenanceCode; // Maintenance code approved by backend developers.
  static Function? _onJump2Login;
  static Function? _onJump2UnderMaintenance;

  /// initialize function
  ///
  /// The `jump2LoginCallback` required argument specifies how to jump to login page,
  /// depends on what your routing library:
  ///
  /// FluroRouter example
  ///
  ///     String? currentRoute = ModalRoute.of(context)?.settings.name;
  ///     if(currentRoute?.split("?").first == "/login") { return ; }
  ///     FluroRouter().navigateTo(context, "/login", clearStack: true);
  ///
  /// GoRouter example
  ///
  ///     String? currentRoute = GoRouter.of(context).location;
  ///     if(currentRoute?.split("?").first == "/login") { return ; }
  ///     GoRouter(routes: []).go("/login");
  ///
  /// The `unAuthCode` optional argument specifies which response (in format {code, message, data})
  /// code (`101` in default) should trigger jump2LoginCallback, split by `|` if multiple code supported.
  ///
  /// The `maintenanceCode` optional argument specifies which response (in format {code, message, data})
  /// code should trigger jump2UnderMaintenanceCallback.
  /// NOTE: If no maintenanceCode specified, means do not support maintenance jump for all requests
  ///
  /// The `jump2UnderMaintenanceCallback` optional argument specifies how to jump to under maintenance page,
  /// depends on what your routing library, similar to `jump2LoginCallback`
  ///
  static void init({
    required Function jump2LoginCallback,
    dynamic unAuthCode,
    int? maintenanceCode,
    Function? jump2UnderMaintenanceCallback
  }){
    assert(unAuthCode == null || unAuthCode is int || unAuthCode is String || unAuthCode is List<int>, "invalid type of unAuthCode !");
    if(unAuthCode is int || unAuthCode is String) {
      _unAuthCode = unAuthCode.toString().split("|").map((ele) => int.parse(ele)).toList();
    } else if (unAuthCode is List<int>){
      _unAuthCode = unAuthCode;
    }

    _maintenanceCode = maintenanceCode;

    _onJump2Login = jump2LoginCallback;
    _onJump2UnderMaintenance = jump2UnderMaintenanceCallback;
  }

  /// Redirect to login route when code or statusCode met.
  static void unAuth({int? code, int? statusCode}) {
    if (!_unAuthCode.contains(code) && statusCode != _unAuthStatusCode) {
      return ;
    }
    print("gonna redirect to login page ....");
    _onJump2Login != null ? Function.apply(_onJump2Login!, []) : null;
  }

  /// Redirect to under maintenance route when code met.
  static void underMaintenance({int? code}) {
    if (code != _maintenanceCode || _maintenanceCode == null) { return ;}
    print("gonna redirect to under maintenance page ....");
    _onJump2UnderMaintenance != null ? Function.apply(_onJump2UnderMaintenance!, []) : null;
  }

  static get unAuthCode => _unAuthCode;
  static get unAuthStatusCode => _unAuthStatusCode;
  static int? get maintenanceCode => _maintenanceCode;

  /// setter for maintenanceCode which decide when http client
  /// need to redirect to under maintenance route.
  /// Note: maintenanceCode can not be `0`, which is reserved for SUCCESS.
  static set maintenanceCode(int? code) {
    if(code == 0) { return ; }
    _maintenanceCode = code;
  }

  /// setter for unAuthCode which decide when http client need
  /// to redirect to login route.
  /// Note: unAuthCode can not be `0`, which is reserved for SUCCESS.
  static set unAuthCode(dynamic code) {
    assert(code is int || code is String || code is List<int>, "invalid type of unAuthCode!");
    if(code is int || code is String) {
      _unAuthCode = code.toString().split("|").map((cc) => int.parse(cc)).where((cc) => cc != 0).toList();
    } else {
      _unAuthCode = code.where((cc) => cc != 0).toList();
    }
  }
}