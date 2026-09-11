import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:miaid/config/app_colors.dart';
import 'package:miaid/generated/l10n.dart';

/// 进入药店前让用户先选配送方式的底部弹窗。
///
/// 只展示药店支持的方式（后台药店管理页的 support_pickup / support_delivery）。
/// 即使只有一种可选也照样弹出，让用户明确知道本次是自取还是寄送。
/// 返回值与 CartEShopStore.deliveryOption 一致：1 到店自取，2 寄送；关闭弹窗返回 null。
Future<int?> showDeliveryMethodSheet(
  BuildContext context, {
  required bool pickupAvailable,
  required bool deliveryAvailable,
}) {
  return showModalBottomSheet<int>(
    context: context,
    backgroundColor: Colors.white,
    isDismissible: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(16),
        topRight: Radius.circular(16),
      ),
    ),
    builder: (context) => SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              S.of(context).chooseDeliveryMethod,
              textAlign: TextAlign.center,
              style: GoogleFonts.rubik(
                color: AppColors.k010101,
                fontSize: 17,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            if (pickupAvailable)
              _DeliveryMethodTile(
                icon: Icons.storefront_outlined,
                title: S.of(context).pickupOption,
                subtitle: S.of(context).pickupOptionHint,
                onTap: () => Navigator.pop(context, 1),
              ),
            if (pickupAvailable && deliveryAvailable) const SizedBox(height: 10),
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
    ),
  );
}

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
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Icon(icon, size: 24, color: AppColors.k0cbcc5),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.rubik(
                      color: AppColors.k010101,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.rubik(
                      color: AppColors.k8f8e94,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.kb1b1b1),
          ],
        ),
      ),
    );
  }
}
