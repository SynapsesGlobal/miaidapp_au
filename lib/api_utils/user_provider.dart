import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:injectable/injectable.dart';
import 'package:miaid/generated_api_code/api_client.swagger.dart';
import 'package:miaid/services/location_upload_service.dart';
import 'package:miaid/store/home/active_subscription_store.dart';
import 'package:miaid/store/home/user_info_store.dart';
import 'package:miaid/store/user/calling/ongoing_call_store.dart';
import 'package:miaid/utils/configure_dependencies.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_provider.dart';
import 'device_id_provider.dart';

@module
abstract class SharedPreferencesModule {
  @preResolve
  Future<SharedPreferences> get sharedPreferences =>
      SharedPreferences.getInstance();
}

/// This class hold the user object across the entire app.
@preResolve
@singleton
class UserProvider {
  static const String _kUserAccessToken = 'accessToken';
  static const String _kUserLoginType = 'lastLoginUserType';

  UserProvider(this.sharedPreferences, DeviceIdProvider deviceIdProvider)
      : deviceId = deviceIdProvider.deviceId;

  @factoryMethod
  static Future<UserProvider> create(SharedPreferences sharedPreferences,
      DeviceIdProvider deviceIdProvider) async {
    final userProvider = UserProvider(sharedPreferences, deviceIdProvider);
    return userProvider;
  }

  final SharedPreferences sharedPreferences;
  final DeviceId deviceId;

  User? _user;

  /// Returns the User if logged in. null otherwise
  User? get user => _user;

  bool get isDoctor => _user?.doctor != null;

  bool get isTranslator => _user?.translator != null;

  bool get isCustomer => _user?.customer != null;

  /// Returns true if the User is logged in
  bool get isLoggedIn => _user != null;

  bool get hasAvailableSubscriptions => _user?.availableSubscriptions != 0;

  /// Call this function when the user logs in
  void onLogIn(User user) async {
    _user = user;
    await _setAccessToken(_user!.accessToken);
    await _setLastLoginUserType(_user?.doctor != null
        ? 'doctor'
        : _user?.translator != null
            ? 'translator'
            : 'customer');

    final userInfoStore = getIt<UserInfoStore>();
    userInfoStore.setFirstName(_user?.firstName ?? '');
  }

  /// Call this function when the user is updated
  void onUserUpdated(User user) async {
    _user = user.copyWith(accessToken: _user?.accessToken);

    final userInfoStore = getIt<UserInfoStore>();
    userInfoStore.setFirstName(_user?.firstName ?? '');
  }

  Future<void> updateUserToken(String token) async {
    _user = _user?.copyWith(accessToken: token);
    await _setAccessToken(token);
  }

  /// Call this function when the user logs out or is logged out
  Future<void> logOut() async {
    try {
      await EasyLoading.show(
          status: 'Logging out...', maskType: EasyLoadingMaskType.clear);

      final api = getIt<ApiProvider>();
      await api.apiClient.authGetLogout(accept: null);
    } catch (e) {
      // print('Could not logout user on the server: $e');
    }

    await _resetUserRelatedData();

    await EasyLoading.dismiss();
  }

  Future<void> deleteAccount() async {
    try {
      await EasyLoading.show(
          status: 'Deleting user data...', maskType: EasyLoadingMaskType.clear);

      final api = getIt<ApiProvider>();
      await api.apiClient.authGetDeleteUser(accept: null);
    } catch (e) {
      // print('Could not logout user on the server: $e');
    }

    await _resetUserRelatedData();

    await EasyLoading.dismiss();
  }

  Future<void> _setAccessToken(String? accessToken) async {
    if (accessToken != null) {
      await sharedPreferences.setString(_kUserAccessToken, accessToken);
    } else {
      await sharedPreferences.remove(_kUserAccessToken);
    }
  }

  String? get _accessToken => sharedPreferences.getString(_kUserAccessToken);

  Future<void> _setLastLoginUserType(String? userType) async {
    if (userType != null) {
      await sharedPreferences.setString(_kUserLoginType, userType);
    } else {
      await sharedPreferences.remove(_kUserLoginType);
    }
  }

  String? get _lastLoginUserType =>
      sharedPreferences.getString(_kUserLoginType);

  Future<User?> getUserOnAppStart() async {
    final api = getIt<ApiProvider>();
    if (_accessToken != null && _accessToken!.isNotEmpty) {
      // print('AccessToken $_accessToken');
      try {
        _user = User(accessToken: _accessToken);

        final apiClient =
            _lastLoginUserType == 'doctor' || _lastLoginUserType == 'translator'
                ? api.apiClientMain
                : api.apiClientSub;

        var profile = await apiClient.profileGetMyProfile();
        _user = profile.body?.payload?.copyWith(accessToken: _accessToken);

        final userInfoStore = getIt<UserInfoStore>();
        userInfoStore.setFirstName(_user?.firstName ?? '');

        return _user;
      } catch (e) {
        _user = null;
      }
    }
    return null;
  }

  Future<void> _resetUserRelatedData() async {
    // 停止定位上传并清掉本地追踪开关缓存：在这里统一处理，
    // 覆盖所有登出路径（抽屉登出、401 强制登出、注销账号）。
    if (await LocationUploadService.isRunning) {
      await LocationUploadService.stop();
    }
    await sharedPreferences.remove('open_position_tracking');

    // 首页剩余问诊次数缓存与账号绑定，登出时必须清掉，
    // 否则下个登录账号（或未登录状态）会短暂显示上个账号的次数。
    await sharedPreferences.remove('remaining_consultations');

    await _setAccessToken(null);
    await _setLastLoginUserType(null);
    _user = null;
    final userInfoStore = getIt<UserInfoStore>();
    userInfoStore.setFirstName('');
    final activeSubscriptionStore = getIt<ActiveSubscriptionStore>();
    activeSubscriptionStore.resetActiveSubscription();

    // clean up ongoing call
    final ongoingCallStore = getIt<OngoingCallStore>();
    ongoingCallStore.setOngoingCall(ongoingCall: null);
    ongoingCallStore.setHasPendingCall(false);
  }
}
