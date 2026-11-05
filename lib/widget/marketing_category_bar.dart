import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config/app_colors.dart';
import '../generated/l10n.dart';

/// marketing 商品列表顶部的横向分类栏，商家商品页和分类商品页共用。
///
/// [categories] 的形状与后端 `company.categories` 和 `/category/products` 的
/// `categories` 一致：`{cateId, cateName, cateImg}`，`cateId == 0` 表示全部商品，
/// 文案不用后端返回的，改用本地 l10n（`allProducts`），和列表其它文字一起切语言。
class MarketingCategoryBar extends StatelessWidget {
  const MarketingCategoryBar({
    super.key,
    required this.categories,
    required this.selectedCateId,
    required this.onSelected,
  });

  final List categories;
  final int selectedCateId;
  final ValueChanged<int> onSelected;

  /// 栏高，供外层吸顶 header 计算总高度
  static const double height = 60;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: MediaQuery.of(context).size.width,
      height: height,
      child: ListView.builder(
        padding: const EdgeInsets.only(left: 18, right: 18, top: 16, bottom: 10),
        itemCount: categories.length,
        scrollDirection: Axis.horizontal,
        shrinkWrap: true,
        physics: const BouncingScrollPhysics(),
        itemBuilder: (BuildContext context, int index) {
          final category = categories[index];
          final cateId = _toInt(category['cateId']);
          final selected = selectedCateId == cateId;
          return Row(children: [
            InkWell(
              onTap: () => onSelected(cateId),
              child: Container(
                decoration: BoxDecoration(
                  color: selected ? AppColors.k0cbcc5 : AppColors.kffffff,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    width: 0.5,
                    color: !selected ? AppColors.k0cbcc5 : Colors.transparent,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.k003f51.withOpacity(0.1),
                      offset: const Offset(0, 4),
                      blurRadius: 10,
                      spreadRadius: 0,
                    ),
                  ],
                ),
                padding: const EdgeInsets.only(left: 10, right: 10),
                alignment: Alignment.center,
                child: Text(
                  cateId == 0 ? S.of(context).allProducts : category['cateName']?.toString() ?? '',
                  style: GoogleFonts.rubik(
                    color: selected ? AppColors.kffffff : AppColors.k010101,
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
          ]);
        },
      ),
    );
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
