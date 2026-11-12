import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:miaid/component/nav_bar_icons.dart';
import 'package:miaid/config/app_colors.dart';

/// 智能戒指「家人共享 / 走势 / 看板」几个页面共用的小组件，风格沿用智能戒指页面。

AppBar familyAlertAppBar(BuildContext context, String title, {List<Widget>? actions}) {
  return AppBar(
    backgroundColor: Colors.white,
    elevation: 0,
    leading: InkWell(
      onTap: () => Navigator.pop(context),
      child: navBarIcon(iconAssetName: 'ic_nb_back.png'),
    ),
    title: Text(title, style: GoogleFonts.rubik(
      color: AppColors.k010101,
      fontSize: 18,
      fontWeight: FontWeight.w600,
    )),
    centerTitle: true,
    actions: actions,
  );
}

Widget familySectionTitle(String title, {String? subtitle}) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: GoogleFonts.rubik(color: AppColors.k010101, fontSize: 15, fontWeight: FontWeight.w600)),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(subtitle, style: GoogleFonts.rubik(color: AppColors.k8f8e94, fontSize: 12)),
        ],
      ],
    ),
  );
}

Widget familyCard({required Widget child, EdgeInsets padding = const EdgeInsets.all(14)}) {
  return Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3))],
    ),
    padding: padding,
    child: child,
  );
}

Widget familyIconTile(IconData icon, Color color, {double size = 40}) {
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(size * 0.32)),
    child: Icon(icon, color: color, size: size * 0.52),
  );
}

/// 圆形头像：取名字首字。
Widget familyAvatar(String name, Color color, {double size = 40}) {
  final initial = name.isEmpty ? '?' : name.characters.first.toUpperCase();
  return Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(shape: BoxShape.circle, color: color.withOpacity(0.14)),
    child: Text(initial, style: GoogleFonts.rubik(color: color, fontSize: size * 0.42, fontWeight: FontWeight.w600)),
  );
}

Widget familyChip(String text, Color color) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
    child: Text(text, style: GoogleFonts.rubik(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
  );
}

Widget familyFilledButton(String label, {required VoidCallback? onPressed, IconData? icon, Color? color}) {
  final c = color ?? AppColors.k0cbcc5;
  return MaterialButton(
    onPressed: onPressed,
    elevation: 0,
    height: 46,
    minWidth: double.infinity,
    color: c,
    disabledColor: c.withOpacity(0.4),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(23)),
    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      if (icon != null) ...[Icon(icon, color: Colors.white, size: 18), const SizedBox(width: 8)],
      Text(label, style: GoogleFonts.rubik(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
    ]),
  );
}

Widget familyOutlinedButton(String label, {required VoidCallback? onPressed, IconData? icon}) {
  return MaterialButton(
    onPressed: onPressed,
    elevation: 0,
    height: 46,
    minWidth: double.infinity,
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(23),
      side: BorderSide(color: AppColors.k0cbcc5, width: 1.2),
    ),
    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      if (icon != null) ...[Icon(icon, color: AppColors.k0cbcc5, size: 18), const SizedBox(width: 8)],
      Text(label, style: GoogleFonts.rubik(color: AppColors.k0cbcc5, fontSize: 14, fontWeight: FontWeight.w600)),
    ]),
  );
}
