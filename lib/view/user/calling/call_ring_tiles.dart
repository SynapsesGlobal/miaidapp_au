import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:miaid/config/app_colors.dart';
import 'package:miaid/generated/l10n.dart';

/// 通话内戒指数据弹层（患者端「分享给医生」、医生端「患者戒指数据」）共用的紧凑网格。
class RingShareTile {
  const RingShareTile({
    required this.key,
    required this.label,
    required this.value,
    required this.unit,
    required this.caption,
    required this.range,
    required this.icon,
    required this.color,
    this.detail,
  });

  final String key;
  final String label;
  final String value;
  final String unit;

  /// 格子里的小字：读数时间或睡眠分期摘要。
  final String caption;
  final String range;

  /// 点选后参考范围下方的补充说明（睡眠完整分期）。
  final String? detail;
  final IconData icon;
  final Color color;
}

/// 弹层顶部的拖拽条。
Widget ringSheetHandle() {
  return Center(child: Container(
    width: 36,
    height: 4,
    decoration: BoxDecoration(
      color: AppColors.kb1b1b1.withOpacity(0.5),
      borderRadius: BorderRadius.circular(2),
    ),
  ));
}

/// 弹层头部：色块图标 + 标题 + 一行副标题 + 可选右侧控件。
Widget ringSheetHeader({
  required IconData icon,
  required String title,
  String? subtitle,
  Widget? trailing,
}) {
  return Row(children: [
    Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: AppColors.k0cbcc5.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: AppColors.k0cbcc5, size: 19),
    ),
    const SizedBox(width: 10),
    Expanded(child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: GoogleFonts.rubik(
          color: AppColors.k010101,
          fontSize: 15.5,
          fontWeight: FontWeight.w600,
        )),
        if (subtitle != null && subtitle.isNotEmpty) ...[
          const SizedBox(height: 1),
          Text(subtitle, style: GoogleFonts.rubik(color: AppColors.k8f8e94, fontSize: 11.5),
              maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ],
    )),
    if (trailing != null) ...[
      const SizedBox(width: 6),
      trailing,
    ],
  ]);
}

Widget ringSectionTitle(String title) {
  return Text(title, style: GoogleFonts.rubik(
    color: AppColors.k8f8e94,
    fontSize: 11.5,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
  ));
}

/// 两列小格；奇数个时最后一格占满一行。[onTap] 为空时格子不可点。
Widget ringTileGrid(
  List<RingShareTile> tiles, {
  String? selectedKey,
  ValueChanged<RingShareTile>? onTap,
}) {
  final rows = <Widget>[];
  for (var i = 0; i < tiles.length; i += 2) {
    final left = tiles[i];
    final right = i + 1 < tiles.length ? tiles[i + 1] : null;
    rows.add(Padding(
      padding: EdgeInsets.only(bottom: i + 2 < tiles.length ? 6 : 0),
      child: Row(children: [
        Expanded(child: _tile(left, selectedKey == left.key, onTap)),
        if (right != null) ...[
          const SizedBox(width: 6),
          Expanded(child: _tile(right, selectedKey == right.key, onTap)),
        ],
      ]),
    ));
  }
  return Column(children: rows);
}

Widget _tile(RingShareTile t, bool selected, ValueChanged<RingShareTile>? onTap) {
  final body = Container(
    padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
    decoration: BoxDecoration(
      color: AppColors.kf4f4f4,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: selected ? t.color.withOpacity(0.6) : Colors.transparent, width: 1.2),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(t.icon, color: t.color, size: 13),
          const SizedBox(width: 4),
          Expanded(child: Text(t.label, style: GoogleFonts.rubik(color: AppColors.k5e5e5e, fontSize: 11.5),
              maxLines: 1, overflow: TextOverflow.ellipsis)),
        ]),
        const SizedBox(height: 3),
        Text.rich(TextSpan(children: [
          TextSpan(text: t.value, style: GoogleFonts.rubik(
            color: AppColors.k010101,
            fontSize: 17,
            fontWeight: FontWeight.w600,
            height: 1.1,
          )),
          if (t.unit.isNotEmpty)
            TextSpan(text: ' ${t.unit}', style: GoogleFonts.rubik(color: AppColors.k8f8e94, fontSize: 10.5)),
        ]), maxLines: 1, overflow: TextOverflow.ellipsis),
        if (t.caption.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(t.caption, style: GoogleFonts.rubik(color: AppColors.kb1b1b1, fontSize: 10),
              maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ],
    ),
  );
  if (onTap == null) return body;
  return InkWell(
    onTap: () => onTap(t),
    borderRadius: BorderRadius.circular(12),
    child: body,
  );
}

/// 点选某格后，在网格下方显示它的参考范围（以及睡眠分期等补充信息）。
Widget ringRangeBar(BuildContext context, RingShareTile t) {
  final s = S.of(context);
  return Container(
    padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
    decoration: BoxDecoration(
      color: t.color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(Icons.straighten, color: t.color, size: 14),
      const SizedBox(width: 6),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${t.label} · ${s.smartRingReferenceRange}', style: GoogleFonts.rubik(
            color: AppColors.k010101,
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
          )),
          const SizedBox(height: 2),
          Text(t.range, style: GoogleFonts.rubik(color: AppColors.k5e5e5e, fontSize: 11.5, height: 1.35)),
          if (t.detail != null) ...[
            const SizedBox(height: 2),
            Text(t.detail!, style: GoogleFonts.rubik(color: AppColors.k8f8e94, fontSize: 11)),
          ],
        ],
      )),
    ]),
  );
}

/// 弹层底部通栏按钮（实心青色 / 浅灰）。
Widget ringSheetButton(String label, {required VoidCallback? onPressed, bool filled = true}) {
  return MaterialButton(
    onPressed: onPressed,
    elevation: 0,
    height: 42,
    minWidth: double.infinity,
    color: filled ? AppColors.k0cbcc5 : AppColors.kf4f4f4,
    disabledColor: AppColors.k0cbcc5.withOpacity(0.4),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(21)),
    child: Text(label, style: GoogleFonts.rubik(
      color: filled ? Colors.white : AppColors.k5e5e5e,
      fontSize: 14,
      fontWeight: FontWeight.w600,
    )),
  );
}
