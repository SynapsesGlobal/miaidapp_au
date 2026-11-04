import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:map_launcher/map_launcher.dart' as ml;
import 'package:url_launcher/url_launcher.dart';

import '../config/app_colors.dart';
import '../generated/l10n.dart';
import '../view/chatbot/ui/chat_card_widgets.dart' show dialPhone;

/// marketing 商家「联系商家」底部弹框，商品详情页和订单详情页共用。
///
/// [company] 是后端返回的 company 对象（/product/detail、/order/detail），
/// 用到 name / image / phone / address / website / latitude / longitude，
/// 缺哪个字段就隐藏对应的行或禁用对应的按钮，不会因为空值报错。
class ContactShopSheet extends StatelessWidget {
  final Map<String, dynamic> company;

  const ContactShopSheet({super.key, required this.company});

  static Future<void> show(BuildContext context, Map<String, dynamic>? company) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => ContactShopSheet(company: company ?? const {}),
    );
  }

  String? get _name => _text(company['name']);
  String? get _phone => _text(company['phone']);
  String? get _address => _text(company['address']);
  String? get _website => _text(company['website']);
  String? get _image => _text(company['image']);
  double? get _latitude => _number(company['latitude']);
  double? get _longitude => _number(company['longitude']);

  bool get _canDial => _phone != null;
  bool get _canNavigate => _latitude != null && _longitude != null;

  static String? _text(dynamic value) {
    final s = value?.toString().trim() ?? '';
    return s.isEmpty ? null : s;
  }

  static double? _number(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  /// 走聊天卡片同一个拨号逻辑：拨不了（如 iOS 模拟器）就复制号码并提示。
  Future<void> _dial(BuildContext context) async {
    final phone = _phone;
    if (phone == null) return;
    await dialPhone(context, phone);
  }

  Future<void> _openWebsite() async {
    final site = _website;
    if (site == null) return;
    final uri = Uri.tryParse(site.contains('://') ? site : 'https://$site');
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _navigate(BuildContext context) async {
    if (!_canNavigate) return;
    final availableMaps = await ml.MapLauncher.installedMaps;
    if (availableMaps.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.of(context).installMap)),
      );
      return;
    }
    await availableMaps.first.showMarker(
      coords: ml.Coords(_latitude!, _longitude!),
      title: _name ?? '',
      description: _address,
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _dragHandle(),
            const SizedBox(height: 12),
            _header(context, s.contact_shop),
            const SizedBox(height: 16),
            _companyCard(),
            const SizedBox(height: 16),
            if (_phone != null)
              _infoRow(
                icon: Icons.phone_outlined,
                label: s.phone,
                value: _phone!,
                onTap: () => _dial(context),
              ),
            if (_address != null)
              _infoRow(
                icon: Icons.location_on_outlined,
                label: s.address,
                value: _address!,
                onTap: _canNavigate ? () => _navigate(context) : null,
              ),
            if (_website != null)
              _infoRow(
                icon: Icons.language_outlined,
                label: s.website,
                value: _website!,
                onTap: _openWebsite,
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _canNavigate ? () => _navigate(context) : null,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.k0cbcc5,
                      side: BorderSide(color: _canNavigate ? AppColors.k0cbcc5 : AppColors.kb1b1b1),
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.directions_outlined, size: 20),
                    label: Text(s.getDirection, style: GoogleFonts.rubik(fontSize: 15, fontWeight: FontWeight.w500)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _canDial ? () => _dial(context) : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.k0cbcc5,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppColors.kb1b1b1,
                      disabledForegroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.call_outlined, size: 20),
                    label: Text(s.dial_phone, style: GoogleFonts.rubik(fontSize: 15, fontWeight: FontWeight.w500)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 15, color: AppColors.kb1b1b1),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    s.direction_caption,
                    style: GoogleFonts.rubik(fontSize: 12, height: 1.4, color: AppColors.k8f8e94),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _dragHandle() {
    return Center(
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.kb1b1b1.withOpacity(0.6),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _header(BuildContext context, String title) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.rubik(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.k010101),
          ),
        ),
        InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: AppColors.kf4f4f4, shape: BoxShape.circle),
            child: Icon(Icons.close, size: 18, color: AppColors.k696969),
          ),
        ),
      ],
    );
  }

  Widget _companyCard() {
    const avatarSize = 56.0;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.keefeff,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: avatarSize,
            height: avatarSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(color: Colors.white, width: 2),
            ),
            clipBehavior: Clip.antiAlias,
            child: _image == null
                ? Icon(Icons.storefront_outlined, color: AppColors.k0cbcc5, size: 28)
                : CachedNetworkImage(
                    imageUrl: _image!,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) =>
                        Icon(Icons.storefront_outlined, color: AppColors.k0cbcc5, size: 28),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _name ?? '',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.rubik(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.k010101),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow({
    required IconData icon,
    required String label,
    required String value,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.kf4f4f4,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: AppColors.k0cbcc5),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: GoogleFonts.rubik(fontSize: 12, color: AppColors.k8f8e94)),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: GoogleFonts.rubik(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.k010101, height: 1.35),
                  ),
                ],
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, size: 20, color: AppColors.kb1b1b1),
            ],
          ],
        ),
      ),
    );
  }
}
