import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:miaid/api_utils/api_provider.dart';
import 'package:miaid/api_utils/http_exception.dart';
import 'package:miaid/config/app_colors.dart';
import 'package:miaid/generated/l10n.dart';
import 'package:miaid/services/ring_family_service.dart';
import 'package:miaid/services/smart_ring_service.dart';
import 'package:miaid/utils/configure_dependencies.dart';
import 'package:miaid/view/user/smart_ring/family/ring_family_dashboard_screen.dart';
import 'package:miaid/view/user/smart_ring/family/ring_family_invite_sheet.dart';
import 'package:miaid/view/user/smart_ring/family/ring_family_join_screen.dart';
import 'package:miaid/view/user/smart_ring/family/ring_family_widgets.dart';
import 'package:miaid/view/user/smart_ring/smart_ring_format.dart';

/// 家人共享：上半部分是「我关注的家人」（点进去看对方最新的戒指面板），
/// 下半部分是「可查看我数据的家人」（生成邀请码、解除绑定）。
class RingFamilyScreen extends StatefulWidget {
  const RingFamilyScreen({Key? key}) : super(key: key);

  @override
  State<RingFamilyScreen> createState() => _RingFamilyScreenState();
}

class _RingFamilyScreenState extends State<RingFamilyScreen> {
  late final RingFamilyService _service = RingFamilyService(getIt<ApiProvider>());

  RingFamilySummary? _summary;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final summary = await _service.fetch();
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _failed = false;
      });
    } on RingFamilyException {
      if (!mounted) return;
      setState(() => _failed = _summary == null);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openJoin() async {
    await Navigator.push(context, MaterialPageRoute<void>(
      builder: (context) => RingFamilyJoinScreen(service: _service),
    ));
    await _load();
  }

  Future<void> _openInvite() async {
    await showRingFamilyInviteSheet(context, _service);
    // 弹层开着的时候家人可能已经输入邀请码绑定了
    await _load();
  }

  Future<void> _openDashboard(RingFamilyOwner owner) async {
    await Navigator.push(context, MaterialPageRoute<void>(
      builder: (context) => RingFamilyDashboardScreen(service: _service, owner: owner),
    ));
    await _load();
  }

  /// 不再关注某位家人（解除后看不到对方的戒指数据）。
  Future<void> _removeOwner(RingFamilyOwner owner) async {
    final s = S.of(context);
    final ok = await confirmRingFamilyRemove(
      context,
      name: owner.displayName,
      message: s.ringFamilyRemoveOwnerConfirm(owner.displayName),
    );
    if (!ok) return;
    try {
      final summary = await _service.remove(owner.linkId);
      if (mounted) setState(() => _summary = summary);
    } on RingFamilyException catch (e) {
      unawaited(HttpExceptionNotifyUser.showError(e.message.isNotEmpty ? e.message : s.ringFamilyActionFailed));
    }
  }

  Future<void> _removeViewer(RingFamilyViewer viewer) async {
    final s = S.of(context);
    final ok = await confirmRingFamilyRemove(
      context,
      name: viewer.name,
      message: s.ringFamilyRemoveViewerConfirm(viewer.name),
    );
    if (!ok) return;
    try {
      final summary = await _service.remove(viewer.linkId);
      if (mounted) setState(() => _summary = summary);
    } on RingFamilyException catch (e) {
      unawaited(HttpExceptionNotifyUser.showError(e.message.isNotEmpty ? e.message : s.ringFamilyActionFailed));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      backgroundColor: AppColors.kf4f4f4,
      appBar: familyAlertAppBar(context, s.ringFamily),
      body: _body(context),
    );
  }

  Widget _body(BuildContext context) {
    final s = S.of(context);
    final summary = _summary;
    if (summary == null) {
      if (_loading) return Center(child: CircularProgressIndicator(color: AppColors.k0cbcc5));
      return Center(child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.cloud_off, color: AppColors.kb1b1b1, size: 40),
          const SizedBox(height: 12),
          Text(_failed ? s.ringFamilyLoadFailed : '', textAlign: TextAlign.center,
              style: GoogleFonts.rubik(color: AppColors.k8f8e94, fontSize: 13)),
          const SizedBox(height: 16),
          SizedBox(width: 160, child: familyOutlinedButton(s.retry, onPressed: () {
            setState(() => _loading = true);
            unawaited(_load());
          })),
        ]),
      ));
    }

    return RefreshIndicator(
      color: AppColors.k0cbcc5,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          familySectionTitle(s.ringFamilyWatching),
          if (summary.owners.isEmpty)
            _emptyCard(Icons.visibility_outlined, s.ringFamilyWatchingEmpty)
          else
            familyCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(children: [
                for (var i = 0; i < summary.owners.length; i++) ...[
                  if (i > 0) Divider(height: 1, indent: 66, endIndent: 14, color: AppColors.kf4f4f4),
                  _ownerRow(context, summary.owners[i]),
                ],
              ]),
            ),
          const SizedBox(height: 12),
          familyOutlinedButton(s.ringFamilyEnterCode, icon: Icons.pin_outlined, onPressed: () => unawaited(_openJoin())),
          const SizedBox(height: 26),
          familySectionTitle(s.ringFamilyViewers),
          if (summary.viewers.isEmpty)
            _emptyCard(Icons.group_outlined, s.ringFamilyViewersEmpty)
          else
            familyCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(children: [
                for (var i = 0; i < summary.viewers.length; i++) ...[
                  if (i > 0) Divider(height: 1, indent: 66, endIndent: 14, color: AppColors.kf4f4f4),
                  _viewerRow(context, summary.viewers[i]),
                ],
              ]),
            ),
          const SizedBox(height: 12),
          familyFilledButton(s.ringFamilyInvite, icon: Icons.person_add_alt_1, onPressed: () => unawaited(_openInvite())),
          if (SmartRingService.instance.isBound) ...[
            const SizedBox(height: 14),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(Icons.cloud_upload_outlined, color: AppColors.kb1b1b1, size: 14),
              ),
              const SizedBox(width: 6),
              Expanded(child: Text(s.ringFamilyUploadNotice,
                  style: GoogleFonts.rubik(color: AppColors.k8f8e94, fontSize: 11.5, height: 1.4))),
            ]),
          ],
        ],
      ),
    );
  }

  Widget _emptyCard(IconData icon, String text) {
    return familyCard(
      child: Row(children: [
        familyIconTile(icon, AppColors.k8f8e94),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: GoogleFonts.rubik(color: AppColors.k8f8e94, fontSize: 12.5, height: 1.4))),
      ]),
    );
  }

  Widget _ownerRow(BuildContext context, RingFamilyOwner owner) {
    final s = S.of(context);
    final updated = owner.snapshotAt;
    final subtitle = updated == null
        ? s.ringFamilyNoDataYet
        : s.ringFamilyUpdatedAt(SmartRingFormat.dateTime(context, updated));
    return InkWell(
      onTap: () => unawaited(_openDashboard(owner)),
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 6, 4, 6),
        child: Row(children: [
          familyAvatar(owner.displayName, AppColors.k0cbcc5),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(owner.displayName, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.rubik(color: AppColors.k010101, fontSize: 14.5, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.rubik(color: AppColors.k8f8e94, fontSize: 12)),
            ],
          )),
          if (owner.battery != null) ...[
            const SizedBox(width: 8),
            familyChip('${owner.battery}%', AppColors.k0cbcc5),
          ],
          TextButton(
            onPressed: () => unawaited(_removeOwner(owner)),
            child: Text(s.ringFamilyRemove, style: GoogleFonts.rubik(color: AppColors.ke63030, fontSize: 12.5)),
          ),
        ]),
      ),
    );
  }

  Widget _viewerRow(BuildContext context, RingFamilyViewer viewer) {
    final s = S.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 4, 6),
      child: Row(children: [
        familyAvatar(viewer.name, AppColors.k0CC58F),
        const SizedBox(width: 12),
        Expanded(child: Text(viewer.name, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: GoogleFonts.rubik(color: AppColors.k010101, fontSize: 14.5, fontWeight: FontWeight.w600))),
        TextButton(
          onPressed: () => unawaited(_removeViewer(viewer)),
          child: Text(s.ringFamilyRemove, style: GoogleFonts.rubik(color: AppColors.ke63030, fontSize: 12.5)),
        ),
      ]),
    );
  }
}

