import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:injectable/injectable.dart';
import 'package:miaid/api_utils/api_parser.dart';
import 'package:miaid/api_utils/api_provider.dart';
import 'package:miaid/api_utils/user_provider.dart';
import 'package:miaid/config/stripe_settings.dart';
import 'package:miaid/generated/l10n.dart';
import 'package:miaid/notifications/notifications_token_provider.dart';
import 'package:miaid/services/analytics_service.dart';
import 'package:miaid/services/facebook_service.dart';
import 'package:miaid/services/square_payment_backend_service.dart';
import 'package:miaid/services/square_payment_service.dart';
import 'package:miaid/store/app/app_settings.dart';
import 'package:miaid/utils/configure_dependencies.dart';
import 'package:miaid/view/user/calling/call_history/call_history.dart';
import 'package:miaid/view/user/home/home_screen.dart';
import 'package:miaid/view/user/password/reset_password.dart';
import 'package:miaid/view/user/sign_up/otp_screen.dart';
import 'package:miaid/view/user/sign_up/sign_up_2.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uni_links/uni_links.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:miaid/config/stream_settings.dart';
import 'package:cometchat/cometchat_sdk.dart' as cometchat;
import 'notifications/firebase_notifications_handler.dart';
import 'notifications/notifications_handler.dart';
import 'package:device_info/device_info.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:logging/logging.dart';

import 'generated_api_code/api_client.swagger.dart';
import 'package:country_code_picker/country_code_picker.dart';

bool _initialURILinkHandled = false;
StreamSubscription? _streamSubscription;
GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// 全局路由观察者：首页借助它感知“上层页面 pop 回首页”（RouteAware.didPopNext），
/// 用于购买套餐/加叫服务（Stripe 支付）后返回首页时自动刷新剩余次数。
final RouteObserver<PageRoute<dynamic>> routeObserver =
    RouteObserver<PageRoute<dynamic>>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDependencies(prod.name);
  await initFirebase();

  /// square payment: 先挂队列监听器，再 init —— 顺序保证冷启动 URI
  /// 在 getInitialAppLink() 触发 _onUri 时已经有订阅者落库
  PaymentBackend.attachQueueListener();
  await SquarePaymentService.instance.init();
  // 不阻塞启动，后台尝试对账历史未完成的支付
  unawaited(PaymentBackend.reconcilePendingPayments());

  await runAppFromEnvironment();
}

