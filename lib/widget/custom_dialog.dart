import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:miaid/config/app_colors.dart';

class CustomDialog extends StatelessWidget {
  final String title;
  final String content;
  final String buttonText;
  final bool showCancel;
  final Function onPressed;

  CustomDialog({
    required this.title,
    required this.content,
    required this.buttonText,
    required this.showCancel,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    Widget okButton = Padding(
      padding: EdgeInsets.only(left: 64.5, right: 63.5, bottom: 24.5),
      child: Container(
        width: MediaQuery.of(context).size.width,
        height: 36,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: AppColors.k0cbcc5.withOpacity(0.2),
              blurRadius: 10.0,
              spreadRadius: 0.0, //extend the shadow
              offset: Offset(
                0.0, // Move to right 10  horizontally
                4, // Move to bottom 10 Vertically
              ),
            ),
          ],
        ),
        child: TextButton(
          style: ButtonStyle(
            backgroundColor: MaterialStateProperty.all(AppColors.k0cbcc5),
            shape: MaterialStateProperty.all(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(9),
              ),
            ),
          ),
          onPressed: () {
            Navigator.of(context).pop(); // 关闭弹窗
            onPressed();
          },
          child: Text(
            buttonText,
            style: GoogleFonts.rubik(
              color: AppColors.kffffff,
              fontSize: 17,
            ),
          ),
        ),
      ),
    );

    Widget cancelButton = TextButton(
      onPressed: () {
        Navigator.of(context).pop(); // 关闭弹窗
      },
      child: Text('Cancel'),
    );

    var alert = AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      title: Text(
        title,
        textAlign: TextAlign.center,
        style: GoogleFonts.rubik(
          fontWeight: FontWeight.w500,
          fontSize: 17,
          color: AppColors.k010101,
        ),
      ),
      content: Text(
        content,
        textAlign: TextAlign.center,
        style: GoogleFonts.rubik(
          fontSize: 13,
          color: AppColors.k010101,
        ),
      ),
      actions: [showCancel ? cancelButton : Container(), okButton],
    );

    return alert;
  }
}
