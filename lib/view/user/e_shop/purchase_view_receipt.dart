import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:gallery_saver/gallery_saver.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:injectable/injectable.dart';
import 'package:intl/intl.dart';
import 'package:miaid/api_utils/api_provider.dart';
import 'package:miaid/component/nav_bar_icons.dart';
import 'package:miaid/component/progress_indicator.dart';
import 'package:miaid/config/app_colors.dart';
import 'package:miaid/generated/l10n.dart';
import 'package:miaid/store/app/app_settings.dart';
import 'package:miaid/store/e_shop/purchases_store.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share/share.dart';
import 'package:tap_debouncer/tap_debouncer.dart';
import 'package:screenshot/screenshot.dart';

class PurchaseViewReceiptParams {
  final int orderId;
  final String currency;
  PurchaseViewReceiptParams(
    this.orderId,
    this.currency,
  );
}

@injectable
class PurchaseViewReceiptServices {
  PurchaseViewReceiptServices(this.api, this.store, this.appSettings);

  final ApiProvider api;
  final PurchasesStore store;
  final AppSettings appSettings;
}

@injectable
class PurchaseViewReceipt extends StatefulWidget {
  PurchaseViewReceipt({
    @factoryParam this.params,
    required this.services,
  }) : super();

  final PurchaseViewReceiptParams? params;
  final PurchaseViewReceiptServices services;

  @override
  _PurchaseViewReceiptState createState() => _PurchaseViewReceiptState();
}

