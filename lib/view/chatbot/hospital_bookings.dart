import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../component/nav_bar_icons.dart';
import '../../config/app_colors.dart';
import '../../generated/l10n.dart';
import 'hospital_booking_api.dart';
import 'hospital_booking_dtl.dart';
import 'models/hospital_booking.dart';
import 'ui/hospital_booking_widgets.dart';

/// chatbot 帮用户发起过的医院预约：按发送预约请求的时间列出，点进去看发给了哪些医院
class HospitalBookings extends StatefulWidget {
  const HospitalBookings({super.key});

  @override
  State<HospitalBookings> createState() => _HospitalBookingsState();
}

class _HospitalBookingsState extends State<HospitalBookings> {
  final _api = HospitalBookingApi();
  List<HospitalBooking> _bookings = [];
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool showSpinner = true}) async {
    setState(() {
      _loading = showSpinner;
      _failed = false;
    });
    try {
      final bookings = await _api.fetchBookings();
      if (!mounted) return;
      setState(() {
        _bookings = bookings;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Hospital bookings load error: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  Future<void> _open(HospitalBooking booking) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (context) => HospitalBookingDtl(booking: booking)),
    );
    // 详情页里可能刷新到了新的确认状态，回来后同步列表上的计数
    await _load(showSpinner: false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bookingPageBackground,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        elevation: 0,
        backgroundColor: AppColors.kffffff,
        centerTitle: true,
        title: Text(
          S.of(context).hospitalBookings,
          style: bookingText(size: 15, weight: FontWeight.w500),
        ),
        leading: InkWell(
          onTap: () => Navigator.pop(context),
          child: navBarIcon(iconAssetName: 'ic_nb_back.png'),
        ),
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return Center(child: CircularProgressIndicator(color: AppColors.k0cbcc5));
    }
    if (_failed && _bookings.isEmpty) {
      return BookingPlaceholder(
        icon: Icons.cloud_off_outlined,
        text: S.of(context).somethingWentWrong,
        onRetry: _load,
      );
    }

    return RefreshIndicator(
      color: AppColors.k0cbcc5,
      onRefresh: () => _load(showSpinner: false),
      child: HospitalBookingsList(bookings: _bookings, onTap: _open),
    );
  }
}

/// 预约请求列表的展示部分：按月份分组，每月一张卡片，一行一次预约请求
class HospitalBookingsList extends StatelessWidget {
  final List<HospitalBooking> bookings;
  final ValueChanged<HospitalBooking> onTap;

  const HospitalBookingsList({super.key, required this.bookings, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (bookings.isEmpty) {
      // 空列表也要能下拉刷新
      return LayoutBuilder(
        builder: (context, constraints) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: constraints.maxHeight,
              child: BookingPlaceholder(
                icon: Icons.event_available_outlined,
                text: S.of(context).noHospitalBookings,
              ),
            ),
          ],
        ),
      );
    }

    final months = _groupByMonth(bookings);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
      children: [
        for (final month in months.entries) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 20, 4, 10),
            child: Text(
              month.key,
              style: bookingText(size: 13, weight: FontWeight.w500, color: AppColors.k8f8e94),
            ),
          ),
          BookingCard(
            margin: EdgeInsets.zero,
            padding: EdgeInsets.zero,
            child: Column(children: [
              for (var i = 0; i < month.value.length; i++) ...[
                if (i > 0)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Divider(height: 1, thickness: 1, color: bookingDivider),
                  ),
                _BookingRow(booking: month.value[i], onTap: () => onTap(month.value[i])),
              ],
            ]),
          ),
        ],
      ],
    );
  }

  /// 按 "yyyy-MM" 分组，保持服务端给的顺序（新的在前）
  Map<String, List<HospitalBooking>> _groupByMonth(List<HospitalBooking> bookings) {
    final months = <String, List<HospitalBooking>>{};
    for (final booking in bookings) {
      final requestedAt = booking.requestedAt;
      final month = requestedAt == null ? '-' : DateFormat('yyyy-MM').format(requestedAt);
      months.putIfAbsent(month, () => []).add(booking);
    }
    return months;
  }
}

class _BookingRow extends StatelessWidget {
  final HospitalBooking booking;
  final VoidCallback onTap;

  const _BookingRow({required this.booking, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final requestedAt = booking.requestedAt;
    final hasConfirmed = booking.confirmedCount > 0;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                requestedAt == null ? '-' : DateFormat('MM-dd  HH:mm').format(requestedAt),
                style: bookingText(size: 16, weight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                s.bookingSentTo(booking.hospitalsCount),
                style: bookingText(size: 13, color: AppColors.k8f8e94),
              ),
            ]),
          ),
          const SizedBox(width: 8),
          BookingStatusBadge(
            text: hasConfirmed
                ? s.bookingConfirmedCount(booking.confirmedCount, booking.hospitalsCount)
                : s.bookingUnconfirmed,
            color: hasConfirmed ? AppColors.k0cbcc5 : bookingPending,
          ),
          Icon(Icons.chevron_right, color: AppColors.kb1b1b1),
        ]),
      ),
    );
  }
}
