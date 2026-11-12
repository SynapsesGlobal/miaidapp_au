import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:miaid/api_utils/http_exception.dart';
import 'package:miaid/config/app_colors.dart';
import 'package:miaid/generated/l10n.dart';
import 'package:miaid/services/ring_family_service.dart';
import 'package:miaid/view/user/calling/call_ring_tiles.dart';
import 'package:miaid/view/user/smart_ring/family/ring_family_widgets.dart';

/// 生成并展示家人邀请码：打开即向后端要一个新码，带有效期倒计时，过期后可重新生成。
Future<void> showRingFamilyInviteSheet(BuildContext context, RingFamilyService service) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => _RingFamilyInviteSheet(service: service),
  );
}

class _RingFamilyInviteSheet extends StatefulWidget {
  const _RingFamilyInviteSheet({required this.service});

  final RingFamilyService service;

  @override
  State<_RingFamilyInviteSheet> createState() => _RingFamilyInviteSheetState();
}

class _RingFamilyInviteSheetState extends State<_RingFamilyInviteSheet> {
  RingFamilyInvite? _invite;
  bool _loading = true;
  String? _error;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    unawaited(_generate());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _generate() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final invite = await widget.service.createInvite();
      if (!mounted) return;
      _ticker?.cancel();
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
      setState(() => _invite = invite);
    } on RingFamilyException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message.isNotEmpty ? e.message : S.of(context).ringFamilyActionFailed);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Duration get _remaining {
    final left = _invite?.expiresAt.difference(DateTime.now()) ?? Duration.zero;
    return left.isNegative ? Duration.zero : left;
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final invite = _invite;
    final remaining = _remaining;
    final expired = invite != null && remaining == Duration.zero;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 10, 20, 16 + MediaQuery.of(context).padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ringSheetHandle(),
          const SizedBox(height: 16),
          Text(s.ringFamilyInviteCode, textAlign: TextAlign.center,
              style: GoogleFonts.rubik(color: AppColors.k010101, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 18),
          SizedBox(
            height: 64,
            child: Center(child: _loading
                ? CircularProgressIndicator(color: AppColors.k0cbcc5)
                : invite == null
                    ? Text(_error ?? '', textAlign: TextAlign.center,
                        style: GoogleFonts.rubik(color: AppColors.ke63030, fontSize: 13))
                    : _code(invite.code, expired)),
          ),
          const SizedBox(height: 10),
          if (invite != null && !_loading)
            Text(
              expired ? s.ringFamilyInviteExpired : s.ringFamilyInviteExpiresIn(_clock(remaining)),
              textAlign: TextAlign.center,
              style: GoogleFonts.rubik(color: expired ? AppColors.ke63030 : AppColors.k8f8e94, fontSize: 12.5),
            ),
          const SizedBox(height: 12),
          Text(s.ringFamilyInviteHint, textAlign: TextAlign.center,
              style: GoogleFonts.rubik(color: AppColors.k8f8e94, fontSize: 12.5, height: 1.45)),
          const SizedBox(height: 20),
          if (invite != null && !expired)
            familyFilledButton(s.ringFamilyCopy, icon: Icons.copy, onPressed: _loading ? null : () {
              unawaited(Clipboard.setData(ClipboardData(text: invite.code)));
              unawaited(HttpExceptionNotifyUser.showInfo(s.ringFamilyCopied));
            })
          else
            familyFilledButton(s.ringFamilyRegenerate, icon: Icons.refresh,
                onPressed: _loading ? null : () => unawaited(_generate())),
        ],
      ),
    );
  }

  Widget _code(String code, bool expired) {
    final half = code.length ~/ 2;
    return Text(
      '${code.substring(0, half)} ${code.substring(half)}',
      style: GoogleFonts.rubik(
        color: expired ? AppColors.kb1b1b1 : AppColors.k003f51,
        fontSize: 40,
        fontWeight: FontWeight.w700,
        letterSpacing: 6,
        decoration: expired ? TextDecoration.lineThrough : null,
      ),
    );
  }

  static String _clock(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
}
