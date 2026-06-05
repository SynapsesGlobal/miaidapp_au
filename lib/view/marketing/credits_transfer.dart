import 'dart:convert';

import 'package:email_validator/email_validator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

import '../../api_utils/api_provider.dart';
import '../../api_utils/consts.dart';
import '../../api_utils/http_exception.dart';
import '../../component/nav_bar_icons.dart';
import '../../config/app_colors.dart';
import '../../generated/l10n.dart';
import '../../utils/configure_dependencies.dart';

class CreditsTransfer extends StatefulWidget {
  const CreditsTransfer({super.key});

  @override
  State<CreditsTransfer> createState() => _CreditsTransferState();
}

class _CreditsTransferState extends State<CreditsTransfer> {
  late int credits = 0;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final formKey = GlobalKey<FormState>();
  var loaded = false;

  @override
  void initState() {
    _getCreditPoints();
    super.initState();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _getCreditPoints() async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'x-api-key': Consts.marketingApiKey,
    };

    await EasyLoading.show(
      status: 'Loading',
      maskType: EasyLoadingMaskType.black,
    );

    try {
      final api = getIt<ApiProvider>();
      final url = Uri.parse(Consts.marketingApiHost+'/credits/total').replace(queryParameters: {
        'userId': api.userProvider.user!.id.toString(),
      });
      final response = await http.get(url, headers: headers);

      await EasyLoading.dismiss();

      if (response.statusCode == 200) {
        var responseData = jsonDecode(response.body);
        setState(() {
          credits = int.parse(responseData['credit'].toString());
          loaded = true;
        });
      } else {
        await EasyLoading.dismiss();
        await HttpExceptionNotifyUser.showInfo(S.of(context).somethingWentWrong);
      }
    } catch (e) {
      print(e.toString());
      await EasyLoading.dismiss();
    }
  }

  Future<void> _transferCredit() async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'x-api-key': Consts.marketingApiKey,
    };

    await EasyLoading.show(
      status: 'Loading',
      maskType: EasyLoadingMaskType.black,
    );

    try {
      final api = getIt<ApiProvider>();
      final url = Uri.parse(Consts.marketingApiHost+'/credits/transfer').replace(queryParameters: {
        'userId': api.userProvider.user!.id.toString(),
        'email': _emailController.text,
        'quantity': _quantityController.text
      });
      final response = await http.post(url, headers: headers);

      await EasyLoading.dismiss();
      var responseData = jsonDecode(response.body);
      await HttpExceptionNotifyUser.showInfo(responseData['message']);

      if (response.statusCode == 200) {
        setState(() {
          credits = int.parse(responseData['remain_credit']);
          _emailController.text = '';
          _quantityController.text = '';
        });
      }
    } catch (e) {
      print(e.toString());
      await EasyLoading.dismiss();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        elevation: 0,
        backgroundColor: AppColors.kffffff,
        centerTitle: true,
        title: Text(S.of(context).credit_transfer, style: GoogleFonts.rubik(
          color: AppColors.k010101,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),),
        leading: Builder(
          builder: (BuildContext context) => InkWell(
            onTap: () => Navigator.pop(context, true),
            child: navBarIcon(iconAssetName: 'ic_nb_back.png'),
          ),
        ),
      ),
      body: loaded ? Padding(
        padding: EdgeInsets.all(20),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                alignment: Alignment.center,
                padding: EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(5)
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(S.of(context).available_credit, style: GoogleFonts.rubik(
                    color: AppColors.k0cbcc5,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),),
                  Text(credits.toString(), style: GoogleFonts.rubik(
                    color: AppColors.k0cbcc5,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),),
                ],),
              ),
              SizedBox(height: 10,),
              TextFormField(
                controller: _emailController,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return S.of(context).entEmail;
                  }
                  if (!EmailValidator.validate(value.trim())) {
                    return S.of(context).entVEmain;
                  }
                  return null;
                },
                decoration: InputDecoration(
                  hintText: S.of(context).transfer_caption,
                  hintStyle: TextStyle(
                    color: AppColors.kb1b1b1,
                    fontSize: 14,
                  ),
                  contentPadding: EdgeInsets.only(left: 16, top: 5, bottom: 5,),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: AppColors.k010101,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: AppColors.kb1b1b1,
                      width: 0.5,
                    ),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: AppColors.kfa0020,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: AppColors.kfa0020,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  prefixIcon: Icon(Icons.email, color: Colors.grey, size: 16,)
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              SizedBox(height: 10,),
              TextFormField(
                controller: _quantityController,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return S.of(context).transfer_amount;
                  }
                  if (int.parse(value.trim().toString()) > int.parse(credits.toString())) {
                    return S.of(context).transfer_amount_invalid+credits.toString();
                  }
                  return null;
                },
                decoration: InputDecoration(
                  hintText: S.of(context).transfer_amount,
                  hintStyle: TextStyle(
                    color: AppColors.kb1b1b1,
                    fontSize: 14,
                  ),
                  contentPadding: EdgeInsets.only(left: 16, top: 5, bottom: 5,),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: AppColors.k010101,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: AppColors.kb1b1b1,
                      width: 0.5,
                    ),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: AppColors.kfa0020,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: AppColors.kfa0020,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  prefixIcon: Icon(Icons.confirmation_num, color: Colors.grey, size: 16,)
                ),
                keyboardType: TextInputType.number,
              ),
              SizedBox(height: 20,),
              MaterialButton(
                onPressed: int.parse(credits.toString()) > 0 ? () {
                  if (formKey.currentState?.validate() ?? false) {
                    showAlertDialog(context);
                  }
                } : null,
                disabledColor: Colors.black12,
                disabledTextColor: AppColors.k010101,
                minWidth: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                color: AppColors.k0cbcc5,
                child: Text(S.of(context).confirm, style: GoogleFonts.rubik(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                )),
              )
            ],
          ),
        ),
      ) : Offstage()
    );
  }

  void showAlertDialog(BuildContext context) {
    Widget okButton = Padding(
      padding: EdgeInsets.only(left: 64.5, right: 63.5, bottom: 24.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
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
                  offset: Offset(0.0, 4,),
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
              onPressed: () => Navigator.pop(context),
              child: Text(S.of(context).no, style: GoogleFonts.rubik(
                color: AppColors.kffffff,
                fontSize: 14,
              ),),
            ),
          ),
          Center(child: TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(S.of(context).yes, style: GoogleFonts.rubik(
              color: AppColors.k0cbcc5,
              fontSize: 14,
            ),),
          ),),
        ],
      ),
    );
    var alert = AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      title: Text(
        S.of(context).credit_transfer,
        textAlign: TextAlign.center,
        style: GoogleFonts.rubik(
          color: AppColors.k010101,
          fontWeight: FontWeight.w600,
          fontSize: 16
        ),
      ),
      content: Text(
        S.of(context).transfer_confirmation,
        textAlign: TextAlign.center,
        style: GoogleFonts.rubik(
          fontSize: 13,
        ),
      ),
      actions: [okButton],
    );

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return alert;
      }
    ).then((value) async {
      if (value ?? false) {
        await _transferCredit();
      }
    });
  }
}