Future<void> runAppFromEnvironment() async {
  // 在所有入口（main / main_prod / main_dev / main_sandbox）共同调用的这里加载 .env，
  // 确保任何入口启动时 dotenv 都已初始化（否则访问 dotenv.env 会抛 NotInitializedError，
  // 例如地图页的 MAPBOX_ACCESS_TOKEN）。
  await dotenv.load(fileName: '.env');

  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarBrightness: Brightness.light,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  Stripe.publishableKey = getIt<StripeSettings>().publishableKey;
  Stripe.merchantIdentifier = 'Synapses Global Assist Pty Ltd';

  final streamSettings = getIt<StreamSettings>();
  var appSettings = (cometchat.AppSettingsBuilder()
        ..subscriptionType = cometchat.CometChatSubscriptionType.allUsers
        ..region = streamSettings.region
        ..autoEstablishSocketConnection = true)
      .build();

  await cometchat.CometChat.init(streamSettings.appId, appSettings, onSuccess: (String successMessage) {
    debugPrint('CometChat 初始化成功  $successMessage');
  }, onError: (cometchat.CometChatException excep) {
    debugPrint('CometChat 初始化失败: ${excep.message}');
  });

  await LogEventService.init();
  final home = await getHome();

  // update user device push token when app starts
  final userProvider = getIt<UserProvider>();
  if (userProvider.isLoggedIn) {
    final api = getIt<ApiProvider>();
    final tokenProvider = getIt<NotificationsTokenProvider>();

    try {
      final res = await api.apiClient.authPostUpdateToken(
        device_id: userProvider.deviceId.deviceId,
        device_type: tokenProvider.deviceType,
        device_push_token: tokenProvider.token,
      );

      final payload = await ApiSuccessParser.payloadOrThrowWithMessage(res);

      await userProvider.updateUserToken(payload['access_token']);
    } catch (e) {
      debugPrint('Error updating token: $e');
    }
  }

  final localeSettings = getIt<AppSettings>();

  runApp(
    // 监听 AppSettings.localeListenable：切换语言时整体重建 MaterialApp，
    // 让所有 S.of(context) 文案实时刷新，无需重启 App。
    ValueListenableBuilder<Locale>(
      valueListenable: localeSettings.localeListenable,
      builder: (context, locale, _) => MaterialApp(
      theme: ThemeData(
        appBarTheme: AppBarTheme(
          systemOverlayStyle: SystemUiOverlayStyle.light,
        ),
        scaffoldBackgroundColor: Colors.white,
      ),
      localizationsDelegates: [
        S.delegate,
        CountryLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      navigatorObservers: [
        getIt<AnalyticsService>().getAnalyticsObserver(), // Firebase Analytics
        routeObserver,
      ],
      locale: locale,
      initialRoute: '/',
      supportedLocales: S.delegate.supportedLocales,
      // home: home,
      //builder: EasyLoading.init(),
      builder: (context, child) {
        // 先经过 EasyLoading，再包 SafeArea
        final easyLoadingChild = EasyLoading.init()(context, child);
        return SafeArea(
          top: false,
          left: false,
          right: false,
          bottom: Platform.isAndroid ? true : false,
          child: easyLoadingChild,
        );
      },
      routes: {
        '/': (context) => home,
        // '/in-app/reset-password': (context) => getIt<ResetPassword>(),
      },
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      ),
    ),
  );
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitDown,
    DeviceOrientation.portraitUp,
  ],);
}

Future<Widget> getHome() async {
  try {
    final initialUri = await getInitialUri();
    if (initialUri != null && initialUri.path.startsWith('/password/reset/')) {
      _initialURILinkHandled = true;
      var token = initialUri.path.replaceAll('/password/reset/', '');
      var email = initialUri.queryParameters['email'] ?? '';
      var param = ResetPasswordParams(
        token: token,
        email: email,
      );

      return getIt<ResetPassword>(param1: param);
    }
  } on FormatException {
    // Handle exception by warning the user their action did not succeed
    // return?
  }
  final userProvider = getIt<UserProvider>();
  final user = await userProvider.getUserOnAppStart();

  return getHomeFromUser(user);
}

Widget getHomeFromUser(User? user) {
  Widget home = getIt<HomeScreen>();
  // Widget home = getIt<SignIn>();
  if (user != null) {
    if (user.emailVerifiedAt == null && user.translator == null && user.doctor == null) {
      home = getIt<OtpScreen>();
    } else if (user.customer == null && user.translator == null && user.doctor == null) {
      // Assume the user is a customer that has not completed the signup flow
      home = getIt<SignUp2>();
    } else {
      if (user.translator != null || user.doctor != null) {
        // This is a translator or doctor
        home = getIt<CallHistory>();
      } else {
        // This is a customer
        home = getIt<HomeScreen>();
      }
    }
  }
  return home;
}

void incomingLinkHandler() async {
  try {
    _streamSubscription = uriLinkStream.listen(
      (Uri? uri) {
        if (uri != null && uri.path.startsWith('/password/reset/')) {
          var token = uri.path.replaceAll('/password/reset/', '');
          var email = uri.queryParameters['email'] ?? '';
          var param = ResetPasswordParams(
            token: token,
            email: email,
          );
          // Create an instance of ResetPassword
          var resetPasswordWidget = getIt<ResetPassword>(param1: param);

          // 在这里执行你的跳转逻辑
          Navigator.pushAndRemoveUntil(
            navigatorKey.currentContext!,
            MaterialPageRoute(builder: (BuildContext context) => resetPasswordWidget),
            ModalRoute.withName('/')
          );
        }
      },
      onError: (Object err) {
        print('Error occurred: $err');
      },
    );

    // 在应用关闭时取消监听器
    WidgetsBinding.instance.addObserver(AppLifecycleObserver());
  } on PlatformException {
    print('Error initializing uni_links plugin');
  }
}

