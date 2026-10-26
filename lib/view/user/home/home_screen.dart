import 'dart:async';
import 'dart:convert';

import 'package:after_layout/after_layout.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:injectable/injectable.dart';
import 'package:intl/intl.dart';
import 'package:miaid/api_utils/api_parser.dart';
import 'package:miaid/api_utils/api_provider.dart';
import 'package:miaid/api_utils/user_provider.dart';
import 'package:miaid/component/miaid_card.dart';
import 'package:miaid/component/nav_bar_icons.dart';
import 'package:miaid/config/app_colors.dart';
import 'package:miaid/dialogs/consultation_language_dialog.dart';
import 'package:miaid/dialogs/targeted_push_dialog.dart';
import 'package:miaid/country/emergency_numbers.dart';
import 'package:miaid/generated/l10n.dart';
import 'package:miaid/main.dart';
import 'package:miaid/notifications/notifications_handler.dart';
import 'package:miaid/payment/additional_services.dart';
import 'package:miaid/services/social_account_service.dart';
import 'package:miaid/store/home/active_subscription_store.dart';
import 'package:miaid/store/home/home_screen_store.dart';
import 'package:miaid/store/home/user_info_store.dart';
import 'package:miaid/store/user/calling/call_screen_store.dart';
import 'package:miaid/store/user/calling/ongoing_call_store.dart';
import 'package:miaid/utils/configure_dependencies.dart';
import 'package:miaid/utils/utils.dart';
import 'package:miaid/view/chatbot/chartbot_history.dart';
import 'package:miaid/view/drawer/about.dart';
import 'package:miaid/view/map/map_screen.dart';
import 'package:miaid/view/user/calling/call_screen_helper.dart';
import 'package:miaid/view/user/e_shop/e_shop.dart';
import 'package:miaid/view/user/home/qrcode_scan.dart';
import 'package:miaid/view/user/user_profile_screen/complete_name.dart';
import 'package:miaid/view/user/user_profile_screen/user_profile_screen.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tap_debouncer/tap_debouncer.dart';
import 'package:flutter_app_badger/flutter_app_badger.dart';
import 'package:eraser/eraser.dart';
import 'package:miaid/with_notification_handler_widget.dart';

import '../../../api_utils/consts.dart';
import '../../../country/translations.dart';
import 'package:http/http.dart' as http;

import '../../../dialogs/appoint_checkin.dart';
import '../../../dialogs/package_redemption.dart';

class HomeScreenParams {
  const HomeScreenParams(this.key);

  final Key key;
}

@injectable
class HomeScreenServices {
  HomeScreenServices(
    this.api,
    this.store,
    this.ongoingCallStore,
    this.activeSubscriptionStore,
    this.userInfoStore,
  );

  final ApiProvider api;
  final OngoingCallStore ongoingCallStore;
  final HomeScreenStore store;
  final ActiveSubscriptionStore activeSubscriptionStore;
  final UserInfoStore userInfoStore;
}

@injectable
class HomeScreen extends StatefulWidget {
  static const routeName = '/home';

  HomeScreen({
    @factoryParam this.params,
    required this.services,
  }) : super(key: params?.key);

  final HomeScreenParams? params;
  final HomeScreenServices services;

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with AfterLayoutMixin<HomeScreen>, WidgetsBindingObserver, RouteAware {

  var emergency_number = '000';
  var remaining_consultations = '0';

  @override
  void initState() {
    _initEmergencyAndConsultationData();

    final store = widget.services.store;
    store.initState().whenComplete(() => setState(() {}));
    store.fetchCountryCode();

    if (store.user.isLoggedIn) {
      widget.services.activeSubscriptionStore.fetchActiveSubscription();
    }

    WidgetsBinding.instance.addObserver(this);
    _fetchEmergencyNumber();
    _fetchRemainingConsultations();

    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 订阅路由变化，感知上层页面 pop 回首页（didPopNext）。
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
    }
  }

  /// 上层页面（旅行套餐、加叫服务、通话等）pop 回首页时刷新剩余次数。
  /// Stripe 购买成功后返回首页，剩余次数才能实时更新，
  /// 不需要再从抽屉重新进首页。
  @override
  void didPopNext() {
    _fetchRemainingConsultations();
  }

