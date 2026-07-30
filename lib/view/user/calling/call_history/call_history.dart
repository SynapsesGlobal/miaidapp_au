import 'dart:async';

import 'package:after_layout/after_layout.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app_badger/flutter_app_badger.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:injectable/injectable.dart';
import 'package:miaid/api_utils/api_parser.dart';
import 'package:miaid/api_utils/api_provider.dart';
import 'package:miaid/component/miaid_drawer.dart';
import 'package:miaid/component/nav_bar_icons.dart';
import 'package:miaid/config/app_colors.dart';
import 'package:miaid/generated/l10n.dart';
import 'package:miaid/generated_api_code/api_client.swagger.dart';
import 'package:miaid/notifications/notifications_handler.dart';
import 'package:miaid/store/user/calling/call_history/call_history_store.dart';
import 'package:miaid/store/user/calling/ongoing_call_store.dart';
import 'package:miaid/utils/configure_dependencies.dart';
import 'package:miaid/utils/date_utils.dart';
import 'package:miaid/view/user/sign_in/sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tap_debouncer/tap_debouncer.dart';
import 'package:eraser/eraser.dart';

import '../../../../with_notification_handler_widget.dart';
import 'call_view_receipt.dart';

class CallHistoryParams {
  const CallHistoryParams(this.key);

  final Key key;
}

@injectable
class CallHistoryServices {
  CallHistoryServices(this.store, this.ongoingCallStore);

  final CallHistoryStore store;
  final OngoingCallStore ongoingCallStore;
}

@injectable
class CallHistory extends StatefulWidget {
  CallHistory({
    @factoryParam this.params,
    required this.services,
  }) : super(key: params?.key);

  final CallHistoryParams? params;
  final CallHistoryServices services;

  @override
  _CallHistoryState createState() => _CallHistoryState();
}

class _CallHistoryState extends State<CallHistory> with AfterLayoutMixin<CallHistory>, WidgetsBindingObserver {
  late Timer _timer;

  @override
  void initState() {
    widget.services.store.fetchCallHistory();
    WidgetsBinding.instance.addObserver(this);

    _timer = Timer.periodic(Duration(seconds: 4), (Timer timer) async {
      var sharedPreferences = await SharedPreferences.getInstance();
      if(sharedPreferences.getString('doctor-or-translator-state') != 'busy') {
        _checkAndShowIncomingCalls();
      } else {
        final api = getIt<ApiProvider>();
        final response = await api.apiClientMain.callsPostCallActive();
        if (!ApiSuccessParser.isSuccessfulWithPayload(response)) {
          var sharedPreferences = await SharedPreferences.getInstance();
          await sharedPreferences.setString('doctor-or-translator-state', 'available');
        }
      }
    });

    super.initState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer.cancel();
    super.dispose();
  }

