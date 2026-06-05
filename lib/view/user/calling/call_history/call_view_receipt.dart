import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:injectable/injectable.dart';
import 'package:miaid/api_utils/user_provider.dart';
import 'package:miaid/component/nav_bar_icons.dart';
import 'package:miaid/config/app_colors.dart';
import 'package:miaid/generated/l10n.dart';
import 'package:miaid/generated_api_code/api_client.swagger.dart';
import 'package:miaid/payment/additional_services.dart';
import 'package:miaid/store/user/calling/call_history/call_view_receipt_store.dart';
import 'package:miaid/utils/date_utils.dart';

class CallViewReceiptParams {
  const CallViewReceiptParams({
    this.key,
    this.user,
    required this.call,
  });

  final UserProvider? user;
  final Key? key;
  final Call call;
}

@injectable
class CallViewReceiptServices {
  final CallViewReceiptStore store;

  CallViewReceiptServices(this.store);
}

@injectable
class CallViewReceipt extends StatefulWidget {
  CallViewReceipt({
    @factoryParam this.params,
    required this.services,
  }) : super(key: params?.key);

  final CallViewReceiptParams? params;
  final CallViewReceiptServices services;

  @override
  _CallViewReceiptState createState() => _CallViewReceiptState();
}

class _CallViewReceiptState extends State<CallViewReceipt> {
  final key = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final store = widget.services.store;
    final call = widget.params!.call;
    final user = widget.params!.user;

    return RepaintBoundary(
      key: key,
      child: Scaffold(
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
            S.of(context).viewReceipt,
            style: GoogleFonts.rubik(
              color: AppColors.k010101,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          actions: [
            Padding(
              padding: EdgeInsets.only(
                right: 12,
              ),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => store.printReceipt(key),
                    child: navBarIcon(
                        iconAssetName: 'ic_nb_viewreciept_print.png'),
                  ),
                  SizedBox(
                    width: 20,
                  ),
                  InkWell(
                    onTap: () => store.shareReceipt(key),
                    child: navBarIcon(
                        iconAssetName: 'ic_nb_viewreciept_share.png'),
                  ),
                ],
              ),
            ),
          ],
        ),
        body: SingleChildScrollView(
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: Color.fromRGBO(0, 100, 244, 1),
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            margin: EdgeInsets.all(10),
            padding: EdgeInsets.only(bottom: 15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      EdgeInsets.only(top: 5, left: 17, right: 17, bottom: 5),
                  decoration: BoxDecoration(
                    color: Color.fromRGBO(90, 177, 255, 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            S.of(context).appointmentReceipt,
                            style: GoogleFonts.rubik(fontSize: 12),
                          ),
                          Image.asset('assets/images/logo_reciept.png'),
                        ],
                      ),
                      Text(
                        S.of(context).doctorName(
                              call.doctor?.user?.fullName ?? '',
                            ),
                        style: GoogleFonts.rubik(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: AppColors.k010101,
                        ),
                      ),
                      SizedBox(
                        height: 10,
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          RichText(
                            textAlign: TextAlign.left,
                            text: TextSpan(
                              style: GoogleFonts.rubik(
                                  color: AppColors.k5e5e5e,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w300),
                              children: [
                                TextSpan(
                                    text: S.of(context).providerNumber + ' '),
                                TextSpan(
                                  text: call.doctor?.providerNumber ?? '',
                                  style: GoogleFonts.rubik(
                                    color: AppColors.k010101,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            formatDate(
                                DateTime.parse(call.endedAt ?? '').toLocal()),
                            style: GoogleFonts.rubik(
                              fontSize: 10,
                              fontWeight: FontWeight.w300,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(
                        height: 10,
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            S.of(context).patientName,
                            style: GoogleFonts.rubik(
                              fontSize: 14,
                              fontWeight: FontWeight.w300,
                            ),
                          ),
                          Text(
                            call.customer?.user?.fullName ?? '',
                            style: GoogleFonts.rubik(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      if (call.customer?.medicareNumber != null)
                        SizedBox(
                          height: 10,
                        ),
                      if (call.customer?.medicareNumber != null)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              S.of(context).medicareNumber,
                              style: GoogleFonts.rubik(
                                fontSize: 14,
                                fontWeight: FontWeight.w300,
                              ),
                            ),
                            Text(
                              call.customer?.medicareNumber ?? '',
                              style: GoogleFonts.rubik(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 15,
                ),
                Container(
                  padding: EdgeInsets.only(left: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        S.of(context).videoConsult,
                        style: GoogleFonts.rubik(
                            fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                      SizedBox(
                        height: 10,
                      ),
                      Text(
                        S.of(context).itemNumber(91804),
                        style: GoogleFonts.rubik(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 15,
                ),
                Divider(
                  endIndent: 25,
                  indent: 25,
                ),
                Container(
                  padding: EdgeInsets.only(left: 20, right: 20, top: 10),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            S.of(context).subTotal,
                            style: GoogleFonts.rubik(fontSize: 12),
                          ),
                          Text(
                            total(call, user!),
                            style: GoogleFonts.rubik(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(
                        height: 5,
                      ),
                      SizedBox(
                        height: 5,
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            S.of(context).total,
                            style: GoogleFonts.rubik(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            total(call, user),
                            style: GoogleFonts.rubik(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String total(Call call, UserProvider user) {
    if (user.isCustomer) {
      if (call.payment == null) {
        return '0';
      }

      return call.payment!.currency!.currency! +
          ' ' +
          amountDisplay(call.payment!.amount!).toString();
    } else if (user.isDoctor) {
      // FIXME: When consultation fee is not available, set default amount to AUD 79 from API
      if (call.doctor?.doctorCountry?.consultationFee?.consultationFee !=
              null &&
          call.doctor?.doctorCountry?.currency != null) {
        return call.doctor!.doctorCountry!.currency! +
            ' ' +
            call.doctor!.doctorCountry!.consultationFee!.consultationFee!
                .toString();
      }

      return "AUD 79.00";
    } else {
      return "0";
    }
  }
}
