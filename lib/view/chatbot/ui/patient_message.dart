import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../config/app_colors.dart';

class PatientMessage extends StatelessWidget {
  final dynamic message;
  const PatientMessage({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
          child: Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.k0cbcc5,
              borderRadius: BorderRadius.circular(10)
            ),
            child: Text(message['content'], style: GoogleFonts.rubik(
              color: Colors.white,
              fontSize: 15,
            ),),
          ),
        ),
        SizedBox(width: 10,),
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: AppColors.k0cbcc5,
            borderRadius: BorderRadius.circular(5)
          ),
          child: Icon(CupertinoIcons.person, color: Colors.white,),
        )
      ],
    );
  }
}