  @override
  Future<void> afterFirstLayout(BuildContext context) async {
    var sharedPreferences = await SharedPreferences.getInstance();
    if(sharedPreferences.getString('doctor-or-translator-state') != 'busy') {
      _checkAndShowIncomingCalls();
    }
  }

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed) {
      var sharedPreferences = await SharedPreferences.getInstance();
      if(sharedPreferences.getString('doctor-or-translator-state') != 'busy') {
        _checkAndShowIncomingCalls();
      }
    } else if (state == AppLifecycleState.inactive) {
      // remove the badge
      Eraser.clearAllAppNotifications();
      FlutterAppBadger.removeBadge();
    }
  }

  void showAlertDialog(BuildContext context) {
    Widget okButton = Padding(
      padding: EdgeInsets.only(left: 64.5, right: 63.5, bottom: 24.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: MediaQuery.of(context).size.width,
            height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: AppColors.k0cbcc5.withOpacity(0.2),
                  blurRadius: 10.0,
                  spreadRadius: 0.0, //extend the shadow
                  offset: Offset(
                    0.0, // Move to right 10  horizontally
                    4, // Move to bottom 10 Vertically
                  ),
                ),
              ],
            ),
            child: TextButton(
              style: ButtonStyle(
                backgroundColor: MaterialStateProperty.all(AppColors.k0cbcc5),
                shape: MaterialStateProperty.all(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9),
                  ),
                ),
              ),
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text(
                S.of(context).no,
                style: GoogleFonts.rubik(
                  color: AppColors.kffffff,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          SizedBox(
            height: 20,
          ),
          Center(
            child: InkWell(
              onTap: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute<void>(
                    builder: (context) => getIt<SignIn>(),
                  ),
                );
              },
              child: Text(
                S.of(context).yes,
                style: GoogleFonts.rubik(
                  color: AppColors.k0cbcc5,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    var alert = AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      title: Text(
        S.of(context).logout,
        textAlign: TextAlign.center,
        style: GoogleFonts.rubik(
            color: AppColors.k010101, fontWeight: FontWeight.w700),
      ),
      content: Text(
        S.of(context).logoutAlertMessage,
        textAlign: TextAlign.center,
        style: GoogleFonts.rubik(
          fontSize: 13,
        ),
      ),
      actions: [okButton],
    );

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return alert;
      },
    );
  }

  Widget cupertinoDatePicker(BuildContext context) {
    var date = widget.services.store.date ?? DateTime.now();
    final now = DateTime.now();
    return Container(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.only(left: 20, right: 20),
            height: 50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                InkWell(
                  onTap: () {
                    Navigator.pop(context);
                  },
                  child: Text(
                    S.of(context).cancel,
                    style: GoogleFonts.rubik(
                      fontSize: 15,
                      fontWeight: FontWeight.w300,
                      color: Color.fromRGBO(12, 188, 197, 1),
                    ),
                  ),
                ),
                TapDebouncer(
                  onTap: () async {
                    await widget.services.store.setDateFilter(date);
                    Navigator.pop(context);
                  },
                  builder: (context, onTap) => InkWell(
                    onTap: onTap,
                    child: Text(
                      S.of(context).done,
                      style: GoogleFonts.rubik(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Color.fromRGBO(12, 188, 197, 1),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 200,
            child: CupertinoDatePicker(
              initialDateTime: date,
              maximumYear: now.year,
              minimumYear: 2021,
              maximumDate: DateTime(now.year, now.month, now.day, 23, 59, 59),
              use24hFormat: false,
              mode: CupertinoDatePickerMode.date,
              onDateTimeChanged: (selectedDate) {
                date = selectedDate;
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          S.of(context).callHistory,
          style: GoogleFonts.rubik(
            color: AppColors.k010101,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        actions: [
          InkWell(
            onTap: () {
              showModalBottomSheet(
                context: context,
                builder: (context) => cupertinoDatePicker(context),
              );
            },
            child: Padding(
              padding: const EdgeInsets.only(right: 10),
              child: navBarIcon(iconAssetName: 'ic_nb_callhistory_date.png'),
            ),
          ),
        ],
        leading: Builder(
          builder: (BuildContext context) {
            return InkWell(
              onTap: () {
                widget.services.store.user.isCustomer
                    ? Navigator.pop(context)
                    : Scaffold.of(context).openDrawer();
              },
              child: widget.services.store.user.isCustomer
                  ? navBarIcon(iconAssetName: 'ic_nb_back.png')
                  : navBarIcon(iconAssetName: 'ic_nb_menu.png'),
            );
          },
        ),
      ),
      drawer: getDrawer(widget.services.store.user),
      body: Observer(
        builder: (context) => WithNotificationHandlerWidget(
          handler: getIt<NotificationHandler>(),
          child: _listCalls(context),
        ),
      ),
    );
  }

  Widget _listCalls(BuildContext context) {
    if (widget.services.store.calls.isEmpty) {
      return _emptyState(context);
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: widget.services.store.calls.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (context, index) =>
          _callHistoryItem(widget.services.store.calls[index], context),
    );
  }

  // 空状态：无通话记录时的占位提示
  Widget _emptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.history, size: 56, color: AppColors.kb1b1b1),
          const SizedBox(height: 12),
          Text(
            S.of(context).noCallsAvailable,
            style: GoogleFonts.rubik(
              fontSize: 14,
              color: AppColors.k8f8e94,
            ),
          ),
        ],
      ),
    );
  }

  // 通话记录卡片：头部为日期 + 时长，下方为参与人信息与查看收据按钮
  Widget _callHistoryItem(Call call, BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: AppColors.k010101.withOpacity(0.04),
            offset: const Offset(0, 3),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: Color.fromRGBO(90, 177, 255, 0.1),
              borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  formatDate(DateTime.parse(call.createdAt ?? '').toLocal()),
                  style: GoogleFonts.rubik(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.k010101,
                  ),
                ),
                _durationBadge(call, context),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Column(
              children: [
                _infoRow(
                  S.of(context).assistant,
                  call.$Operator?.user?.fullName ?? '',
                ),
                if (_shouldShowDoctorInCall()) ...[
                  const SizedBox(height: 10),
                  _infoRow(S.of(context).doctor, doctorName(call)),
                ],
                if (_shouldShowTranslatorInCall()) ...[
                  const SizedBox(height: 10),
                  _infoRow(S.of(context).translator, translatorName(call)),
                ],
                if (_shouldShowViewReceiptButton(call)) ...[
                  const SizedBox(height: 12),
                  _viewReceiptButton(call, context),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 时长胶囊：主题色底 + 时钟图标
  Widget _durationBadge(Call call, BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.k0cbcc5.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.schedule, size: 12, color: AppColors.k0cbcc5),
          const SizedBox(width: 4),
          Text(
            callDuration(call, context),
            style: GoogleFonts.rubik(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.k0cbcc5,
            ),
          ),
        ],
      ),
    );
  }

  // 信息行：左侧灰色标签，右侧加粗取值（超长省略）
  Widget _infoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.rubik(
            fontSize: 14,
            fontWeight: FontWeight.w300,
            color: AppColors.k5e5e5e,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.rubik(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.k010101,
            ),
          ),
        ),
      ],
    );
  }

  Widget _viewReceiptButton(Call call, BuildContext context) {
    return TextButton(
      style: ButtonStyle(
        backgroundColor: MaterialStateProperty.all(AppColors.kffffff),
        shape: MaterialStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(9),
          ),
        ),
        side: MaterialStateProperty.all(
          BorderSide(color: AppColors.k0cbcc5),
        ),
        overlayColor:
            MaterialStateProperty.all(AppColors.k0cbcc5.withOpacity(0.2)),
        minimumSize: MaterialStateProperty.all(Size(double.infinity, 36)),
      ),
      onPressed: () {
        final params = CallViewReceiptParams(
          user: widget.services.store.user,
          call: call,
        );
        final receipt = getIt<CallViewReceipt>(param1: params);

        Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (context) => receipt,
          ),
        );
      },
      child: Text(
        S.of(context).viewReceipt,
        style: GoogleFonts.rubik(
          color: AppColors.k0cbcc5,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  String doctorName(Call call) {
    if (call.doctorJoinedAt != null) {
      return call.doctor?.user?.fullName ?? 'N/A';
    }
    return '';
  }

  String translatorName(Call call) {
    if (call.translatorJoinedAt != null) {
      return call.translator?.user?.fullName ?? 'N/A';
    }
    return '';
  }

  String callDuration(Call call, BuildContext context) {
    final endedAt = DateTime.parse(call.endedAt ?? '');
    final createdAt = DateTime.parse(call.createdAt ?? '');
    final minutes = endedAt.difference(createdAt).inMinutes;
    return S.of(context).durationMinutes(minutes);
  }

  bool _shouldShowDoctorInCall() {
    return !widget.services.store.user.isTranslator;
  }

  bool _shouldShowTranslatorInCall() {
    return !widget.services.store.user.isDoctor;
  }

  bool _shouldShowViewReceiptButton(Call call) {
    if (widget.services.store.user.isCustomer) {
      if (call.doctor != null && call.doctorJoinedAt != null) {
        return true;
      } else {
        return false;
      }
    } else if (widget.services.store.user.isDoctor) {
      return true;
    } else if (widget.services.store.user.isTranslator) {
      return false;
    } else {
      return false;
    }
    // return widget.services.store.user.isCustomer &&
    //     call.payment != null;
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
        await widget.services.ongoingCallStore.showIncomingCallDialogOrGoToCallScreen(context, response.body!.payload!);
      }
    }
  }
}
