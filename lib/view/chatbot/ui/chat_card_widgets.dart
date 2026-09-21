import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/app_colors.dart';
import '../../../generated/l10n.dart';

/// 聊天卡片（医院卡片、心理资源卡片）共用的小部件与工具。

/// 无效值（null/空/na/-/unknown 等）一律视为缺失
String? cardField(Map<String, dynamic> data, String key) {
  final value = data[key]?.toString().trim();
  if (value == null || value.isEmpty) return null;
  const invalid = ['na', 'n/a', '-', 'unknown', 'null'];
  if (invalid.contains(value.toLowerCase())) return null;
  return value;
}

/// 跳转系统拨号页面；无法拨号的环境（如 iOS 模拟器没有电话应用）
/// 复制号码并提示，避免点击无任何反馈
Future<void> dialPhone(BuildContext context, String phone) async {
  // 只保留数字及拨号有效符号，避免个别系统解析失败
  final number = phone.replaceAll(RegExp(r'[^0-9+#*,;]'), '');
  var ok = false;
  if (number.isNotEmpty) {
    try {
      // 标准写法是 tel:<号码>（不带 //）：带 // 时号码会被当成 URI 的 host，
      // 以 + 开头的国际号码在部分系统上无法解析，拨号页打不开
      ok = await launchUrl(Uri(scheme: 'tel', path: number));
    } catch (_) {
      ok = false;
    }
  }
  if (!ok && context.mounted) {
    await Clipboard.setData(ClipboardData(text: phone));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${S.of(context).phoneCopied}: $phone')),
    );
  }
}

class ChatCardTag extends StatelessWidget {
  final String text;
  final Color color;

  const ChatCardTag({super.key, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: GoogleFonts.rubik(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class ChatCardInfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback? onTap;

  /// 链接样式：文字用主题色展示，明示可点击（电话、网址）
  final bool isLink;

  const ChatCardInfoRow({
    super.key,
    required this.icon,
    required this.text,
    this.onTap,
    this.isLink = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 15, color: AppColors.k0cbcc5),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                text,
                style: GoogleFonts.rubik(
                  color: isLink ? AppColors.k0cbcc5 : AppColors.k010101,
                  fontSize: 13,
                  height: 1.35,
                  decoration: isLink ? TextDecoration.underline : null,
                  decorationColor: AppColors.k0cbcc5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 卡片组标题（如"心理援助热线"）
class ChatCardSectionTitle extends StatelessWidget {
  final String text;

  const ChatCardSectionTitle({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Text(
        text,
        style: GoogleFonts.rubik(
          color: AppColors.k010101,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