void setLoggingLevelAll() {
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((rec) {
    print('${rec.level.name}: ${rec.time}: ${rec.message}');
  });
}

Future<void> initFirebase() async {
  // If you're going to use other Firebase services in the background, such as Firestore,
  // make sure you call `initializeApp` before using other Firebase services.
  await Firebase.initializeApp();

  var messaging = FirebaseMessaging.instance;
  var analytics = FirebaseAnalytics.instance;
  FirebaseAnalyticsObserver(analytics: analytics);

  final deviceType = Platform.isIOS ? 'APPLE' : 'ANDROID';
  String? token;
  await messaging.setForegroundNotificationPresentationOptions(
    alert: true, // Required to display a heads up notification
    badge: true,
    sound: true,
  );

  var settings = await messaging.requestPermission(
    alert: true,
    announcement: false,
    badge: true,
    carPlay: false,
    criticalAlert: false,
    provisional: false,
    sound: true,
  );

  if (Platform.isIOS) {
    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      var apnsToken = await FirebaseMessaging.instance.getAPNSToken();
      //developer.log("apnsToken $apnsToken");
      if (apnsToken != null && apnsToken.isNotEmpty) {
        try {
          token = await FirebaseMessaging.instance.getToken();
        } catch (e) {
          token = '';
        }
      } else {
        token = '';
      }
    } else {
      token = '';
    }
  } else {
    try {
      token = await FirebaseMessaging.instance.getToken();
    } catch (e) {
      token = '';
    }
  }

  //developer.log('Firebase Token: $token');
  if (token == null || token.isEmpty) {
    token = '';
  }
  getIt.registerSingleton<NotificationsTokenProvider>(NotificationsTokenProvider(
    token: token,
    deviceType: deviceType,
  ));

  getIt.registerSingleton<NotificationHandler>(FirebaseNotificationHandler());

  getIt.registerSingleton<AnalyticsService>(AnalyticsService());

  // Heads up notifications
  // https://firebase.flutter.dev/docs/messaging/notifications/#foreground-notifications
  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true, // Required to display a heads up notification
    badge: true,
    sound: true,
  );
}

void setupFlutterLocalNotifications() async {
  final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  if (Platform.isAndroid) {
    final androidLocalNotifications = flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    // TODO translations
    final channel = AndroidNotificationChannel(
      'high_importance_channel', // id
      'Incoming Call from MiAid', // name
      description: 'Tap to answer.', // description
      importance: Importance.max,
    );

    var androidInfo = await DeviceInfoPlugin().androidInfo;

    if (androidInfo.version.sdkInt > 25) {
      // TODO This does not work on Android 7.1 or below
      // because we can't set the channel priority
      // This can probably be improved in the flutter plugin with an issue and a PR
      // in https://github.com/MaikuB/flutter_local_notifications/issues
      await androidLocalNotifications?.createNotificationChannel(channel);
    } else {
      final sharedPreferences = getIt<SharedPreferences>();
      if (sharedPreferences.get('CREATED_PUSH_NOTIFICATIONS_CHANNEL') == null) {
        // Show local notification to create the channel
        await flutterLocalNotificationsPlugin.show(
          0,
          'Welcome to MiAid!',
          '',
          NotificationDetails(
            android: AndroidNotificationDetails(
              channel.id,
              channel.name,
              channelDescription: channel.description,
              importance: Importance.max,
              priority: Priority.high,
              icon: 'ic_notifications',
            ),
          ),
        );
        await sharedPreferences.setBool('CREATED_PUSH_NOTIFICATIONS_CHANNEL', true);
      }
    }
  }
}

class AppLifecycleObserver extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // 回到前台时兜底重试 —— 覆盖热启动后 confirmPayment 临时失败 / 后端
      // 刚恢复的场景。reconcilePendingPayments 自身有去重锁。
      unawaited(PaymentBackend.reconcilePendingPayments());
    }
  }
}
