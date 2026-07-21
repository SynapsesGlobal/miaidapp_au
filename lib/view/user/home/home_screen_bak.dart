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
import 'package:miaid/component/miaid_drawer.dart';
import 'package:miaid/component/nav_bar_icons.dart';
import 'package:miaid/config/app_colors.dart';
import 'package:miaid/country/emergency_numbers.dart';
import 'package:miaid/generated/l10n.dart';
import 'package:miaid/notifications/notifications_handler.dart';
import 'package:miaid/payment/additional_services.dart';
import 'package:miaid/store/home/active_subscription_store.dart';
import 'package:miaid/store/home/home_screen_store.dart';
import 'package:miaid/store/home/user_info_store.dart';
import 'package:miaid/store/user/calling/call_screen_store.dart';
import 'package:miaid/store/user/calling/ongoing_call_store.dart';
import 'package:miaid/utils/configure_dependencies.dart';
import 'package:miaid/utils/utils.dart';
import 'package:miaid/view/affiliate/affiliate.dart';
import 'package:miaid/view/chatbot/chartbot_history.dart';
import 'package:miaid/view/drawer/about.dart';
import 'package:miaid/view/map/map_screen.dart';
import 'package:miaid/view/user/calling/call_screen_helper.dart';
import 'package:miaid/view/user/e_shop/e_shop.dart';
import 'package:miaid/view/user/home/mobile_scanner.dart';
import 'package:miaid/view/user/home/qrcode_scan.dart';
import 'package:miaid/view/user/sign_in/sign_in.dart';
import 'package:miaid/view/user/user_profile_screen/user_profile_screen.dart';
import 'package:miaid/widget/custom_dialog.dart';
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
import '../../../services/location_upload_service.dart';

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
    with AfterLayoutMixin<HomeScreen>, WidgetsBindingObserver {

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
    initLocationListening();
    _fetchEmergencyNumber();
    _fetchRemainingConsultations();

    super.initState();
  }

  Future<void> _initEmergencyAndConsultationData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      emergency_number = prefs.getString('current_emergency_number') ?? '000';
      remaining_consultations = prefs.getString('remaining_consultations') ?? '0';
    });
  }

  void _fetchEmergencyNumber() async {
    final position = await determinePosition(desiredAccuracy: LocationAccuracy.medium);
    final countryCode = await getCountryCodeFromLocation(position);
    final emergencyCode = EmergencyNumbers.getNumber(countryCode!);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('current_emergency_number', emergencyCode);
    setState(() => emergency_number = emergencyCode);
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
    }
  }

  Future<dynamic> initLocationListening() async {
    final userProvider = getIt<UserProvider>();
    if (userProvider.isLoggedIn && userProvider.user?.doctor == null && userProvider.user?.translator == null) {
      final api = getIt<ApiProvider>();
      final headers = <String, String>{
        'x-user-id': api.userProvider.user!.id.toString(),
        'x-api-key': api.apiKey,
      };

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('base_url', api.baseUrl);
      await prefs.setString('api_key', api.apiKey);
      await prefs.setString('user_id', api.userProvider.user!.id.toString());

      try {
        final url = Uri.parse(api.baseUrl+'/api/v1/position/index');
        final response = await http.post(url, headers: headers, body: {'source': 'au'});

        if (response.statusCode == 200) {
          var responseData = jsonDecode(response.body)['payload'];
          var _opened = responseData['open_position_tracking'].toString() == '1';
          if (_opened) {
            await LocationUploadService.start();
          }
        }
      } catch (e) {
        print(e);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void afterFirstLayout(BuildContext context) {
    _checkAppVersion();
    _checkAndShowIncomingCalls();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkAndShowIncomingCalls();
      _checkAppVersion();
      // _checkAndShowIncomingCalls();
    } else if (state == AppLifecycleState.inactive) {
      Eraser.clearAllAppNotifications();
      FlutterAppBadger.removeBadge();
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.services.store;
    return Scaffold(
      backgroundColor: Colors.white,
      drawer: getDrawer(store.user),
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
              child: Icon(Icons.qr_code, color: AppColors.k0cbcc5,),
              onTap: () async {
                if (store.user.isLoggedIn) {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => QrCodeScan()),
                  );
                  if (result.toString().isNotEmpty) {
                    var hospitalName = result['hospital_name'];
                    if (result['type'] == Consts.CheckInQrcode) {
                      await AppointCheckInDialog.show(hospitalName);
                    }
                    if (result['type'] == Consts.RedemptionQrcode) {
                      var hospitalId = result['hospital_id'];
                      await PackageRedemptionDialog.show(hospitalId, hospitalName);
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(S.of(context).qrcode_invalid)),
                    );
                  }
                } else {
                  showAlertDialog(context);
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
                        fontSize: 24,
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
                        fontSize: 24,
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
                        fontSize: 24,
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
                        fontSize: 24,
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
                        fontSize: 24,
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
                        fontSize: 24,
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
                showCupertinoModalPopup(context: context, builder: (context) => action);
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
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0,),
                  child: Observer(builder: (context) => Text(
                    store.languageCode == 'zh' ? '简' : (store.languageCode == 'zh_Hant' ? '繁' : (store.languageCode ?? 'en')).toUpperCase(),
                    style: GoogleFonts.rubik(
                      color: AppColors.k0cbcc5,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),),
                ),),
              ),
            ),
          ),
        ],
        leading: Builder(builder: (BuildContext context) => InkWell(
          onTap: () {
            Scaffold.of(context).openDrawer();
          },
          child: navBarIcon(iconAssetName: 'ic_nb_menu.png'),
        )),
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
                        if (store.user.isLoggedIn)
                          TextSpan(
                            text: S.of(context).hi+', ',
                            style: GoogleFonts.rubik(
                              color: AppColors.k010101,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        TextSpan(
                          recognizer: TapGestureRecognizer()..onTap = () {
                            if (store.user.isLoggedIn) {
                              Navigator.push(context, MaterialPageRoute<void>(
                                builder: (context) => getIt<UserProfileScreen>(),
                              ),);
                            } else {
                              Navigator.push(context, MaterialPageRoute<void>(
                                builder: (context) => getIt<SignIn>(),
                              ),);
                            }
                          },
                          text: store.user.isLoggedIn ? '${widget.services.userInfoStore.firstName ?? ''}' : S.of(context).signIn,
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
                  Observer(builder: (context) => Text(
                    S.of(context).youAreInCountry(country(context, store)) + ',  ' + S.of(context).needHelp,
                    style: GoogleFonts.rubik(
                      color: AppColors.k5e5e5e,
                      fontSize: 14,
                    ),
                    softWrap: true,
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
          const SizedBox(height: 12),
          // AI Banner
          TapDebouncer(
            onTap: () async {
              if (_checkLoginStatus()) {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ChatbotHistory(services: widget.services.activeSubscriptionStore,)),
                );
              } else {
                showAlertDialog(context);
              }
            },
            builder: (context, onTap) => InkWell(
              onTap: onTap,
              child: Stack(
                children: [
                  Image.asset(
                    'assets/banner.png',
                    width: double.infinity,
                    fit: BoxFit.fitWidth,
                  ),
                  Positioned.fill(
                    child: Padding(
                      padding: EdgeInsets.only(left: Utils.isPad(context) ? 50 : 20, top: 14, bottom: 14, right: 130),
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
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              S.of(context).bannerSubtitle,
                              style: GoogleFonts.rubik(
                                color: Colors.white.withOpacity(0.85),
                                fontSize: 11,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                S.of(context).bannerButton,
                                style: GoogleFonts.rubik(
                                  color: AppColors.k0cbcc5,
                                  fontSize: 11,
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
                ],
              ),
            ),
          ),
          // Service cards 2x2 grid
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 16, right: 16),
            child: Column(
              children: [
                IntrinsicHeight(child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Customer Care
                    Expanded(child: TapDebouncer(
                      onTap: () async {
                        if (_checkLoginStatus()){
                          var sharedPreferences = await SharedPreferences.getInstance();
                          await sharedPreferences.setString('video-call-source', 'home');
                          await navigateToCallScreen(context, widget.services.activeSubscriptionStore, VIDEO_CALL_TYPE.CONSULT_A_DOCTOR,);
                        } else {
                          showAlertDialog(context);
                        }
                      },
                      builder: (context, onTap) => InkWell(
                        onTap: onTap,
                        child: miAidCard(Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.k0cbcc5,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.favorite, color: Colors.white, size: 22),
                              ),
                              const SizedBox(height: 16),
                              Text(S.of(context).videoDoctor, style: GoogleFonts.rubik(
                                color: AppColors.k010101,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ), maxLines: 2, overflow: TextOverflow.ellipsis,),
                            ],
                          ),
                        )),
                      ),
                    )),
                    const SizedBox(width: 15),
                    // ED and Clinics Near Me
                    Expanded(child: InkWell(
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute<void>(
                          builder: (context) => getIt<MapScreen>(),
                        ),);
                      },
                      child: miAidCard(Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.k0cbcc5,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.add, color: Colors.white, size: 22),
                            ),
                            const SizedBox(height: 16),
                            Text(S.of(context).edandClinic, style: GoogleFonts.rubik(
                              color: AppColors.k010101,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ), maxLines: 2, overflow: TextOverflow.ellipsis,),
                          ],
                        ),
                      )),
                    )),
                  ],
                )),
                const SizedBox(height: 15),
                IntrinsicHeight(child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // e-Shop
                    Expanded(child: InkWell(
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute<void>(
                          builder: (context) => getIt<EShop>(),
                        ),);
                      },
                      child: miAidCard(Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.k0cbcc5,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.shopping_cart, color: Colors.white, size: 22),
                            ),
                            const SizedBox(height: 16),
                            Text(S.of(context).eShop, style: GoogleFonts.rubik(
                              color: AppColors.k010101,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ), maxLines: 2, overflow: TextOverflow.ellipsis,),
                          ],
                        ),
                      )),
                    )),
                    const SizedBox(width: 15),
                    // MiAid Service
                    Expanded(child: InkWell(
                      onTap: () {
                        if (_checkLoginStatus()) {
                          Navigator.push(context, MaterialPageRoute<void>(
                            builder: (context) => getIt<AdditionalServices>(),
                          ),);
                        } else {
                          showAlertDialog(context);
                        }
                      },
                      child: miAidCard(Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.k0cbcc5,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.medical_services, color: Colors.white, size: 22),
                            ),
                            const SizedBox(height: 16),
                            Text(S.of(context).otherService, style: GoogleFonts.rubik(
                              color: AppColors.k010101,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ), maxLines: 2, overflow: TextOverflow.ellipsis,),
                          ],
                        ),
                      )),
                    )),
                  ],
                )),
              ],
            ),
          ),
          // About section
          Padding(
            padding: const EdgeInsets.only(top: 32),
            child: InkWell(
              onTap: () {
                Navigator.push(context, MaterialPageRoute<void>(
                  builder: (context) => getIt<AboutMiAid>(),
                ),);
              },
              child: Container(
                color: AppColors.k2e2e2e,
                child: Center(child: Padding(
                  padding: const EdgeInsets.only(top: 14, bottom: 14,),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image(image: AssetImage('assets/images/ic_home_about.png'),),
                      SizedBox(width: 16.33,),
                      Flexible(child: Text(S.of(context).about, style: GoogleFonts.rubik(
                        color: AppColors.k0cbcc5,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ), maxLines: 1, overflow: TextOverflow.ellipsis,),),
                    ],
                  ),
                ),),
              ),
            ),
          ),
        ],),),
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

    if (widget.services.ongoingCallStore.hasOngoingCall) return;

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

  bool _checkLoginStatus() {
    final user = getIt<UserProvider>();
    if (!user.isLoggedIn) return false;

    return true;
  }

  void showAlertDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) => CustomDialog(
        title: S.of(context).alert,
        content: S.of(context).pleaseSignInFirst,
        buttonText: S.of(context).signIn,
        showCancel: false,
        onPressed: () {
          Navigator.push(context, MaterialPageRoute<void>(
            builder: (context) => getIt<SignIn>(),
          ),);
        },
      ),
    );
  }
}