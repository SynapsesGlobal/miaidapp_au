import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config/app_colors.dart';
import '../generated/l10n.dart';
import 'marketing_product_card.dart' show MarketingCompanyRow;

/// 分类商品页的商家筛选弹层：列出该主分类下有商品的商家（后端 `/category/products`
/// 的 `companies`，形状 `{companyId, name, image, distance}`，按距离由近到远），
/// 第一项是「全部商家」。商家多时可在顶部按名称过滤（本地过滤，不发请求）。
///
/// 用 [show] 弹出，返回选中的 companyId（0 = 全部），用户直接关掉返回 null。
class MarketingShopPicker extends StatefulWidget {
  const MarketingShopPicker({
    super.key,
    required this.companies,
    required this.selectedCompanyId,
  });

  final List companies;
  final int selectedCompanyId;

  /// 列表超过这个数量才显示本地搜索框
  static const int searchThreshold = 6;

  static Future<int?> show(
    BuildContext context, {
    required List companies,
    required int selectedCompanyId,
  }) {
    return showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => MarketingShopPicker(
        companies: companies,
        selectedCompanyId: selectedCompanyId,
      ),
    );
  }

  /// JSON 里的 companyId 可能是 int 也可能是字符串
  static int companyIdOf(dynamic company) {
    final value = company is Map ? company['companyId'] : null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  @override
  State<MarketingShopPicker> createState() => _MarketingShopPickerState();
}

class _MarketingShopPickerState extends State<MarketingShopPicker> {
  String _filter = '';

  List get _visible {
    final needle = _filter.trim().toLowerCase();
    if (needle.isEmpty) return widget.companies;
    return widget.companies
        .where((c) => (c is Map ? c['name']?.toString() ?? '' : '').toLowerCase().contains(needle))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);
    final visible = _visible;
    final showSearch = widget.companies.length > MarketingShopPicker.searchThreshold;

    // 高度随商家数量伸缩，最多占屏幕六成；商家少时不会撑出一大块空白
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 20, bottom: 12),
            child: Text(l10n.selectShop, style: GoogleFonts.rubik(
              fontSize: 17,
              fontWeight: FontWeight.w500,
              color: AppColors.k010101,
            )),
          ),
          if (showSearch)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: TextField(
                autofocus: false,
                onChanged: (value) => setState(() => _filter = value),
                style: GoogleFonts.rubik(color: AppColors.k010101, fontSize: 14),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: l10n.searchShops,
                  hintStyle: GoogleFonts.rubik(color: AppColors.kb1b1b1, fontSize: 14),
                  prefixIcon: Icon(Icons.search, color: AppColors.kb1b1b1, size: 20),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: AppColors.kb1b1b1, width: 0.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: AppColors.k010101),
                  ),
                ),
              ),
            ),
          Divider(color: Colors.grey[300], height: 0),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: 8),
              // 搜索时不显示「全部商家」，避免和过滤结果混在一起
              itemCount: visible.length + (_filter.trim().isEmpty ? 1 : 0),
              separatorBuilder: (_, __) => Divider(color: Colors.grey[200], height: 0, indent: 72),
              itemBuilder: (context, index) {
                if (_filter.trim().isEmpty && index == 0) {
                  return _tile(
                    context,
                    leading: _avatarFrame(Icon(Icons.storefront_outlined, color: AppColors.k0cbcc5, size: 22)),
                    title: l10n.allShops,
                    selected: widget.selectedCompanyId == 0,
                    onTap: () => Navigator.pop(context, 0),
                  );
                }
                final company = visible[_filter.trim().isEmpty ? index - 1 : index];
                final id = MarketingShopPicker.companyIdOf(company);
                return _tile(
                  context,
                  leading: _avatar(company is Map ? company['image']?.toString() : null),
                  title: company is Map ? company['name']?.toString() ?? '' : '',
                  subtitle: MarketingCompanyRow.distanceLabel(company is Map ? company['distance'] : null),
                  selected: widget.selectedCompanyId == id,
                  onTap: () => Navigator.pop(context, id),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(
    BuildContext context, {
    required Widget leading,
    required String title,
    required bool selected,
    required VoidCallback onTap,
    String? subtitle,
  }) {
    return ListTile(
      leading: leading,
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.rubik(
        color: selected ? AppColors.k0cbcc5 : AppColors.k010101,
        fontSize: 14,
        fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
      )),
      subtitle: subtitle == null
          ? null
          : Text(subtitle, style: GoogleFonts.rubik(color: Colors.grey.shade500, fontSize: 11)),
      trailing: selected ? Icon(Icons.check, color: AppColors.k0cbcc5, size: 20) : null,
      onTap: onTap,
    );
  }

  Widget _avatar(String? url) {
    final fallback = _avatarFrame(Icon(Icons.storefront_outlined, color: Colors.grey.shade400, size: 22));
    if (url == null || url.isEmpty) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: CachedNetworkImage(
        imageUrl: url,
        width: 40,
        height: 40,
        fit: BoxFit.cover,
        placeholder: (_, __) => fallback,
        errorWidget: (_, __, ___) => fallback,
      ),
    );
  }

  Widget _avatarFrame(Widget child) {
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.keefeff,
        borderRadius: BorderRadius.circular(8),
      ),
      child: child,
    );
  }
}
