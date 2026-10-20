import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:miaid/config/app_colors.dart';
import 'package:miaid/generated/l10n.dart';
import 'package:miaid/services/marketing_payment_service.dart';
import 'package:miaid/widget/quantity_dialog.dart';

/// marketing 商品列表共用的卡片及其零件，供商家商品页（CompanyProducts）和
/// 分类商品页（CategoryProducts）复用；两边的商品 JSON 结构相同
/// （productId/companyId/title/description/price/discount_price/currency/image）。

/// 商品图（含占位与出错兜底）
Widget marketingProductImage(Map product, {double? height, double? width}) {
  return CachedNetworkImage(
    height: height,
    width: width,
    fit: BoxFit.cover,
    imageUrl: product['image']?.toString() ?? '',
    placeholder: (context, url) => Container(
      height: height,
      width: width,
      color: const Color(0xFFEDEFF2),
      child: Icon(Icons.image_outlined, size: 28, color: Colors.grey.shade400),
    ),
    errorWidget: (context, url, error) => Container(
      height: height,
      width: width,
      color: const Color(0xFFEDEFF2),
      child: Icon(Icons.broken_image_outlined,
          size: 28, color: Colors.grey.shade400),
    ),
  );
}

/// 价格行：折后价 + 划线原价（无折扣时只显示一个价）
class MarketingPriceRow extends StatelessWidget {
  final Map product;
  final double fontSize;
  const MarketingPriceRow(
      {super.key, required this.product, this.fontSize = 16});

  @override
  Widget build(BuildContext context) {
    final hasDiscount = product['price'] != product['discount_price'];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text('${product['currency']} ',
            style: GoogleFonts.rubik(
              color: AppColors.k0cbcc5,
              fontSize: fontSize - 4,
              fontWeight: FontWeight.w500,
            )),
        Text('${product['discount_price']}',
            style: GoogleFonts.rubik(
              color: AppColors.k0cbcc5,
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
            )),
        if (hasDiscount) ...[
          const SizedBox(width: 6),
          Flexible(
            child: Text('${product['currency']} ${product['price']}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.rubik(
                  color: Colors.grey,
                  fontSize: fontSize - 4,
                  decoration: TextDecoration.lineThrough,
                  decorationColor: Colors.grey,
                )),
          ),
        ],
      ],
    );
  }
}

/// “立即购买”按钮：弹数量选择后走 MarketingPaymentService 下单
class MarketingPurchaseButton extends StatelessWidget {
  final Map product;
  final bool fullWidth;
  const MarketingPurchaseButton(
      {super.key, required this.product, this.fullWidth = false});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () async {
        final productId = product['productId'].toString();
        final companyId = product['companyId'].toString();
        await showQuantityDialog(
          context: context,
          title: product['title']?.toString() ?? '',
          currency: product['currency']?.toString(),
          unitPrice: num.tryParse(product['discount_price'].toString()),
          imageUrl: product['image']?.toString(),
          onConfirm: (qty) async {
            await MarketingPaymentService.instance.handlePurchase(
              context: context,
              companyId: companyId,
              products: [
                {
                  'productId': productId,
                  'quantity': qty,
                }
              ],
            );
          },
        );
      },
      child: Container(
        width: fullWidth ? double.infinity : null,
        alignment: fullWidth ? Alignment.center : null,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.k0cbcc5,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          S.of(context).purchase_now,
          style: GoogleFonts.rubik(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

/// 列表里的一张商品卡：左图右文 + 价格 + 购买按钮；[company] 是价格行下面的
/// 商家属性行（分类商品页用，见 [MarketingCompanyRow]）。
class MarketingProductCard extends StatelessWidget {
  final Map product;
  final VoidCallback onTap;
  final Widget? company;
  const MarketingProductCard(
      {super.key, required this.product, required this.onTap, this.company});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child:
                      marketingProductImage(product, height: 104, width: 104),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product['title']?.toString() ?? '',
                        style: GoogleFonts.rubik(
                          color: AppColors.k010101,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        product['description']?.toString() ?? '',
                        style: GoogleFonts.rubik(
                          color: Colors.grey.shade500,
                          fontSize: 12,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(child: MarketingPriceRow(product: product)),
                          const SizedBox(width: 8),
                          MarketingPurchaseButton(product: product),
                        ],
                      ),
                      if (company != null) ...[
                        company!,
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 商家属性行（店铺图标 + 名称 + 距离），放在分类商品页卡片的价格行下面，
/// 点击进入该商家的商品列表。[company] 是后端 /category/products 返回的
/// `company` 对象（与 /companies 一致）。
class MarketingCompanyRow extends StatelessWidget {
  final Map company;
  final VoidCallback onTap;
  const MarketingCompanyRow(
      {super.key, required this.company, required this.onTap});

  /// 后端给的 distance 是公里数（一位小数）；不足 1 km 显示米。
  static String? distanceLabel(dynamic distance) {
    final km = double.tryParse(distance?.toString() ?? '');
    if (km == null) return null;
    if (km < 1) return '${(km * 1000).round()} m';
    return '${km.toStringAsFixed(1)} km';
  }

  @override
  Widget build(BuildContext context) {
    final distance = distanceLabel(company['distance']);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.storefront_outlined,
                size: 13, color: Colors.grey.shade500),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                company['name']?.toString() ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.rubik(
                  color: Colors.grey.shade600,
                  fontSize: 11,
                ),
              ),
            ),
            if (distance != null) ...[
              const SizedBox(width: 6),
              Text(
                distance,
                style: GoogleFonts.rubik(
                  color: Colors.grey.shade500,
                  fontSize: 11,
                ),
              ),
            ],
            Icon(Icons.chevron_right, size: 14, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}

/// 列表尾部：加载更多转圈 / “没有更多商品”
class MarketingListFooter extends StatelessWidget {
  final bool loadingMore;
  final bool hasMore;
  const MarketingListFooter(
      {super.key, required this.loadingMore, required this.hasMore});

  @override
  Widget build(BuildContext context) {
    if (loadingMore) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CupertinoActivityIndicator()),
      );
    }

    if (!hasMore) {
      return Padding(
        padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 32),
        child: Center(
            child: Text('—— ${S.of(context).no_more_products} ——',
                style: GoogleFonts.rubik(
                  color: Colors.grey,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ))),
      );
    }

    return const SizedBox.shrink();
  }
}

/// 列表为空时的占位（加载中不显示）
class MarketingEmptyState extends StatelessWidget {
  final bool loading;
  const MarketingEmptyState({super.key, required this.loading});

  @override
  Widget build(BuildContext context) {
    if (loading) return const SizedBox.shrink();
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inventory_2_outlined,
              size: 56, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text('No data available.',
              style: GoogleFonts.rubik(
                color: Colors.grey,
                fontSize: 14,
                fontWeight: FontWeight.normal,
              )),
        ],
      ),
    );
  }
}
