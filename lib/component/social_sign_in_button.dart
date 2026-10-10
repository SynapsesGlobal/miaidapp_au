import 'package:flutter/material.dart';
import 'package:miaid/component/google_logo.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// 登录页的第三方登录按钮：左侧平台标志 + 文字。
///
/// 尺寸、圆角和字号与页面上的"登录"按钮一致（高 44、圆角 9、按钮默认字体），
/// 只有配色按各平台的品牌规范：Apple 黑底白字，Google 白底深字加浅灰描边。
class SocialSignInButton extends StatelessWidget {
  const SocialSignInButton({
    Key? key,
    required this.text,
    required this.onPressed,
    required this.logo,
    required this.backgroundColor,
    required this.foregroundColor,
    this.borderColor,
  }) : super(key: key);

  /// Sign in with Apple：黑底白字，Apple 标志用插件自带的画笔
  factory SocialSignInButton.apple({
    Key? key,
    required String text,
    required VoidCallback onPressed,
  }) {
    return SocialSignInButton(
      key: key,
      text: text,
      onPressed: onPressed,
      logo: const SizedBox(
        width: 14,
        height: 17,
        child: CustomPaint(painter: AppleLogoPainter(color: Colors.white)),
      ),
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
    );
  }

  /// Google 登录：按 Google 品牌规范的浅色样式
  factory SocialSignInButton.google({
    Key? key,
    required String text,
    required VoidCallback onPressed,
  }) {
    return SocialSignInButton(
      key: key,
      text: text,
      onPressed: onPressed,
      logo: const GoogleLogo(size: 18),
      backgroundColor: Colors.white,
      foregroundColor: const Color(0xFF1F1F1F),
      borderColor: const Color(0xFFDADCE0),
    );
  }

  static const double _height = 44;
  static const double _borderRadius = 9;

  final String text;
  final VoidCallback onPressed;
  final Widget logo;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _height,
      width: double.infinity,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_borderRadius),
            side: borderColor == null
                ? BorderSide.none
                : BorderSide(color: borderColor!),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            logo,
            const SizedBox(width: 10),
            // 不另设字号，沿用 TextButton 的默认文字样式，与"登录"按钮一致
            Text(text),
          ],
        ),
      ),
    );
  }
}
