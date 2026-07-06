import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/app_colors.dart';
import '../generated/l10n.dart';

Future<void> showQuantityDialog({
  required BuildContext context,
  required String title,
  required void Function(int qty) onConfirm,
  String? currency,
  num? unitPrice,
  String? imageUrl,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFFF5F6F8),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      var qty = 1;
      return StatefulBuilder(
        builder: (context, setModalState) {
          Widget sectionCard({required Widget child}) {
            return Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: child,
            );
          }

          Widget stepButton({
            required IconData icon,
            required bool enabled,
            required VoidCallback onTap,
          }) {
            return InkWell(
              onTap: enabled ? onTap : null,
              child: SizedBox(
                width: 40,
                height: 34,
                child: Icon(
                  icon,
                  size: 16,
                  color: enabled ? AppColors.k010101 : Colors.grey[350],
                ),
              ),
            );
          }

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 顶部:拖拽指示条居中,关闭按钮靠右
                SizedBox(
                  height: 40,
                  child: Stack(
                    children: [
                      Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey[350],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 12,
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: InkWell(
                            onTap: () => Navigator.of(context).pop(),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE9EBEE),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Icon(Icons.close,
                                  color: Colors.grey[600], size: 16),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // 卡片:商品信息 + 数量选择
                sectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (imageUrl != null && imageUrl.isNotEmpty) ...[
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: CachedNetworkImage(
                                width: 76,
                                height: 76,
                                fit: BoxFit.cover,
                                imageUrl: imageUrl,
                                errorWidget: (context, url, error) =>
                                    Container(
                                  width: 76,
                                  height: 76,
                                  color: const Color(0xFFF5F5F5),
                                  child: Icon(Icons.image_outlined,
                                      color: Colors.grey[400]),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (unitPrice != null) ...[
                                  Text.rich(
                                    TextSpan(
                                      children: [
                                        TextSpan(
                                          text: '${currency ?? ''} ',
                                          style: GoogleFonts.rubik(
                                            color: AppColors.k0cbcc5,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        TextSpan(
                                          text: unitPrice.toStringAsFixed(2),
                                          style: GoogleFonts.rubik(
                                            color: AppColors.k0cbcc5,
                                            fontSize: 22,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                ],
                                Text(
                                  title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.rubik(
                                    color: AppColors.k5e5e5e,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Divider(
                          height: 1, thickness: 0.5, color: Colors.grey[200]),
                      const SizedBox(height: 14),
                      // 数量选择
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            S.of(context).enter_quantity,
                            style: GoogleFonts.rubik(
                              color: AppColors.k010101,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[300]!),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                stepButton(
                                  icon: CupertinoIcons.minus,
                                  enabled: qty > 1,
                                  onTap: () => setModalState(() => qty -= 1),
                                ),
                                Container(
                                  width: 44,
                                  height: 34,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    border: Border.symmetric(
                                      vertical:
                                          BorderSide(color: Colors.grey[300]!),
                                    ),
                                  ),
                                  child: Text(
                                    qty.toString(),
                                    style: GoogleFonts.rubik(
                                      color: AppColors.k010101,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                stepButton(
                                  icon: CupertinoIcons.plus,
                                  enabled: true,
                                  onTap: () => setModalState(() => qty += 1),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                // 底部操作栏:小计 + 确认按钮
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x14000000),
                        blurRadius: 10,
                        offset: Offset(0, -2),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      child: Row(
                        children: [
                          if (unitPrice != null)
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    S.of(context).subTotal,
                                    style: GoogleFonts.rubik(
                                      color: AppColors.k5e5e5e,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${currency ?? ''} ${(unitPrice * qty).toStringAsFixed(2)}',
                                    style: GoogleFonts.rubik(
                                      color: AppColors.k0cbcc5,
                                      fontSize: 19,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (unitPrice != null) const SizedBox(width: 12),
                          Expanded(
                            flex: unitPrice != null ? 1 : 2,
                            child: MaterialButton(
                              onPressed: () {
                                Navigator.pop(context);
                                onConfirm(qty);
                              },
                              height: 46,
                              elevation: 0,
                              highlightElevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(23),
                              ),
                              color: AppColors.k0cbcc5,
                              child: Text(
                                S.of(context).confirm,
                                style: GoogleFonts.rubik(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}