/// 解除绑定前的确认弹层，样式与戒指页「解绑戒指」一致：红色图标、标题、对象名胶囊、说明、红色确认 + 灰色取消。
/// [name] 是要解除的那位家人；确认返回 true。
Future<bool> confirmRingFamilyRemove(BuildContext context, {required String name, required String message}) async {
  final s = S.of(context);
  final ok = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) => Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + MediaQuery.of(context).padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.kb1b1b1.withOpacity(0.5),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 22),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: AppColors.ke63030.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(Icons.link_off, color: AppColors.ke63030, size: 30),
          ),
          const SizedBox(height: 16),
          Text(s.ringFamilyRemove, textAlign: TextAlign.center, style: GoogleFonts.rubik(
            color: AppColors.k010101,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          )),
          if (name.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.kf4f4f4,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.person, color: AppColors.k0cbcc5, size: 14),
                const SizedBox(width: 6),
                Flexible(child: Text(name, style: GoogleFonts.rubik(
                  color: AppColors.k5e5e5e,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                ), maxLines: 1, overflow: TextOverflow.ellipsis)),
              ]),
            ),
          ],
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center, style: GoogleFonts.rubik(
            color: AppColors.k8f8e94,
            fontSize: 13,
            height: 1.45,
          )),
          const SizedBox(height: 24),
          MaterialButton(
            onPressed: () => Navigator.pop(context, true),
            elevation: 0,
            height: 46,
            minWidth: double.infinity,
            color: AppColors.ke63030,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(23)),
            child: Text(s.ringFamilyRemove, style: GoogleFonts.rubik(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            )),
          ),
          const SizedBox(height: 10),
          MaterialButton(
            onPressed: () => Navigator.pop(context, false),
            elevation: 0,
            height: 46,
            minWidth: double.infinity,
            color: AppColors.kf4f4f4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(23)),
            child: Text(s.cancel, style: GoogleFonts.rubik(
              color: AppColors.k5e5e5e,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            )),
          ),
        ],
      ),
    ),
  );
  return ok == true;
}
