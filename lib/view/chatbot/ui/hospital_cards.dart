import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:map_launcher/map_launcher.dart' as ml;
// ignore: deprecated_member_use
import 'package:url_launcher/url_launcher.dart';

import '../../../config/app_colors.dart';
import '../../../generated/l10n.dart';
import 'chat_card_widgets.dart';

/// 附近医院卡片列表：渲染 AI 查询附近医院返回的结构化数据。
/// 每项字段：name / address / phone / website / is_private /
/// has_emergency_department，以及可选的 latitude / longitude / distance。
/// 心理工作流的 m4_list 复用本组件，它没有 is_private /
/// has_emergency_department 字段，此时不显示公立/急诊标签。
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

  String? _field(String key) => cardField(hospital, key);

  double? _coord(String key) => double.tryParse(hospital[key]?.toString() ?? '');

  String? _distanceText() {
    final d = double.tryParse(hospital['distance']?.toString() ?? '');
    if (d == null) return null;
    return d < 1 ? '${(d * 1000).round()} m' : '$d km';
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
    // 医院查询接口总会带这两个字段；心理工作流的 m4_list 不带，缺失时不显示标签
    final showTags = hospital.containsKey('is_private') ||
        hospital.containsKey('has_emergency_department');
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
          if (showTags) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                ChatCardTag(
                  text: isPrivate
                      ? S.of(context).hospitalPrivate
                      : S.of(context).hospitalPublic,
                  color: AppColors.k0cbcc5,
                ),
                const SizedBox(width: 6),
                ChatCardTag(
                  text: hasEmergency
                      ? S.of(context).hospitalHasEmergency
                      : S.of(context).hospitalNoEmergency,
                  color: hasEmergency ? Colors.redAccent : AppColors.kb1b1b1,
                ),
              ],
            ),
          ],
          if (address != null)
            ChatCardInfoRow(
              icon: Icons.location_on_outlined,
              text: address,
              onTap: () => _openMap(context, name, address),
            ),
          if (phone != null)
            ChatCardInfoRow(
              icon: Icons.phone_outlined,
              text: phone,
              isLink: true,
              // 点击跳转到系统拨号页面
              onTap: () => dialPhone(context, phone),
            ),
          if (website != null)
            ChatCardInfoRow(
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
