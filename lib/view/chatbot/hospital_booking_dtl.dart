import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../component/nav_bar_icons.dart';
import '../../config/app_colors.dart';
import '../../generated/l10n.dart';
import 'hospital_booking_api.dart';
import 'models/hospital_booking.dart';
import 'ui/chat_card_widgets.dart';
import 'ui/hospital_booking_widgets.dart';

/// 一次预约请求的详情：发送过请求的医院列表。
/// 医院补充了就诊信息的标为已确认并展示就诊信息，其余标为未确认
class HospitalBookingDtl extends StatefulWidget {
  /// 列表页带过来的概要（时间、计数），详情加载完成前先用它占位
  final HospitalBooking booking;

  const HospitalBookingDtl({super.key, required this.booking});

  @override
  State<HospitalBookingDtl> createState() => _HospitalBookingDtlState();
}

class _HospitalBookingDtlState extends State<HospitalBookingDtl> {
  final _api = HospitalBookingApi();
  late HospitalBooking _booking = widget.booking;
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
      final booking = await _api.fetchBooking(widget.booking.id);
      if (!mounted) return;
      setState(() {
        _booking = booking;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Hospital booking detail load error: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
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
    if (_failed && _booking.hospitals.isEmpty) {
      return BookingPlaceholder(
        icon: Icons.cloud_off_outlined,
        text: S.of(context).somethingWentWrong,
        onRetry: _load,
      );
    }

    return RefreshIndicator(
      color: AppColors.k0cbcc5,
      onRefresh: () => _load(showSpinner: false),
      child: HospitalBookingDetailView(booking: _booking),
    );
  }
}

/// 预约详情的展示部分：请求概览、症状、各医院的确认情况。
/// 已确认的医院各占一张卡片展示就诊信息；未确认的只有名字可看，合并在一张卡片里
class HospitalBookingDetailView extends StatelessWidget {
  final HospitalBooking booking;

  const HospitalBookingDetailView({super.key, required this.booking});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final confirmed = booking.hospitals.where((hospital) => hospital.isConfirmed && hospital.visit != null).toList();
    final pending = booking.hospitals.where((hospital) => !confirmed.contains(hospital)).toList();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        _RequestHeader(booking: booking, confirmed: confirmed.length),
        if (booking.symptoms.isNotEmpty) ...[
          _SectionLabel(text: s.bookingSymptoms),
          BookingCard(
            margin: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < booking.symptoms.length; i++)
                  Padding(
                    padding: EdgeInsets.only(top: i == 0 ? 0 : 8),
                    child: _Bullet(text: booking.symptoms[i]),
                  ),
              ],
            ),
          ),
        ],
        if (confirmed.isNotEmpty) ...[
          _SectionLabel(text: s.bookingConfirmed, count: confirmed.length),
          for (var i = 0; i < confirmed.length; i++)
            _ConfirmedHospitalCard(hospital: confirmed[i], first: i == 0),
        ],
        if (pending.isNotEmpty) ...[
          _SectionLabel(text: s.bookingUnconfirmed, count: pending.length),
          _PendingHospitalsCard(hospitals: pending),
        ],
      ],
    );
  }
}

class _RequestHeader extends StatelessWidget {
  final HospitalBooking booking;
  final int confirmed;

  const _RequestHeader({required this.booking, required this.confirmed});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final requestedAt = booking.requestedAt;
    final total = booking.hospitals.isNotEmpty ? booking.hospitals.length : booking.hospitalsCount;
    final confirmed = booking.hospitals.isNotEmpty ? this.confirmed : booking.confirmedCount;

    return BookingGradientHeader(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          s.bookingRequestedAt,
          style: bookingText(size: 12, color: Colors.white.withOpacity(0.85)),
        ),
        const SizedBox(height: 2),
        Text(
          requestedAt == null ? '-' : DateFormat('yyyy-MM-dd  HH:mm').format(requestedAt),
          style: bookingText(size: 20, weight: FontWeight.w600, color: Colors.white),
        ),
        const SizedBox(height: 14),
        BookingProgressBar(confirmed: confirmed, total: total, onGradient: true),
        const SizedBox(height: 8),
        Text(
          '${s.bookingSentTo(total)} · ${s.bookingConfirmedCount(confirmed, total)}',
          style: bookingText(size: 12.5, color: Colors.white.withOpacity(0.92)),
        ),
      ]),
    );
  }
}