  @override
  void didUpdateWidget(HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 防御：若路由 builder 被重新执行（如切换语言导致 MaterialApp 重建）而生成了新的
    // services/store，新 store 的国家信息为空，这里用缓存回填，避免界面退回“获取定位”
    if (!identical(oldWidget.services, widget.services)) {
      widget.services.store.loadCachedCountryCode();
    }
  }

  Future<void> _initEmergencyAndConsultationData() async {
    final prefs = await SharedPreferences.getInstance();
    // 剩余次数缓存只对已登录用户有效，未登录一律显示 0。
    final isLoggedIn = getIt<UserProvider>().isLoggedIn;
    setState(() {
      emergency_number = prefs.getString('current_emergency_number') ?? '000';
      remaining_consultations =
          isLoggedIn ? (prefs.getString('remaining_consultations') ?? '0') : '0';
    });
  }

  void _fetchEmergencyNumber() async {
    try {
      // 真机正常路径：定位成功 -> 解析国家 -> 更新急救号码
      final position = await determinePosition(desiredAccuracy: LocationAccuracy.medium);
      final countryCode = await getCountryCodeFromLocation(position);
      if (countryCode == null) return;
      final emergencyCode = EmergencyNumbers.getNumber(countryCode);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('current_emergency_number', emergencyCode);
      if (mounted) setState(() => emergency_number = emergencyCode);
    } catch (e) {
      // 定位失败（如模拟器未设置模拟定位）时保留已从缓存加载的急救号码，不中断页面。
      // 真机定位正常时不会进入此分支。
      debugPrint('fetchEmergencyNumber failed: $e');
    }
  }

