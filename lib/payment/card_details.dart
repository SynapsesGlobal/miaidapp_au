import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:miaid/component/nav_bar_icons.dart';
import 'package:miaid/config/app_colors.dart';
import 'package:miaid/generated/l10n.dart';
import 'package:miaid/utils/card_utils.dart';
import 'package:miaid/utils/configure_dependencies.dart';
import 'package:miaid/view/user/e_shop/purchase.dart';

enum CardType {
  Master,
  Visa,
  Verve,
  Discover,
  AmericanExpress,
  DinersClub,
  Jcb,
  Others,
  Invalid
}

class CardDetails extends StatefulWidget {
  @override
  _CardDetailsState createState() => _CardDetailsState();
}

class _CardDetailsState extends State<CardDetails> {
  late int month;
  late int year;
  late CardType cardType;

  var maskFormatter = MaskTextInputFormatter(
      mask: '#### #### #### ####', filter: {'#': RegExp(r'[0-9]')});
  var expiryMask =
      MaskTextInputFormatter(mask: '##/##', filter: {'#': RegExp(r'[0-9]')});
  var cvvMask =
      MaskTextInputFormatter(mask: '###', filter: {'#': RegExp(r'[0-9]')});
  TextEditingController cardNumber = TextEditingController();
  TextEditingController cardHolderName = TextEditingController();
  TextEditingController cvv = TextEditingController();
  TextEditingController expiry = TextEditingController();
  final formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: InkWell(
          onTap: () {
            Navigator.pop(context);
          },
          child: navBarIcon(iconAssetName: 'ic_nb_back.png'),
        ),
        centerTitle: true,
        title: Text(
          S.of(context).addCardDetails,
          style: GoogleFonts.rubik(
            color: AppColors.k010101,
            fontSize: 15,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: formKey,
          child: ListView(
            children: [
              Text(
                S.of(context).cardName,
                style: GoogleFonts.rubik(
                  color: cardNumber.text.trim().isNotEmpty
                      ? AppColors.kb1b1b1
                      : AppColors.k010101,
                  fontSize: 12,
                  letterSpacing: 0.4,
                ),
              ),
              SizedBox(
                height: 10,
              ),
              TextFormField(
                controller: cardNumber,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return S.of(context).cardNumberMessage;
                  }
                  if (value.length < 8) {
                    return S.of(context).cardNumberValidate;
                  } else {
                    return null;
                  }
                },
                inputFormatters: [
                  maskFormatter,
                ],
                onChanged: (value) {
                  setState(() {
                    cardType = validateCardType(value);
                  });
                },
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  contentPadding: EdgeInsets.only(
                    left: 16,
                    top: 5,
                    bottom: 5,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: AppColors.k010101,
                      width: 0.5,
                    ),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: AppColors.kb1b1b1,
                      width: 0.5,
                    ),
                  ),
                  hintText: 'EX: 1234 5678 8901 234',
                  hintStyle: GoogleFonts.rubik(
                    color: AppColors.kb1b1b1,
                    fontSize: 14,
                  ),
                  suffixIcon: getCardIcon(cardType),
                ),
              ),
              SizedBox(
                height: 25,
              ),
              Text(
                S.of(context).cardName,
                style: GoogleFonts.rubik(
                  color: cardHolderName.text.trim().isNotEmpty
                      ? AppColors.kb1b1b1
                      : AppColors.k010101,
                  fontSize: 12,
                  letterSpacing: 0.4,
                ),
              ),
              SizedBox(
                height: 10,
              ),
              TextFormField(
                controller: cardHolderName,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return S.of(context).cardNameMessage;
                  } else {
                    return null;
                  }
                },
                keyboardType: TextInputType.text,
                onChanged: (value) {
                  setState(() {});
                },
                decoration: InputDecoration(
                  contentPadding: EdgeInsets.only(
                    left: 16,
                    top: 5,
                    bottom: 5,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: AppColors.k010101,
                      width: 0.5,
                    ),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: AppColors.kb1b1b1,
                      width: 0.5,
                    ),
                  ),
                  hintText: 'Ex: Kelly Babara',
                  hintStyle: GoogleFonts.rubik(
                    color: AppColors.kb1b1b1,
                    fontSize: 14,
                  ),
                ),
              ),
              SizedBox(
                height: 25,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          S.of(context).expiryDate,
                          style: GoogleFonts.rubik(
                            color: expiry.text.trim().isNotEmpty
                                ? AppColors.kb1b1b1
                                : AppColors.k010101,
                            fontSize: 12,
                            letterSpacing: 0.4,
                          ),
                        ),
                        SizedBox(
                          height: 10,
                        ),
                        TextFormField(
                          controller: expiry,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return S.of(context).cardNumberMessage;
                            }
                            if (value.length != 5) {
                              return S.of(context).expiryValidate;
                            }
                            if (value.contains(RegExp(r'(\/)'))) {
                              var split = value.split(RegExp(r'(\/)'));
                              // ignore: missing_return
                              // The value before the slash is the month while the value to right of
                              // it is the year.
                              month = int.parse(split[0]);
                              year = int.parse(split[1]);
                            } else {
                              // Only the month was entered
                              month =
                                  int.parse(value.substring(0, (value.length)));
                              year =
                                  -1; // Lets use an invalid year intentionally
                            }
                            if ((month < 1) || (month > 12)) {
                              // A valid month is between 1 (January) and 12 (December)
                              return S.of(context).expiryMonth;
                            }
                            if (year == null) {
                              return S.of(context).expiryYear;
                            }
                            return null;
                          },
                          inputFormatters: [
                            expiryMask,
                          ],
                          keyboardType: TextInputType.number,
                          onChanged: (value) {
                            setState(() {});
                          },
                          decoration: InputDecoration(
                            contentPadding: EdgeInsets.only(
                              left: 16,
                              top: 5,
                              bottom: 5,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                color: AppColors.k010101,
                                width: 0.5,
                              ),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                color: AppColors.kb1b1b1,
                                width: 0.5,
                              ),
                            ),
                            hintText: 'MM/YY',
                            hintStyle: GoogleFonts.rubik(
                              color: AppColors.kb1b1b1,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        SizedBox(
                          height: 25,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 19,
                  ),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          S.of(context).cvv,
                          style: GoogleFonts.rubik(
                            color: cvv.text.trim().isNotEmpty
                                ? AppColors.kb1b1b1
                                : AppColors.k010101,
                            fontSize: 12,
                            letterSpacing: 0.4,
                          ),
                        ),
                        SizedBox(
                          height: 10,
                        ),
                        TextFormField(
                          controller: cvv,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return S.of(context).cardNumberMessage;
                            }
                            if (value.length < 3 || value.length > 4) {
                              return S.of(context).cvvValidate;
                            } else {
                              return null;
                            }
                          },
                          inputFormatters: [
                            cvvMask,
                          ],
                          keyboardType: TextInputType.number,
                          onChanged: (value) {
                            setState(() {});
                          },
                          decoration: InputDecoration(
                            contentPadding: EdgeInsets.only(
                              left: 16,
                              top: 5,
                              bottom: 5,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                color: AppColors.k010101,
                                width: 0.5,
                              ),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                color: AppColors.kb1b1b1,
                                width: 0.5,
                              ),
                            ),
                            hintText: 'Ex:123',
                            hintStyle: GoogleFonts.rubik(
                              color: AppColors.kb1b1b1,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        SizedBox(
                          height: 25,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              TextButton(
                style: ButtonStyle(
                    backgroundColor:
                        MaterialStateProperty.all(AppColors.k0cbcc5),
                    padding: MaterialStateProperty.all(
                        EdgeInsets.only(bottom: 15, top: 15)),
                    shape: MaterialStateProperty.all(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9),
                      ),
                    )),
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    paymentConfirmationDialog();
                  }
                },
                child: Text(
                  S.of(context).payAndContinue,
                  style: GoogleFonts.rubik(
                    color: AppColors.kffffff,
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future paymentConfirmationDialog() {
    return showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Center(
              child: Text(
                S.of(context).confirmation,
                style: GoogleFonts.rubik(
                  color: AppColors.k010101,
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'You are about to make payment of \$20.00 for “Additional Video Consultations” Service.',
                  style: GoogleFonts.rubik(
                    color: AppColors.k010101,
                    fontSize: 13,
                    letterSpacing: -0.08,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(
                  height: 30,
                ),
                Container(
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.k0cbcc5.withOpacity(0.2),
                        offset: Offset(
                          0,
                          0.4,
                        ),
                        blurRadius: 10,
                        spreadRadius: 0,
                      )
                    ],
                  ),
                  child: TextButton(
                    style: ButtonStyle(
                      backgroundColor:
                          MaterialStateProperty.all(AppColors.k0cbcc5),
                      shape: MaterialStateProperty.all(
                        RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9),
                        ),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      successDialog();
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(
                        left: 44,
                        right: 44,
                        top: 10,
                        bottom: 8,
                      ),
                      child: Text(
                        S.of(context).confirm,
                        style: GoogleFonts.rubik(
                          color: AppColors.kffffff,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
                TextButton(
                  style: ButtonStyle(
                    shape: MaterialStateProperty.all(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9),
                      ),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    errorDialog();
                  },
                  child: Text(
                    S.of(context).cancel,
                    style: GoogleFonts.rubik(
                      color: AppColors.k0cbcc5,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                )
              ],
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          );
        });
  }

  Future errorDialog() {
    return showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Center(
              child: Text(
                S.of(context).error,
                style: GoogleFonts.rubik(
                  color: AppColors.k010101,
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  S.of(context).errorPaymentMessage,
                  style: GoogleFonts.rubik(
                    color: AppColors.k010101,
                    fontSize: 13,
                    letterSpacing: -0.08,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(
                  height: 30,
                ),
                Container(
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.k0cbcc5.withOpacity(0.2),
                        offset: Offset(
                          0,
                          0.4,
                        ),
                        blurRadius: 10,
                        spreadRadius: 0,
                      )
                    ],
                  ),
                  child: TextButton(
                    style: ButtonStyle(
                      backgroundColor:
                          MaterialStateProperty.all(AppColors.k0cbcc5),
                      shape: MaterialStateProperty.all(
                        RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9),
                        ),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(
                        left: 44,
                        right: 44,
                        top: 10,
                        bottom: 8,
                      ),
                      child: Text(
                        S.of(context).okay,
                        style: GoogleFonts.rubik(
                          color: AppColors.kffffff,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          );
        });
  }

  Future successDialog() {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Center(
            child: Text(
              S.of(context).success,
              style: GoogleFonts.rubik(
                color: AppColors.k010101,
                fontSize: 17,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                S.of(context).successPaymentMessage,
                style: GoogleFonts.rubik(
                  color: AppColors.k010101,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(
                height: 30,
              ),
              Container(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.k0cbcc5.withOpacity(0.2),
                      offset: Offset(
                        0,
                        0.4,
                      ),
                      blurRadius: 10,
                      spreadRadius: 0,
                    )
                  ],
                ),
                child: TextButton(
                  style: ButtonStyle(
                    backgroundColor:
                        MaterialStateProperty.all(AppColors.k0cbcc5),
                    shape: MaterialStateProperty.all(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9),
                      ),
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(context).push(CupertinoPageRoute<void>(
                        builder: (context) => getIt<PurchaseItem>()));
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(
                      left: 44,
                      right: 44,
                      top: 10,
                      bottom: 8,
                    ),
                    child: Text(
                      S.of(context).okay,
                      style: GoogleFonts.rubik(
                        color: AppColors.kffffff,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        );
      },
    );
  }
}
