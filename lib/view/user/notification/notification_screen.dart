import 'package:eraser/eraser.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app_badger/flutter_app_badger.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
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
  bool _isLoading = true;

  @override
  void initState() {
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
    _loadNotifications();
    _checkAndShowIncomingCalls();
  }

  Future<void> _loadNotifications() async {
    await EasyLoading.show(
      status: S.of(context).loading,
      maskType: EasyLoadingMaskType.black,
    );
    try {
      await widget.services.store.fetchNotificationList();
      await EasyLoading.dismiss();
    } catch (e) {
      await EasyLoading.dismiss();
      await EasyLoading.showError(e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _refreshNotifications() async {
    setState(() {
      _isLoading = true;
    });
    try {
      await widget.services.store.fetchNotificationList();
    } catch (e) {
      await EasyLoading.showError(e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
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
      backgroundColor: AppColors.kf4f4f4,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          S.of(context).notificationList,
          style: GoogleFonts.rubik(
            color: AppColors.k010101,
            fontSize: 15,
            fontWeight: FontWeight.bold,
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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(
            height: 1,
            thickness: 1,
            color: AppColors.kf4f4f4,
          ),
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
      return RefreshIndicator(
        color: AppColors.k30bee6,
        onRefresh: _refreshNotifications,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: _isLoading ? const [] : [
            SizedBox(height: MediaQuery.of(context).size.height * 0.3),
            Icon(
              Icons.notifications_none_rounded,
              size: 64,
              color: AppColors.kb1b1b1,
            ),
            const SizedBox(height: 12),
            Text(
              S.of(context).noNotification,
              textAlign: TextAlign.center,
              style: GoogleFonts.rubik(
                fontSize: 14,
                color: AppColors.k808080,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.k30bee6,
      onRefresh: _refreshNotifications,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 12),
        itemCount: widget.services.store.notifications.length,
        itemBuilder: (context, index) => _notificationListItem(
          widget.services.store.notifications[index],
          context,
          widget.services.store
        ),
      ),
    );
  }

  Widget _notificationListItem(MiaidNotification notification,
      BuildContext context, NotificationScreenStore store) {
    final isRead = notification.isRead ?? false;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () async {
            if (isRead) {
              return;
            }
            await store.markNotificationAsRead(notification.id ?? 0);
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isRead ? AppColors.kffffff : AppColors.keefeff,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isRead ? AppColors.kf4f4f4 : AppColors.k30bee6.withOpacity(0.3),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.k000000.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isRead)
                      Container(
                        margin: const EdgeInsets.only(top: 5, right: 8),
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: AppColors.k30bee6,
                          shape: BoxShape.circle,
                        ),
                      ),
                    Expanded(
                      child: Text(
                        notification.subject ?? '',
                        style: GoogleFonts.rubik(
                          color: AppColors.k010101,
                          fontWeight: isRead ? FontWeight.bold : FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                Divider(color: Colors.black12,),
                Text(
                  notification.content ?? '',
                  style: GoogleFonts.rubik(
                    fontSize: 14,
                    height: 1.4,
                    color: AppColors.k5e5e5e,
                    fontWeight: isRead ? FontWeight.w300 : FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      size: 14,
                      color: AppColors.k808080,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      formatDate(DateTime.parse(notification.sentAt ?? '').toLocal()),
                      style: GoogleFonts.rubik(
                        fontSize: 12,
                        color: AppColors.k808080,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
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