  void  _fetchRemainingConsultations() async {
    final userProvider = getIt<UserProvider>();
    if (userProvider.isLoggedIn && userProvider.user?.doctor == null && userProvider.user?.translator == null) {
      final api = getIt<ApiProvider>();
      final userId = api.userProvider.user!.id.toString();
      final accessToken = api.userProvider.user!.accessToken!;
      final headers = <String, String>{
        'x-user-id': userId,
        'x-api-key': api.apiKey,
        'x-access-token': accessToken
      };

      try {
        final position = await determinePosition(desiredAccuracy: LocationAccuracy.medium);
        final countryCode = await getCountryCodeFromLocation(position);

        final url = Uri.parse(api.baseUrl+'/api/v1/remaining-consultations?userId=$userId&countryCode=$countryCode');
        final response = await http.get(url, headers: headers);

        if (response.statusCode == 200) {
          var remaining_count = jsonDecode(response.body)['remaining_consultations'].toString();
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('remaining_consultations', remaining_count);
          setState(() => remaining_consultations = remaining_count);
        }
      } catch (e) {
        debugPrint(e.toString());
      }
    } else {
      // 未登录（或医生/翻译端）没有剩余次数概念，显示重置为 0，
      // 防止登出后首页实例复用时残留上个账号的数字。
      if (mounted) setState(() => remaining_consultations = '0');
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void afterFirstLayout(BuildContext context) {
    _checkAppVersion();
    _checkAndShowIncomingCalls();
    _showHomeEntryDialogs();
  }

  /// 进入首页时按顺序弹出的对话框：先语言选择，再商品定向推送，避免两个弹框叠在一起。
  /// 语言选择仅冷启动后第一个首页生效；商品定向推送只在 App 启动后和登录成功后
  /// 第一次进入首页弹（见 TargetedPushTrigger），抽屉重建首页、后台恢复都不弹。
  Future<void> _showHomeEntryDialogs() async {
    await ConsultationLanguageDialog.showOnHomeEntry(context, isColdLaunch: true);
    if (!mounted) return;
    await TargetedPushDialog.showOnHomeEntry(context);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkAndShowIncomingCalls();
      _checkAppVersion();
      // 情况2：App 从后台恢复回到首页时弹出。页面内导航返回首页不会触发此回调，故不会重复弹。
      ConsultationLanguageDialog.showOnHomeEntry(context, isColdLaunch: false);
    } else if (state == AppLifecycleState.inactive) {
      Eraser.clearAllAppNotifications();
      FlutterAppBadger.removeBadge();
    }
  }

  /// 首页问候语的补填姓名入口；保存后 UserInfoStore 已更新，问候语自动显示名字
  Future<void> _openCompleteName() async {
    await Navigator.push(context, MaterialPageRoute<bool>(
      builder: (context) => CompleteNameScreen(
        service: SocialAccountService(widget.services.api),
      ),
    ),);
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.services.store;
    // iPad/平板上把右上角图标适当放大（手机保持原尺寸）。
    final isTablet = MediaQuery.of(context).size.shortestSide >= 600;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        elevation: 0,
        backgroundColor: AppColors.kffffff,
        centerTitle: true,
        title: Text(
          //'MiAid',
          Intl.getCurrentLocale().isEmpty || Intl.getCurrentLocale() == 'zh' ? '脉康连' : 'MiAid',
          style: GoogleFonts.rubik(
            color: AppColors.k010101,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(
              right: 13,
              top: 10,
              bottom: 10,
            ),
            child: InkWell(
              child: Icon(Icons.qr_code, color: AppColors.k0cbcc5, size: isTablet ? 32 : 24,),
              onTap: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => QrCodeScan()),
                );
                // 扫码页可能返回三种值：Map(成功)、''(扫到非法码)、null(用户点返回)。
                // 此前用 result.toString().isNotEmpty 判断，null 会被当成有效值再取下标导致崩溃。
                if (result is Map) {
                  var hospitalName = result['hospital_name'];
                  if (result['type'] == Consts.CheckInQrcode) {
                    await AppointCheckInDialog.show(hospitalName);
                  }
                  if (result['type'] == Consts.RedemptionQrcode) {
                    var hospitalId = result['hospital_id'];
                    await PackageRedemptionDialog.show(hospitalId, hospitalName);
                  }
                } else if (result == '') {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(S.of(context).qrcode_invalid)),
                  );
                }
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(
              right: 13,
              top: 10,
              bottom: 10,
            ),
            child: InkWell(
              onTap: () {
                final action = CupertinoActionSheet(
                  message: Text(S.of(context).changeLanguage, style: TextStyle(
                    fontSize: 13.0,
                    color: AppColors.k8f8e94,
                  ),),
                  actions: <Widget>[
                    CupertinoActionSheetAction(
                      isDefaultAction: Intl.getCurrentLocale() == 'en' ? true : false,
                      onPressed: () async {
                        Localizations.override(context: context, locale: Locale('en'));
                        await store.setLanguageCode('en');

                        Navigator.pop(context);
                        setState(() {});
                      },
                      child: Text('English', style: GoogleFonts.rubik(
                        color: AppColors.k0cbcc5,
                        fontSize: 20,
                      ),),
                    ),
                    CupertinoActionSheetAction(
                      isDefaultAction: Intl.getCurrentLocale() == 'zh' ? true : false,
                      onPressed: () async {
                        Localizations.override(context: context, locale: Locale('zh'));
                        await store.setLanguageCode('zh');
                        Navigator.pop(context);
                        setState(() {});
                      },
                      child: Text('简体中文', style: GoogleFonts.rubik(
                        color: AppColors.k0cbcc5,
                        fontSize: 20,
                      ),),
                    ),
                    CupertinoActionSheetAction(
                      isDefaultAction: Intl.getCurrentLocale() == 'zh_Hant' ? true : false,
                      onPressed: () async {
                        Localizations.override(context: context, locale: Locale('zh'));
                        await store.setLanguageCode('zh_Hant');
                        Navigator.pop(context);
                        setState(() {});
                      },
                      child: Text('繁体中文', style: GoogleFonts.rubik(
                        color: AppColors.k0cbcc5,
                        fontSize: 20,
                      ),),
                    ),
                    CupertinoActionSheetAction(
                      isDefaultAction: Intl.getCurrentLocale() == 'ko' ? true : false,
                      onPressed: () async {
                        Localizations.override(context: context, locale: Locale('ko'));
                        await store.setLanguageCode('ko');
                        Navigator.pop(context);
                        setState(() {});
                      },
                      child: Text('한국인', style: GoogleFonts.rubik(
                        color: AppColors.k0cbcc5,
                        fontSize: 20,
                      ),),
                    ),
                    CupertinoActionSheetAction(
                      isDefaultAction: Intl.getCurrentLocale() == 'id' ? true : false,
                      onPressed: () async {
                        Localizations.override(context: context, locale: Locale('id'));
                        await store.setLanguageCode('id');
                        Navigator.pop(context);
                        setState(() {});
                      },
                      child: Text('Indonesia', style: GoogleFonts.rubik(
                        color: AppColors.k0cbcc5,
                        fontSize: 20,
                      ),),
                    ),
                    CupertinoActionSheetAction(
                      isDefaultAction: Intl.getCurrentLocale() == 'el' ? true : false,
                      onPressed: () async {
                        Localizations.override(context: context, locale: Locale('el'));
                        await store.setLanguageCode('el');
                        Navigator.pop(context);
                        setState(() {});
                      },
                      child: Text('Ελληνικά', style: GoogleFonts.rubik(
                        color: AppColors.k0cbcc5,
                        fontSize: 20,
                      ),),
                    )
                  ],
                  cancelButton: CupertinoActionSheetAction(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: Text(S.of(context).cancel, style: GoogleFonts.rubik(
                      color: AppColors.k0cbcc5,
                      fontSize: 20,
                    ),),
                  ),
                );
                showCupertinoModalPopup(
                  context: context,
                  // barrier 不响应点击关闭：iPad 大屏上，右上角触发的点击落点在底部弹框之外的
                  // barrier 区域，会被 barrier 接收并立刻 dismiss，表现为「弹出即消失」。
                  // 弹框本身保留「取消」按钮，关闭体验不受影响。
                  barrierDismissible: false,
                  builder: (popupContext) {
                    // CupertinoActionSheet 横屏时按屏幕较短边(height)计算宽度，iPad 横屏下会变窄；
                    // 这里强制以竖屏方式计算，让弹框横向铺满屏宽。
                    final mq = MediaQuery.of(popupContext);
                    return MediaQuery(
                      data: mq.copyWith(size: Size(mq.size.width, mq.size.width + 1)),
                      child: action,
                    );
                  },
                );
              },
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.keefeff,
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.k003f51.withOpacity(0.1),
                      blurRadius: 10.0,
                      spreadRadius: 0.0, //extend the shadow
                      offset: Offset(0, 4,),
                    ),
                  ],
                ),
                child: Center(child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: isTablet ? 14 : 10, vertical: 0,),
                  child: Observer(builder: (context) => Text(
                    store.languageCode == 'zh' ? '简' : (store.languageCode == 'zh_Hant' ? '繁' : (store.languageCode ?? 'en')).toUpperCase(),
                    style: GoogleFonts.rubik(
                      color: AppColors.k0cbcc5,
                      fontSize: isTablet ? 20 : 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),),
                ),),
              ),
            ),
          ),
        ],
        leading: InkWell(
          // 抽屉挂在外层 MainTabs 的 Scaffold 上（才能盖住底部导航），这里打开最外层那个
          onTap: () => context.findRootAncestorStateOfType<ScaffoldState>()?.openDrawer(),
          child: navBarIcon(iconAssetName: 'ic_nb_menu.png'),
        ),
      ),
      body: WithNotificationHandlerWidget(
        handler: getIt<NotificationHandler>(),
        child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
          // Header section
          SizedBox(
            width: double.infinity,
            child: Padding(
              padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Observer(builder: (context) => RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: S.of(context).hi+', ',
                          style: GoogleFonts.rubik(
                            color: AppColors.k010101,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (widget.services.userInfoStore.firstName.trim().isEmpty)
                          // 第三方登录可能拿不到姓名：问候语后面给一个补填入口，不让"您好，"后面空着
                          TextSpan(
                            recognizer: TapGestureRecognizer()..onTap = _openCompleteName,
                            text: S.of(context).setYourName,
                            style: GoogleFonts.rubik(
                              color: AppColors.k0cbcc5,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.underline,
                              decorationColor: AppColors.k0cbcc5,
                            ),
                          )
                        else
                          TextSpan(
                            recognizer: TapGestureRecognizer()..onTap = () {
                              Navigator.push(context, MaterialPageRoute<void>(
                                builder: (context) => getIt<UserProfileScreen>(),
                              ),);
                            },
                            text: widget.services.userInfoStore.firstName,
                            style: GoogleFonts.rubik(
                              color: AppColors.k010101,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                  ),),
                  SizedBox(height: 8,),
                  // 整句固定在一行：放不下时等比缩小字号，不换行
                  Observer(builder: (context) => SizedBox(
                    width: double.infinity,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        S.of(context).youAreInCountry(country(context, store)) + ', ' + S.of(context).needHelp,
                        style: GoogleFonts.rubik(
                          color: AppColors.k5e5e5e,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        softWrap: false,
                      ),
                    ),
                  ),),
                  SizedBox(height: 6,),
                  InkWell(
                    child: Text(S.of(context).get_location, style: GoogleFonts.rubik(
                      color: AppColors.k0cbcc5,
                      fontSize: 14,
                      decoration: TextDecoration.underline,
                      decorationColor: AppColors.k0cbcc5,
                    ),),
                    onTap: () async {
                      final position = await determinePosition(desiredAccuracy: LocationAccuracy.medium);
                      await showDialog(
                        context: context,
                        builder: (_) => AlertDialog(
                          alignment: Alignment.center,
                          title: Text(
                            S.of(context).location_info,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.rubik(
                              fontSize: 16,
                              fontWeight: FontWeight.bold
                            )
                          ),
                          content: SizedBox(
                            height: 75,
                            child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
                              Divider(height: 10, color: Colors.black12,),
                              SizedBox(height: 10,),
                              Text(
                                S.of(context).longitude+': ${position.longitude}',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.rubik(
                                  fontSize: 14,
                                  fontWeight: FontWeight.normal,
                                )
                              ),
                              SizedBox(height: 10,),
                              Text(
                                S.of(context).latitude+': ${position.latitude}',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.rubik(
                                  fontSize: 14,
                                  fontWeight: FontWeight.normal
                                )
                              )
                            ],),
                          ),
                          actions: [
                            MaterialButton(
                              onPressed: () => Navigator.of(context).pop(context),
                              minWidth: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 7),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                              color: AppColors.k0cbcc5,
                              child: Text(S.of(context).cancel, style: GoogleFonts.roboto(
                                color: AppColors.kffffff,
                                fontSize: 16,
                              )),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          // Emergency + Consultations buttons
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, top: 0, bottom: 16),
            child: IntrinsicHeight(child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Emergency button (red)
                Expanded(child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.ke63030,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.phone_iphone, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Flexible(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Observer(builder: (context) => Text(
                              emergency_number,
                              style: GoogleFonts.rubik(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            )),
                            Text(
                              S.of(context).dial + ' ' + S.of(context).emergency,
                              style: GoogleFonts.rubik(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 11,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                            ),
                          ],
                        )),
                      ],
                    ),
                  ),
                )),
                const SizedBox(width: 12),
                // Available Consultations button (teal)
                Expanded(child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.k0cbcc5,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.chat_bubble_outline, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Flexible(child: Observer(builder: (context) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$remaining_consultations',
                                style: GoogleFonts.rubik(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                              Text(
                                S.of(context).remainingConsultations,
                                style: GoogleFonts.rubik(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 11,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 2,
                              ),
                            ],
                          );
                        })),
                      ],
                    ),
                  ),
                )),
              ],
            )),
          ),
          const SizedBox(height: 4),
          const Divider(height: 1, thickness: 1, indent: 16, endIndent: 16, color: Color(0xFFE8E8E8)),
          SizedBox(height: Utils.isPad(context) ? 12 : 0),
          // AI Banner
          _aiBanner(context),
          SizedBox(height: Utils.isPad(context) ? 24 : 16,),
          // Service cards 2x2 grid
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16),
            child: Column(
              children: [
                IntrinsicHeight(child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Customer Care
                    _serviceCard(
                      context,
                      icon: Icons.favorite,
                      title: S.of(context).videoDoctor,
                      onTap: () async {
                        var sharedPreferences = await SharedPreferences.getInstance();
                        await sharedPreferences.setString('video-call-source', 'home');
                        await navigateToCallScreen(context, widget.services.activeSubscriptionStore, VIDEO_CALL_TYPE.CONSULT_A_DOCTOR,);
                      },
                    ),
                    const SizedBox(width: 12),
                    // ED and Clinics Near Me
                    _serviceCard(
                      context,
                      icon: Icons.add,
                      title: S.of(context).edandClinic,
                      onTap: () async {
                        await Navigator.push(context, MaterialPageRoute<void>(
                          builder: (context) => getIt<MapScreen>(),
                        ),);
                      },
                    ),
                  ],
                )),
                const SizedBox(height: 12),
                IntrinsicHeight(child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // e-Shop
                    _serviceCard(
                      context,
                      icon: Icons.shopping_cart,
                      title: S.of(context).eShop,
                      onTap: () async {
                        await Navigator.push(context, MaterialPageRoute<void>(
                          builder: (context) => getIt<EShop>(),
                        ),);
                      },
                    ),
                    const SizedBox(width: 12),
                    // Services
                    _serviceCard(
                      context,
                      icon: Icons.medical_services,
                      title: S.of(context).otherService,
                      onTap: () async {
                        await Navigator.push(context, MaterialPageRoute<void>(
                          builder: (context) => getIt<AdditionalServices>(),
                        ),);
                      },
                    ),
                  ],
                )),
              ],
            ),
          ),
          // 底部留白：「关于」栏已固定在页面底部（bottomNavigationBar），不再跟着内容滚动
          const SizedBox(height: 30),
        ],),),
      ),
      bottomNavigationBar: _aboutFooter(context),
    );
  }

  /// 「关于脉康连 / About MiAid」固定在页面底部，内容区在其上方滚动。
  /// 深色底延伸进 iOS 底部安全区，避免 Home 指示条处露出一截白边。
  Widget _aboutFooter(BuildContext context) {
    return Material(
      color: AppColors.k2e2e2e,
      child: InkWell(
        onTap: () {
          Navigator.push(context, MaterialPageRoute<void>(
            builder: (context) => getIt<AboutMiAid>(),
          ),);
        },
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Image(image: AssetImage('assets/images/ic_home_about.png')),
                const SizedBox(width: 16.33),
                Flexible(child: Text(S.of(context).about, style: GoogleFonts.rubik(
                  color: AppColors.k0cbcc5,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ), maxLines: 1, overflow: TextOverflow.ellipsis,),),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String country(BuildContext context, HomeScreenStore store) {
    if (store.countryCode != null) {
      var countryCode = store.countryCode.toString().toUpperCase();
      var currentLang = Intl.getCurrentLocale().toString().toLowerCase();
      if (Countries.AllCountryNames.containsKey(countryCode) && Countries.AllCountryNames[countryCode]!.containsKey(currentLang)) {
        return Countries.AllCountryNames[countryCode]![currentLang]!.toString();
      }

      return CountryCode.fromCountryCode(store.countryCode!).localize(context).name ?? '';
    }
    return '';
  }

  Future<void> _checkAndShowIncomingCalls() async {
    final api = getIt<ApiProvider>();
    final user = getIt<UserProvider>();

    if (!user.isLoggedIn) return;

    // hasPendingCall is set synchronously at the start of initEngine: while a
    // call is being established, any app resume (e.g. permission dialogs,
    // lock screen) landing here would find the just-created active call and
    // push a second CallScreen, whose second joinChannel gets rejected by
    // Agora with -17 and tears down the whole call
    if (widget.services.ongoingCallStore.hasPendingCall ||
        widget.services.ongoingCallStore.hasOngoingCall) return;

    final response = await api.apiClientMain.callsPostCallActive();
    if (ApiSuccessParser.isSuccessfulWithPayload(response)) {
      await widget.services.ongoingCallStore.showIncomingCallDialogOrGoToCallScreen(context, response.body!.payload!);
    }
  }

  Future<void> _checkAppVersion() async {
    final api = getIt<ApiProvider>();

    var packageInfo = await PackageInfo.fromPlatform();

    var version = packageInfo.version;
    final response = await api.apiClient.settingsGetCheckAppVersion(app_version: version);
    final appVersionResponse = response.body;
    if (appVersionResponse != null && appVersionResponse.status != true) {
      await widget.services.ongoingCallStore.ongoingCallStore(context, appVersionResponse);
    }
  }

  /// 首页 AI 入口。背景用设计给的 assets/ai_banner.png（6104×1200 原图缩到 3052 宽，
  /// 机器人与装饰圆都在图里），高度按「旧 banner 在当前宽度下的高度 × 1.2」算；
  /// 图比这个高度宽得多，用 cover 居中裁切（手机上只显示图中间约 45%，机器人会被裁掉，
  /// 用户要求先看居中效果；之前是靠右裁切保留机器人）。
  /// 圆角半径按图片自身的圆角比例换算，避免右侧两个角露出图片的透明边。
  Widget _aiBanner(BuildContext context) {
    final isPad = Utils.isPad(context);
    // 旧 banner 的宽高比：banner.png 1520×568，banner_pad.png 1526×300
    final oldAspect = isPad ? 1526 / 300 : 1520 / 568;
    const heightScale = 1.2;
    // ai_banner.png 的圆角约为图高的 4.6%
    const imageCornerRatio = 55 / 1200;

    return Padding(
      padding: EdgeInsets.only(left: 16, right: 16, top: isPad ? 16 : 12),
      child: LayoutBuilder(builder: (context, constraints) {
        final height = constraints.maxWidth / oldAspect * heightScale;
        final radius = BorderRadius.circular(height * imageCornerRatio);
        return TapDebouncer(
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (context) => ChatbotHistory(services: widget.services.activeSubscriptionStore,)),
            );
          },
          builder: (context, onTap) => InkWell(
            onTap: onTap,
            borderRadius: radius,
            child: Container(
              // 父级 Column 给的是宽松约束，不写死宽度会收缩到文字宽（中文标题短时尤其明显）
              width: double.infinity,
              height: height,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: radius,
                color: const Color(0xFF052A28),
                // 图片自带浅灰描边，左边被裁掉后这里补一圈同色描边
                border: Border.all(color: const Color(0xFFB9C6C5), width: 1),
                image: const DecorationImage(
                  image: AssetImage('assets/ai_banner.png'),
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                ),
              ),
              child: Padding(
                // 居中裁切时手机上看不到机器人，右侧只留少量空白；iPad 还能看到大半机器人
                padding: EdgeInsets.only(
                  left: isPad ? 40 : 24,
                  right: constraints.maxWidth * (isPad ? 0.3 : 0.2),
                  top: 16,
                  bottom: 16,
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        S.of(context).bannerTitle,
                        style: GoogleFonts.rubik(
                          color: Colors.white,
                          fontSize: isPad ? 24 : 17,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          S.of(context).bannerButton,
                          style: GoogleFonts.rubik(
                            color: AppColors.k0cbcc5,
                            fontSize: isPad ? 18 : 13,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  /// 服务入口卡片：图标和名称横向一行，比原来上下两行的版本更紧凑。
  /// 四个入口都经过 TapDebouncer，防止连点重复进入页面。
  Widget _serviceCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Future<void> Function() onTap,
  }) {
    return Expanded(
      child: TapDebouncer(
        onTap: onTap,
        builder: (context, debouncedTap) => InkWell(
          onTap: debouncedTap,
          borderRadius: BorderRadius.circular(15),
          child: miAidCard(Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.k0cbcc5,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(icon, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(title, style: GoogleFonts.rubik(
                    color: AppColors.k010101,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ), maxLines: 2, overflow: TextOverflow.ellipsis,),
                ),
              ],
            ),
          )),
        ),
      ),
    );
  }
}
