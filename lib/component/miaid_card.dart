import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:miaid/config/app_colors.dart';

Widget miAidCard(Widget child) {
  return Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(15),
      boxShadow: [
        BoxShadow(
          color: AppColors.k003f51.withOpacity(0.19),
          offset: Offset(
            0,
            4,
          ),
          blurRadius: 15,
          spreadRadius: 0,
        )
      ],
    ),
    child: child,
  );
}

Widget activeSubscriptionCard(Widget child) {
  return Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(15),
      color: AppColors.k0cbcc5,
      boxShadow: [
        BoxShadow(
          color: AppColors.k003f51.withOpacity(0.15),
          blurRadius: 15.0,
          spreadRadius: 0.0, //extend the shadow
          offset: Offset(
            0.0, // Move to right 10  horizontally
            4, // Move to bottom 10 Vertically
          ),
        ),
      ],
    ),
    child: child,
  );
}

Widget radiobuttonContainer({required Widget child}) {
  return Column(
    children: [
      Container(
        margin: EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: AppColors.kffffff,
          boxShadow: [
            BoxShadow(
              color: AppColors.k003f51.withOpacity(0.1),
              offset: Offset(
                0,
                4,
              ),
              blurRadius: 15,
              spreadRadius: 0,
            )
          ],
        ),
        child: child,
      ),
      
    ],
  );
}

Widget buttonContainer(Widget child) {
  return Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(4),
      color: AppColors.kffffff,
      boxShadow: [
        BoxShadow(
          color: AppColors.k003f51.withOpacity(0.1),
          offset: Offset(
            0,
            4,
          ),
          blurRadius: 15,
          spreadRadius: 0,
        )
      ],
    ),
    child: child,
  );
}
