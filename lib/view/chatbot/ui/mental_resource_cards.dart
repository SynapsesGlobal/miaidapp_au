import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/app_colors.dart';
import 'chat_card_widgets.dart';

/// 心理援助热线 / 在线支持平台卡片列表（m2_list / m3_list）。
/// 每项字段：country / name / description，热线带 phone，在线平台带 website；
/// 缺失的字段不显示。
class MentalResourceCards extends StatelessWidget {
  final List<Map<String, dynamic>> items;

  const MentalResourceCards({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items.map((item) => _MentalResourceCard(item: item)).toList(),
    );
  }
}

class _MentalResourceCard extends StatelessWidget {
  final Map<String, dynamic> item;

  const _MentalResourceCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final name = cardField(item, 'name');
    if (name == null) return const Offstage();
    final country = cardField(item, 'country');
    final description = cardField(item, 'description');
    final phone = cardField(item, 'phone');
    final website = cardField(item, 'website');

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
              if (country != null) ...[
                const SizedBox(width: 6),
                ChatCardTag(text: country, color: AppColors.k0cbcc5),
              ],
            ],
          ),
          if (description != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                description,
                style: GoogleFonts.rubik(
                  color: AppColors.k010101,
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
            ),
          if (phone != null)
            ChatCardInfoRow(
              icon: Icons.phone_outlined,
              text: phone,
              isLink: true,
              onTap: () => dialPhone(context, phone),
            ),
          if (website != null)
            ChatCardInfoRow(
              icon: Icons.language_outlined,
              text: website,
              isLink: true,
              // 在外部浏览器打开在线平台
              onTap: () => _openWebsite(website),
            ),
        ],
      ),
    );
  }
}

Future<void> _openWebsite(String website) async {
  final uri = Uri.tryParse(website.trim());
  if (uri == null || !uri.hasScheme) return;
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}