class _PurchaseViewReceiptState extends State<PurchaseViewReceipt> {
  late PurchasesStore purchaseViewReceiptStore;
  ScreenshotController _screenshotController = ScreenshotController();
  @override
  void initState() {
    super.initState();
    purchaseViewReceiptStore = widget.services.store;
    purchaseViewReceiptStore.getOrderData(
        widget.services.api, widget.params!.orderId);
  }

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
                TapDebouncer(
                  onTap: () async {
                    try {
                      // taking screenshot and then saving
                      var capturedSC = await _screenshotController.capture();
                      if (capturedSC != null) {
                        final result =
                            await ImageGallerySaver.saveImage(capturedSC);


                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Image downloaded'),
                          ),
                        );
                      }
                    } catch (e) {

                    }
                  },
                  builder: (context, onTap) {
                    return InkWell(
                      onTap: onTap,
                      child: navBarIcon(
                          iconAssetName: 'ic_nb_viewreciept_print.png'),
                    );
                  },
                ),
                SizedBox(
                  width: 20,
                ),
                TapDebouncer(
                  onTap: () async {
                    try {
                      // taking screenshot and then saving
                      final directory =
                          (await getApplicationDocumentsDirectory())
                              .path; //from path_provide package
                      var path = '$directory';
                      await _screenshotController.captureAndSave(
                          path, //set path where screenshot will be saved
                          fileName: 'screenshot.png');
                      var screenshotPath = path + '/screenshot.png';

                      await Share.shareFiles(
                        [screenshotPath],
                        subject: 'Receipt',
                      );
                    } catch (e) {
                    }
                  },
                  builder:
                      (BuildContext context, Future<void> Function()? onTap) {
                    return GestureDetector(
                      onTap: onTap,
                      child: InkWell(
                        child: navBarIcon(
                            iconAssetName: 'ic_nb_viewreciept_share.png'),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
      body: Observer(builder: (context) {
        return purchaseViewReceiptStore.isLoading
            ? Container(
                height: MediaQuery.of(context).size.height,
                child: Align(
                  alignment: Alignment.center,
                  child: progressIndicator(),
                ),
              )
            : Screenshot(
                controller: _screenshotController,
                child: SingleChildScrollView(
                  child: Container(
                    color: Colors.white,
                    child: Container(
                      decoration: BoxDecoration(
                          border: Border.all(
                            color: Color.fromRGBO(0, 100, 244, 1),
                          ),
                          borderRadius: BorderRadius.circular(10)),
                      margin: EdgeInsets.all(10),
                      padding: EdgeInsets.only(bottom: 15),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: EdgeInsets.only(
                                top: 5, left: 17, right: 17, bottom: 5),
                            decoration: BoxDecoration(
                              color: Color.fromRGBO(90, 177, 255, 0.1),
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(10),
                                topRight: Radius.circular(10),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      S.of(context).purchaseReceipt,
                                      style: GoogleFonts.rubik(fontSize: 12),
                                    ),
                                    Image.asset(
                                        'assets/images/logo_reciept.png'),
                                  ],
                                ),
                                Text(
                                  S.of(context).receiptMessage,
                                  style: GoogleFonts.rubik(fontSize: 14),
                                ),
                                SizedBox(
                                  height: 10,
                                ),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    RichText(
                                      textAlign: TextAlign.left,
                                      text: TextSpan(
                                        style: GoogleFonts.rubik(
                                          color: AppColors.k5e5e5e,
                                          fontSize: 12,
                                        ),
                                        children: [
                                          TextSpan(
                                              text:
                                                  '${S.of(context).orderNumber} '),
                                          TextSpan(
                                            text: purchaseViewReceiptStore
                                                .orderDetails?.id
                                                .toString(),
                                            style: GoogleFonts.rubik(
                                              color: AppColors.k010101,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      DateFormat('dd MMM yyyy hh:mm aaa')
                                          .format(
                                        DateTime.parse(purchaseViewReceiptStore
                                                .orderDetails?.createdAt ??
                                            ''),
                                      ),
                                      style: GoogleFonts.rubik(
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(
                                  height: 15,
                                ),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      S.of(context).totalOrder,
                                      style: GoogleFonts.rubik(fontSize: 20),
                                    ),
                                    RichText(
                                      textAlign: TextAlign.left,
                                      text: TextSpan(
                                        style: GoogleFonts.rubik(
                                          color: AppColors.k5e5e5e,
                                          fontSize: 14,
                                        ),
                                        children: [
                                          TextSpan(
                                              text:
                                                  '${widget.params?.currency} '),
                                          TextSpan(
                                            text: purchaseViewReceiptStore
                                                .orderDetails?.orderTotal
                                                .toString(),
                                            style: GoogleFonts.rubik(
                                              color: AppColors.k010101,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 18,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  ],
                                ),
                              ],
                            ),
                          ),
                          SizedBox(
                            height: 15,
                          ),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: NeverScrollableScrollPhysics(),
                            itemCount: purchaseViewReceiptStore
                                .orderDetails!.products!.length,
                            itemBuilder: (BuildContext context, index) =>
                                ListTile(
                              leading: CircleAvatar(
                                radius: 15,
                                backgroundColor:
                                    Color.fromRGBO(90, 177, 255, 0.1),
                                child: Text(
                                  '${purchaseViewReceiptStore.orderDetails!.products![index].pivot!.qty}x',
                                  style: GoogleFonts.rubik(color: Colors.black),
                                ),
                              ),
                              title: Text(purchaseViewReceiptStore
                                  .orderDetails!.products![index].name!),
                              trailing: Text(
                                  '${widget.params?.currency} ${purchaseViewReceiptStore.orderDetails!.products![index].unitPrice}'),
                            ),
                          ),
                          Divider(
                            endIndent: 25,
                            indent: 25,
                          ),
                          Container(
                            padding:
                                EdgeInsets.only(left: 20, right: 20, top: 10),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      S.of(context).subTotal,
                                      style: GoogleFonts.rubik(fontSize: 12),
                                    ),
                                    Text(
                                      '${widget.params?.currency} ${purchaseViewReceiptStore.orderDetails?.subTotal}',
                                      style: GoogleFonts.rubik(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                                SizedBox(
                                  height: 5,
                                ),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      S.of(context).deliveryFees,
                                      style: GoogleFonts.rubik(fontSize: 12),
                                    ),
                                    Text(
                                      '${widget.params?.currency} ${purchaseViewReceiptStore.orderDetails?.deliveryFee}',
                                      style: GoogleFonts.rubik(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                                SizedBox(
                                  height: 5,
                                ),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(S.of(context).orderTotal,
                                        style: GoogleFonts.rubik(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500)),
                                    Text(
                                      '${widget.params?.currency} ${purchaseViewReceiptStore.orderDetails?.orderTotal}',
                                      style: GoogleFonts.rubik(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500),
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
      }),
    );
  }
}
