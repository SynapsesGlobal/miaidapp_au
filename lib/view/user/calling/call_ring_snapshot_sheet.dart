import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:miaid/config/app_colors.dart';
import 'package:miaid/generated/l10n.dart';
import 'package:miaid/services/call_ring_share_service.dart';
import 'package:miaid/view/user/calling/call_ring_tiles.dart';
import 'package:miaid/view/user/smart_ring/smart_ring_format.dart';

/// 医生端：查看患者在本次通话中分享的戒指数据。面板打开期间监听 [receiver]，有新快照自动刷新。
///
/// 通话中屏幕被视频占着，弹层尽量紧凑：指标两列小格，参考范围不默认展开，点某一格才在下方显示一行。
Future<void> showCallRingSnapshotSheet(
  BuildContext context,
  CallRingShareReceiver receiver, {
  String? patientName,
}) {
  receiver.markRead();
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => _CallRingSnapshotSheet(receiver: receiver, patientName: patientName),
  );
}

class _CallRingSnapshotSheet extends StatefulWidget {
  const _CallRingSnapshotSheet({required this.receiver, this.patientName});

  final CallRingShareReceiver receiver;
  final String? patientName;

  @override
  State<_CallRingSnapshotSheet> createState() => _CallRingSnapshotSheetState();
}

class _CallRingSnapshotSheetState extends State<_CallRingSnapshotSheet> {
  bool _refreshing = false;

  /// 当前点选、在下方显示参考范围的指标。
  RingShareTile? _selected;

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      await widget.receiver.refresh();
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
    widget.receiver.markRead();
  }

  void _toggle(RingShareTile t) => setState(() => _selected = _selected?.key == t.key ? null : t);

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return ListenableBuilder(
      listenable: widget.receiver,
      builder: (context, _) {
        final record = widget.receiver.latest;
        // 面板开着时来了新数据，顺手标成已读
        if (widget.receiver.hasUnread) {
          WidgetsBinding.instance.addPostFrameCallback((_) => widget.receiver.markRead());
        }
        return Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(16, 10, 16, 10 + MediaQuery.of(context).padding.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ringSheetHandle(),
              const SizedBox(height: 12),
              _header(context, record),
              const SizedBox(height: 10),
              if (record == null)
                _empty(context)
              else
                Flexible(child: _content(context, record)),
              const SizedBox(height: 8),
              Text(s.smartRingDisclaimer, textAlign: TextAlign.center,
                  style: GoogleFonts.rubik(color: AppColors.kb1b1b1, fontSize: 10.5)),
            ],
          ),
        );
      },
    );
  }

  Widget _header(BuildContext context, CallRingSnapshotRecord? record) {
    final s = S.of(context);
    final sharedAt = record?.createdAt ?? record?.capturedAt;
    final subtitle = <String>[
      if (widget.patientName != null && widget.patientName!.isNotEmpty) widget.patientName!,
      if (record != null) record.displayName,
      if (record?.battery != null) '${record!.battery}%',
      if (sharedAt != null) s.smartRingSharedAt(SmartRingFormat.dateTime(context, sharedAt)),
    ].join(' · ');
    return ringSheetHeader(
      icon: Icons.monitor_heart_outlined,
      title: s.smartRingPatientData,
      subtitle: subtitle,
      trailing: SizedBox(
        width: 32,
        height: 32,
        child: _refreshing
            ? Padding(
                padding: const EdgeInsets.all(8),
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.k0cbcc5),
              )
            : IconButton(
                padding: EdgeInsets.zero,
                icon: Icon(Icons.refresh, color: AppColors.k0cbcc5, size: 20),
                onPressed: () => unawaited(_refresh()),
              ),
      ),
    );
  }

  Widget _empty(BuildContext context) {
    final s = S.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: AppColors.kf4f4f4, shape: BoxShape.circle),
          child: Icon(Icons.donut_large, color: AppColors.kb1b1b1, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(s.smartRingNoSharedData,
            style: GoogleFonts.rubik(color: AppColors.k8f8e94, fontSize: 12.5, height: 1.4))),
      ]),
    );
  }

  Widget _content(BuildContext context, CallRingSnapshotRecord record) {
    final s = S.of(context);
    final vitals = ringRecordVitalTiles(context, record);
    final activity = ringRecordActivityTiles(context, record);
    final all = [...vitals, ...activity];
    // 记录刷新后，之前点选的指标按 key 重新对上
    final selected = _selected == null ? null : all.firstWhere((t) => t.key == _selected!.key, orElse: () => _selected!);

    return ListView(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      children: [
        if (vitals.isNotEmpty) ...[
          ringSectionTitle(s.smartRingVitals),
          const SizedBox(height: 6),
          ringTileGrid(vitals, selectedKey: selected?.key, onTap: _toggle),
        ],
        if (activity.isNotEmpty) ...[
          SizedBox(height: vitals.isEmpty ? 0 : 10),
          ringSectionTitle(s.smartRingSleepActivity),
          const SizedBox(height: 6),
          ringTileGrid(activity, selectedKey: selected?.key, onTap: _toggle),
        ],
        if (all.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(s.smartRingNoData, textAlign: TextAlign.center,
                style: GoogleFonts.rubik(color: AppColors.k8f8e94, fontSize: 12.5)),
          ),
        if (selected != null) ...[
          const SizedBox(height: 8),
          ringRangeBar(context, selected),
        ],
      ],
    );
  }
}