/// 分组小标题，可带数量
class _SectionLabel extends StatelessWidget {
  final String text;
  final int? count;

  const _SectionLabel({required this.text, this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 24, 4, 10),
      child: Text(
        count == null ? text : '$text · $count',
        style: bookingText(size: 13, weight: FontWeight.w500, color: AppColors.k8f8e94),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  final String text;

  const _Bullet({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(top: 7),
        child: Container(
          width: 5,
          height: 5,
          decoration: BoxDecoration(color: AppColors.k0cbcc5, shape: BoxShape.circle),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(child: Text(text, style: bookingText(size: 14, height: 1.4))),
    ]);
  }
}

/// 已确认的医院：名字 + 对齐的两列就诊信息
class _ConfirmedHospitalCard extends StatelessWidget {
  final BookedHospital hospital;
  final bool first;

  const _ConfirmedHospitalCard({required this.hospital, required this.first});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final visit = hospital.visit!;
    final visitTime = visit.visitTime;
    final acceptsInsurance = visit.acceptsInsurance;

    final rows = <TableRow>[
      if (visitTime != null)
        _row(
          s.visitTime,
          Text(
            DateFormat('yyyy-MM-dd  HH:mm').format(visitTime),
            style: bookingText(size: 15, weight: FontWeight.w600, color: bookingTealDark),
          ),
        ),
      if (visit.doctorName.isNotEmpty) _row(s.visitDoctor, _value(visit.doctorName)),
      if (visit.address.isNotEmpty) _row(s.visitAddress, _value(visit.address)),
      if (visit.phone.isNotEmpty)
        _row(
          s.visitPhone,
          InkWell(
            onTap: () => dialPhone(context, visit.phone),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Flexible(
                child: Text(
                  visit.phone,
                  style: bookingText(size: 14, weight: FontWeight.w500, color: AppColors.k0cbcc5, height: 1.4),
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.phone_outlined, size: 15, color: AppColors.k0cbcc5),
            ]),
          ),
        ),
      if (acceptsInsurance != null)
        _row(s.visitInsurance, _value(acceptsInsurance ? s.insuranceAccepted : s.insuranceNotAccepted)),
    ];

    return BookingCard(
      margin: EdgeInsets.only(top: first ? 0 : 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(Icons.check_circle, size: 19, color: AppColors.k0cbcc5),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(hospital.name, style: bookingText(size: 16, weight: FontWeight.w600, height: 1.3)),
          ),
        ]),
        if (rows.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Divider(height: 1, thickness: 1, color: bookingDivider),
          ),
          Table(
            columnWidths: const {0: IntrinsicColumnWidth(), 1: FlexColumnWidth()},
            defaultVerticalAlignment: TableCellVerticalAlignment.top,
            children: rows,
          ),
        ],
      ]),
    );
  }

  TableRow _row(String label, Widget value) {
    return TableRow(children: [
      Padding(
        padding: const EdgeInsets.only(top: 9, right: 18),
        child: Text(label, style: bookingText(size: 13, color: AppColors.k8f8e94, height: 1.4)),
      ),
      Padding(padding: const EdgeInsets.only(top: 9), child: value),
    ]);
  }

  Widget _value(String text) => Text(text, style: bookingText(size: 14, height: 1.4));
}

/// 未确认的医院没有更多信息可看，合并成一张卡片，一行一家
class _PendingHospitalsCard extends StatelessWidget {
  final List<BookedHospital> hospitals;

  const _PendingHospitalsCard({required this.hospitals});

  @override
  Widget build(BuildContext context) {
    return BookingCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final hospital in hospitals) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(children: [
              Icon(Icons.schedule, size: 18, color: bookingPending),
              const SizedBox(width: 9),
              Expanded(child: Text(hospital.name, style: bookingText(size: 15, height: 1.3))),
            ]),
          ),
          Divider(height: 1, thickness: 1, color: bookingDivider),
        ],
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(
            S.of(context).bookingAwaitingConfirmation,
            style: bookingText(size: 12.5, color: AppColors.k8f8e94, height: 1.4),
          ),
        ),
      ]),
    );
  }
}
