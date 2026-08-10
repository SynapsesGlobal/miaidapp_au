import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:map_launcher/map_launcher.dart' as ml;
// ignore: deprecated_member_use
import 'package:url_launcher/url_launcher.dart';

import '../../../config/app_colors.dart';
import '../../../generated/l10n.dart';

/// 附近医院卡片列表：渲染 AI 查询附近医院返回的结构化数据。
/// 每项字段：name / address / phone / website / is_private /
/// has_emergency_department，以及可选的 latitude / longitude / distance。
class HospitalCards extends StatelessWidget {
  final List<Map<String, dynamic>> hospitals;

  const HospitalCards({super.key, required this.hospitals});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: hospitals
          .map((h) => _HospitalCard(hospital: h))
          .toList(),
    );
  }
}

class _HospitalCard extends StatelessWidget {
  final Map<String, dynamic> hospital;

  const _HospitalCard({required this.hospital});

  /// 无效值（null/空/na/-/unknown 等）一律不展示
  String? _field(String key) {
    final value = hospital[key]?.toString().trim();
    if (value == null || value.isEmpty) return null;
    const invalid = ['na', 'n/a', '-', 'unknown', 'null'];
    if (invalid.contains(value.toLowerCase())) return null;
    return value;
  }

  double? _coord(String key) => double.tryParse(hospital[key]?.toString() ?? '');

  String? _distanceText() {
    final d = double.tryParse(hospital['distance']?.toString() ?? '');
    if (d == null) return null;
    return d < 1 ? '${(d * 1000).round()} m' : '$d km';
  }

  /// 跳转系统拨号页面；无法拨号的环境（如 iOS 模拟器没有电话应用）
  /// 复制号码并提示，避免点击无任何反馈
  Future<void> _dial(BuildContext context, String phone) async {
    // 只保留数字及拨号有效符号，避免个别系统解析失败
    final number = phone.replaceAll(RegExp(r'[^0-9+#*,;]'), '');
    var ok = false;
    try {
      // ignore: deprecated_member_use
      ok = await launch('tel://$number');
    } catch (_) {
      ok = false;
    }
    if (!ok && context.mounted) {
      await Clipboard.setData(ClipboardData(text: phone));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${S.of(context).phoneCopied}: $phone')),
      );
    }
  }

  Future<void> _openMap(BuildContext context, String name, String? address) async {
    final latitude = _coord('latitude');
    final longitude = _coord('longitude');
    if (latitude == null || longitude == null) {
      // 老服务端数据无坐标：退化为复制地址
      if (address != null) {
        await Clipboard.setData(ClipboardData(text: '$name $address'));
      }
      return;
    }
    final availableMaps = await ml.MapLauncher.installedMaps;
    if (availableMaps.isNotEmpty) {
      await availableMaps.first.showMarker(
        coords: ml.Coords(latitude, longitude),
        title: name,
        description: address ?? '',
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.of(context).installMap)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = _field('name');
    if (name == null) return const Offstage();
    final address = _field('address');
    final phone = _field('phone');
    final website = _field('website');
    final distance = _distanceText();
    final isPrivate = hospital['is_private'] == true;
    final hasEmergency = hospital['has_emergency_department'] == true;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  name,
                  style: GoogleFonts.rubik(
                    color: AppColors.k010101,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (distance != null) ...[
                const SizedBox(width: 6),
                Text(
                  distance,
                  style: GoogleFonts.rubik(
                    color: AppColors.kb1b1b1,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _Tag(
                text: isPrivate
                    ? S.of(context).hospitalPrivate
                    : S.of(context).hospitalPublic,
                color: AppColors.k0cbcc5,
              ),
              const SizedBox(width: 6),
              _Tag(
                text: hasEmergency
                    ? S.of(context).hospitalHasEmergency
                    : S.of(context).hospitalNoEmergency,
                color: hasEmergency ? Colors.redAccent : AppColors.kb1b1b1,
              ),
            ],
          ),
          if (address != null)
            _InfoRow(
              icon: Icons.location_on_outlined,
              text: address,
              onTap: () => _openMap(context, name, address),
            ),
          if (phone != null)
            _InfoRow(
              icon: Icons.phone_outlined,
              text: phone,
              isLink: true,
              // 点击跳转到系统拨号页面
              onTap: () => _dial(context, phone),
            ),
          if (website != null)
            _InfoRow(
              icon: Icons.language_outlined,
              text: website,
              isLink: true,
              // ignore: deprecated_member_use
              onTap: () => launch(website),
            ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  final Color color;

  const _Tag({required this.text, required this.color});

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

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onTap;

  /// 链接样式：文字用主题色展示，明示可点击（电话、网址）
  final bool isLink;

  const _InfoRow({
    required this.icon,
    required this.text,
    required this.onTap,
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
