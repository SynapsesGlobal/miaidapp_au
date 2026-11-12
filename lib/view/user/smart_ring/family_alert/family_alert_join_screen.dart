import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:miaid/api_utils/http_exception.dart';
import 'package:miaid/config/app_colors.dart';
import 'package:miaid/generated/l10n.dart';
import 'package:miaid/view/user/smart_ring/family_alert/family_alert_widgets.dart';

/// 家人端输入 6 位邀请码绑定长辈（演示版）。
class FamilyAlertJoinScreen extends StatefulWidget {
  const FamilyAlertJoinScreen({Key? key}) : super(key: key);

  @override
  State<FamilyAlertJoinScreen> createState() => _FamilyAlertJoinScreenState();
}

class _FamilyAlertJoinScreenState extends State<FamilyAlertJoinScreen> {
  static const _length = 6;

  final _codeController = TextEditingController();
  final _codeFocus = FocusNode();
  final _nicknameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _codeController.addListener(() => setState(() {}));
    _nicknameController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _codeController.dispose();
    _codeFocus.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  bool get _ready => _codeController.text.length == _length && _nicknameController.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      backgroundColor: AppColors.kf4f4f4,
      appBar: familyAlertAppBar(context, s.familyAlertJoin),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            Center(child: Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [AppColors.k0cbcc5, AppColors.k0CC58F]),
                boxShadow: [BoxShadow(color: AppColors.k0cbcc5.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 6))],
              ),
              child: const Icon(Icons.family_restroom, color: Colors.white, size: 36),
            )),
            const SizedBox(height: 18),
            Text(s.familyAlertJoin, textAlign: TextAlign.center,
                style: GoogleFonts.rubik(color: AppColors.k010101, fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(s.familyAlertJoinDesc, textAlign: TextAlign.center,
                style: GoogleFonts.rubik(color: AppColors.k8f8e94, fontSize: 13, height: 1.4)),
            const SizedBox(height: 26),
            _codeBoxes(context),
            const SizedBox(height: 22),
            familyCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: TextField(
                controller: _nicknameController,
                maxLength: 10,
                style: GoogleFonts.rubik(color: AppColors.k010101, fontSize: 15),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  counterText: '',
                  icon: Icon(Icons.badge_outlined, color: AppColors.k0cbcc5, size: 20),
                  labelText: s.familyAlertNickname,
                  labelStyle: GoogleFonts.rubik(color: AppColors.k8f8e94, fontSize: 13),
                  hintText: s.familyAlertNicknameHint,
                  hintStyle: GoogleFonts.rubik(color: AppColors.kb1b1b1, fontSize: 14),
                ),
              ),
            ),
            const SizedBox(height: 28),
            familyFilledButton(s.familyAlertJoin, onPressed: _ready ? () => unawaited(_join(context)) : null),
            familyDemoNote(context),
          ],
        ),
      ),
    );
  }

  /// 6 个格子 + 一个隐形输入框承接键盘输入。
  Widget _codeBoxes(BuildContext context) {
    final text = _codeController.text;
    return GestureDetector(
      onTap: () => _codeFocus.requestFocus(),
      child: Stack(children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < _length; i++) ...[
              if (i == 3) const SizedBox(width: 14) else if (i > 0) const SizedBox(width: 8),
              _box(i < text.length ? text[i] : '', active: _codeFocus.hasFocus && i == text.length),
            ],
          ],
        ),
        Positioned.fill(
          child: Opacity(
            opacity: 0,
            child: TextField(
              controller: _codeController,
              focusNode: _codeFocus,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(_length)],
              onChanged: (_) => setState(() {}),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _box(String ch, {required bool active}) {
    return Container(
      width: 44,
      height: 54,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: active ? AppColors.k0cbcc5 : Colors.transparent, width: 1.4),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Text(ch, style: GoogleFonts.rubik(color: AppColors.k003f51, fontSize: 24, fontWeight: FontWeight.w700)),
    );
  }

  Future<void> _join(BuildContext context) async {
    final s = S.of(context);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    unawaited(HttpExceptionNotifyUser.showInfo(s.familyAlertJoinSuccess(_nicknameController.text.trim())));
    Navigator.pop(context);
  }
}
