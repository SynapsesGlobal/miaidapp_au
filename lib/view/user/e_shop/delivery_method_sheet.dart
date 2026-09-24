import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:miaid/config/app_colors.dart';
import 'package:miaid/generated/l10n.dart';

/// 进入药店前让用户先选配送方式的弹框（页面居中显示，不从底部弹出）。
///
/// 只展示药店支持的方式（后台药店管理页的 support_pickup / support_delivery）。
/// 即使只有一种可选也照样弹出，让用户明确知道本次是自取还是寄送。
/// 返回值与 CartEShopStore.deliveryOption 一致：1 到店自取，2 寄送；关闭弹框返回 null。
Future<int?> showDeliveryMethodSheet(
  BuildContext context, {
  required bool pickupAvailable,
  required bool deliveryAvailable,
}) {
  return showDialog<int>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black.withOpacity(0.45),
    builder: (context) => Dialog(
      backgroundColor: Colors.white,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      // 固定弹框宽度：手机上为屏宽减两侧留白，iPad 上收窄到 460，居中显示一张手机大小的卡片
      child: SizedBox(
        width: math.min(MediaQuery.of(context).size.width - 64, 460),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 28, 22, 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 顶部品牌色渐变圆形图标，作为弹框的视觉焦点
                  Center(
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            const Color(0xFF12CCD6),
                            AppColors.k0cbcc5,
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.k0cbcc5.withOpacity(0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.shopping_bag_outlined,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    S.of(context).chooseDeliveryMethod,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.rubik(
                      color: AppColors.k010101,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (pickupAvailable)
                    _DeliveryMethodTile(
                      icon: Icons.storefront_outlined,
                      title: S.of(context).pickupOption,
                      subtitle: S.of(context).pickupOptionHint,
                      onTap: () => Navigator.pop(context, 1),
                    ),
                  if (pickupAvailable && deliveryAvailable)
                    const SizedBox(height: 12),
                  if (deliveryAvailable)
                    _DeliveryMethodTile(
                      icon: Icons.local_shipping_outlined,
                      title: S.of(context).deliveryOptionLabel,
                      subtitle: S.of(context).deliveryOptionHint,
                      onTap: () => Navigator.pop(context, 2),
                    ),
                ],
              ),
            ),
            // 右上角关闭：不选直接退出，不进入药店
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                splashRadius: 20,
                icon: Icon(Icons.close, size: 20, color: AppColors.kb1b1b1),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// 单个配送方式选项：左侧品牌色图标底板，中间标题与说明，右侧箭头
class _DeliveryMethodTile extends StatelessWidget {
  const _DeliveryMethodTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        splashColor: AppColors.k0cbcc5.withOpacity(0.08),
        highlightColor: AppColors.k0cbcc5.withOpacity(0.05),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFF7FBFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.k0cbcc5.withOpacity(0.18)),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.k0cbcc5.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, size: 24, color: AppColors.k0cbcc5),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.rubik(
                        color: AppColors.k010101,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: GoogleFonts.rubik(
                        color: AppColors.k8f8e94,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.k0cbcc5.withOpacity(0.25)),
                ),
                child: Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 13,
                  color: AppColors.k0cbcc5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
