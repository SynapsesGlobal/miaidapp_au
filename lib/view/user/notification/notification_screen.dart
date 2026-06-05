import 'package:eraser/eraser.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app_badger/flutter_app_badger.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:injectable/injectable.dart';
import 'package:after_layout/after_layout.dart';
import 'package:miaid/api_utils/api_parser.dart';
import 'package:miaid/api_utils/api_provider.dart';
import 'package:miaid/component/miaid_drawer.dart';
import 'package:miaid/component/nav_bar_icons.dart';
import 'package:miaid/config/app_colors.dart';
import 'package:miaid/generated/l10n.dart';
import 'package:miaid/generated_api_code/api_client.swagger.dart';
import 'package:miaid/notifications/notifications_handler.dart';
import 'package:miaid/store/user/calling/ongoing_call_store.dart';
import 'package:miaid/store/user/notification/notification_screen_store.dart';
import 'package:miaid/utils/configure_dependencies.dart';
import 'package:miaid/utils/date_utils.dart';
import 'package:miaid/with_notification_handler_widget.dart';

class NotificationListParams {
  const NotificationListParams(this.key);

  final Key key;
}

@injectable
class NotificationListServices {
  NotificationListServices(this.store, this.ongoingCallStore);

  final NotificationScreenStore store;
  final OngoingCallStore ongoingCallStore;
}

@injectable
class NotificationScreen extends StatefulWidget {
  NotificationScreen({
    @factoryParam this.params,
    required this.services,
  }) : super(key: params?.key);

  final NotificationListParams? params;
  final NotificationListServices services;

  @override
  _NotificationScreenState createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen>
    with AfterLayoutMixin<NotificationScreen>, WidgetsBindingObserver {
  @override
  void initState() {
    widget.services.store.fetchNotificationList();
    WidgetsBinding.instance?.addObserver(this);
    super.initState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance?.removeObserver(this);
    super.dispose();
  }

  @override
  void afterFirstLayout(BuildContext context) {
    _checkAndShowIncomingCalls();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkAndShowIncomingCalls();
    } else if (state == AppLifecycleState.inactive) {
      // remove the badge
      Eraser.clearAllAppNotifications();
      FlutterAppBadger.removeBadge();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          S.of(context).notificationList,
          style: GoogleFonts.rubik(
            color: AppColors.k010101,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        actions: [],
        leading: Builder(
          builder: (BuildContext context) {
            return InkWell(
              onTap: () {
                Navigator.pop(context);
              },
              child: navBarIcon(iconAssetName: 'ic_nb_back.png'),
            );
          },
        ),
      ),
      drawer: getDrawer(widget.services.store.user),
      body: Observer(
        builder: (context) => WithNotificationHandlerWidget(
          handler: getIt<NotificationHandler>(),
          child: _listNotificationList(context),
        ),
      ),
    );
  }

  Widget _listNotificationList(BuildContext context) {
    if (widget.services.store.notifications.isEmpty) {
      return Center(
        child: Text(S.of(context).noNotification),
      );
    }

    return ListView.builder(
      itemCount: widget.services.store.notifications.length,
      itemBuilder: (context, index) => _notificationListItem(
          widget.services.store.notifications[index],
          context,
          widget.services.store),
    );
  }

  Widget _notificationListItem(MiaidNotification notification,
      BuildContext context, NotificationScreenStore store) {
    return InkWell(
      onTap: () async {
        if (notification.isRead ?? false) {
          return;
        }

        await store.markNotificationAsRead(notification.id ?? 0);
      },
      child: Padding(
        padding: EdgeInsets.only(top: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding:
                  EdgeInsets.only(top: 10, bottom: 10, left: 20, right: 20),
              decoration: BoxDecoration(
                color: Color.fromRGBO(90, 177, 255, 0.1),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          notification.subject ?? '',
                          style: GoogleFonts.rubik(
                              fontSize: 12,
                              fontWeight: notification.isRead ?? false
                                  ? FontWeight.w400
                                  : FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(
                    height: 4,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        formatDate(DateTime.parse(notification.sentAt ?? '')
                            .toLocal()),
                        style: GoogleFonts.rubik(
                          fontSize: 10,
                          fontWeight: notification.isRead ?? false
                              ? FontWeight.w400
                              : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 10,
            ),
            Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        notification.content ?? '',
                        style: GoogleFonts.rubik(
                          fontSize: 12,
                          fontWeight: notification.isRead ?? false
                              ? FontWeight.w300
                              : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _checkAndShowIncomingCalls() async {
    // First check if there are any ongoing calls
    // Do this only for doctors and translators
    final user = widget.services.store.user;

    if (widget.services.ongoingCallStore.hasOngoingCall) {
      return;
    }

    if (user.isTranslator || user.isDoctor) {
      final api = getIt<ApiProvider>();
      final response = await api.apiClientMain.callsPostCallActive();
      if (ApiSuccessParser.isSuccessfulWithPayload(response)) {
        await widget.services.ongoingCallStore
            .showIncomingCallDialogOrGoToCallScreen(
                context, response.body!.payload!);
      }
    }
  }
}
