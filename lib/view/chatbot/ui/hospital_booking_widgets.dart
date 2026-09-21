import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../config/app_colors.dart';

/// 医院预约列表页、详情页共用的视觉元素。

/// 页面底色：卡片是白色，靠它衬出层次
const bookingPageBackground = Color(0xFFF4F7F9);

/// 主题色的深色端，用于渐变
const bookingTealDark = Color(0xFF0895A8);

/// 未确认状态色
const bookingPending = Color(0xFFE68C30);

/// 卡片内分隔线
const bookingDivider = Color(0xFFEEF2F4);

TextStyle bookingText({
  double size = 14,
  FontWeight weight = FontWeight.normal,
  Color? color,
  double? height,
}) {
  return GoogleFonts.rubik(
    fontSize: size,
    fontWeight: weight,
    color: color ?? AppColors.k010101,
    height: height,
  );
}

/// 白色圆角卡片，带很轻的投影
class BookingCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onTap;

  const BookingCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = const EdgeInsets.only(top: 12),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(16);
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0B3C49).withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        // 卡片里的行自带点击水波时，不让它溢出圆角
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// 主题色渐变的头部卡片
class BookingGradientHeader extends StatelessWidget {
  final Widget child;

  const BookingGradientHeader({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.k0cbcc5, bookingTealDark],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.k0cbcc5.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// 已确认医院数 / 医院总数 的进度条
class BookingProgressBar extends StatelessWidget {
  final int confirmed;
  final int total;

  /// 放在渐变头部上时用白色系
  final bool onGradient;

  const BookingProgressBar({
    super.key,
    required this.confirmed,
    required this.total,
    this.onGradient = false,
  });

  @override
  Widget build(BuildContext context) {
    final value = total <= 0 ? 0.0 : (confirmed / total).clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: value,
        minHeight: 6,
        backgroundColor: onGradient ? Colors.white.withOpacity(0.28) : const Color(0xFFE6EEF0),
        valueColor: AlwaysStoppedAnimation<Color>(onGradient ? Colors.white : AppColors.k0cbcc5),
      ),
    );
  }
}

/// 状态徽标：圆点 + 文字
class BookingStatusBadge extends StatelessWidget {
  final String text;
  final Color color;

  const BookingStatusBadge({super.key, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(text, style: bookingText(size: 12, weight: FontWeight.w500, color: color)),
      ]),
    );
  }
}

/// 圆形底的小图标
class BookingIconBubble extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;

  const BookingIconBubble({super.key, required this.icon, required this.color, this.size = 38});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
      child: Icon(icon, color: color, size: size * 0.52),
    );
  }
}

/// 空状态 / 加载失败时居中展示的提示
class BookingPlaceholder extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback? onRetry;

  const BookingPlaceholder({super.key, required this.icon, required this.text, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          BookingIconBubble(icon: icon, color: AppColors.k0cbcc5, size: 84),
          const SizedBox(height: 18),
          Text(
            text,
            textAlign: TextAlign.center,
            style: bookingText(size: 14, color: AppColors.k8f8e94, height: 1.5),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: onRetry,
              icon: Icon(Icons.refresh, color: AppColors.k0cbcc5, size: 18),
              label: Text(
                MaterialLocalizations.of(context).refreshIndicatorSemanticLabel,
                style: bookingText(size: 14, weight: FontWeight.w500, color: AppColors.k0cbcc5),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}
