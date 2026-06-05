import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:injectable/injectable.dart';
import 'package:intl/intl.dart';
import 'package:miaid/api_utils/api_provider.dart';
import 'package:miaid/component/nav_bar_icons.dart';
import 'package:miaid/component/progress_indicator.dart';
import 'package:miaid/config/app_colors.dart';
import 'package:miaid/generated/l10n.dart';
import 'package:miaid/generated_api_code/api_client.swagger.dart';
import 'package:miaid/payment/e_shop_payment_bottom_sheet.dart';
import 'package:miaid/store/app/app_settings.dart';
import 'package:miaid/store/e_shop/purchases_store.dart';
import 'package:miaid/utils/configure_dependencies.dart';
import 'package:miaid/view/user/e_shop/purchase_view_receipt.dart';

class PurchaseItemParams {
  const PurchaseItemParams(this.key);

  final Key key;
}

@injectable
class PurchaseItemServices {
  PurchaseItemServices(this.api, this.store, this.appSettings);

  final ApiProvider api;
  final PurchasesStore store;
  final AppSettings appSettings;
}

@injectable
class PurchaseItem extends StatefulWidget {
  PurchaseItem({
    @factoryParam this.params,
    required this.services,
  }) : super(key: params?.key);

  final PurchaseItemParams? params;
  final PurchaseItemServices services;

  @override
  _PurchaseItemState createState() => _PurchaseItemState();
}

class _PurchaseItemState extends State<PurchaseItem> {
  late PurchasesStore purchasesStore;

  @override
  void initState() {
    super.initState();
    purchasesStore = widget.services.store;
    purchasesStore.getOrders(widget.services.api);
  }

  // bool _expand = false;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: InkWell(
          onTap: () {
            widget.services.store.unExpandEveryItem();
            Navigator.pop(context);
          },
          child: navBarIcon(iconAssetName: 'ic_nb_back.png'),
        ),
        centerTitle: true,
        title: Text(
          S.of(context).purchases,
          style: GoogleFonts.rubik(
            color: AppColors.k010101,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Observer(
          builder: (context) {
            return purchasesStore.orderList.isNotEmpty
                ? _purchasesList()
                : purchasesStore.isLoading
                    ? Align(
                        alignment: Alignment.center,
                        child: progressIndicator(),
                      )
                    : Center(
                        child: Text(S.of(context).noPastPurchases),
                      );
          },
        ),
      ),
    );
  }

  Widget _purchasesList() {
    return Observer(builder: (context) {
      var expansionItems = <ExpansionPanel>[];
      for (var i = 0; i < purchasesStore.orderList.length; i++) {
        var order = purchasesStore.orderList[i];
        var item = ExpansionPanel(
          isExpanded: purchasesStore.isExpandedList[i],
          canTapOnHeader: true,
          headerBuilder: (context, isExpanded) {
            return Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 10,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.pharmacy?.name ?? '',
                        style: GoogleFonts.rubik(
                          color: AppColors.k010101,
                          fontSize: 18,
                        ),
                      ),
                      SizedBox(height: 8),
                      RichText(
                        textAlign: TextAlign.left,
                        text: TextSpan(
                          style: GoogleFonts.rubik(
                            color: AppColors.k5e5e5e,
                            fontSize: 14,
                          ),
                          children: [
                            TextSpan(text: '${S.of(context).orderNumber}\n'),
                            TextSpan(
                              text: order.id.toString(),
                              style: GoogleFonts.rubik(
                                color: AppColors.k010101,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 8),
                      RichText(
                        textAlign: TextAlign.left,
                        text: TextSpan(
                          style: GoogleFonts.rubik(
                            color: AppColors.k5e5e5e,
                            fontSize: 14,
                          ),
                          children: [
                            TextSpan(text: '${S.of(context).orderDate}\n'),
                            TextSpan(
                              text: DateFormat('dd MMM yyyy hh:mm aaa').format(
                                DateTime.parse(order.createdAt ?? ''),
                              ),
                              style: GoogleFonts.rubik(
                                color: AppColors.k010101,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      )
                    ],
                  ),
                ],
              ),
            );
          },
          body: getItems(i),
        );
        expansionItems.add(item);
      }

      return Container(
        child: ExpansionPanelList(
          children: expansionItems,
          dividerColor: Colors.grey.shade300,
          expansionCallback: (i, expand) {
            setState(() {
              purchasesStore.updateExpansion(i, expand);
            });
          },
        ),
      );
    });

    /* return ListView.builder(
      itemCount: purchasesStore.orderList.length,
      shrinkWrap: true,
      physics: ClampingScrollPhysics(),
      itemBuilder: (BuildContext context, index) => purchaseCard(index),
    ); */
  }

  Widget getItems(int i) {
    return Observer(builder: (context) {
      var order = purchasesStore.orderList[i];

      return Column(
        children: [
          ListView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            itemCount: order.products?.length,
            itemBuilder: (BuildContext context, index) {
              var prod = order.products![index];
              return Column(
                children: [
                  Container(
                    color: AppColors.k0cbcc5.withOpacity(0.1),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 15),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Row(
                              mainAxisSize: MainAxisSize.max,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                prod.productImages != null
                                    ? prod.productImages!.isNotEmpty
                                        ? Image.network(
                                            prod.productImages!.first.image!,
                                            height: 70,
                                            width: 70,
                                            errorBuilder: (
                                              context,
                                              exception,
                                              stackTrace,
                                            ) {
                                              return ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                child: Image.asset(
                                                  'assets/images/default_shop_image.png',
                                                  height: 80,
                                                  width: 80,
                                                ),
                                              );
                                            },
                                          )
                                        : Container(
                                            height: 70,
                                            width: 70,
                                            child: Center(
                                              child: Icon(
                                                Icons.local_pharmacy,
                                                size: 50,
                                              ),
                                            ),
                                          )
                                    : Container(
                                        height: 70,
                                        width: 70,
                                        child: Center(
                                          child: Icon(Icons.local_pharmacy,
                                              size: 50),
                                        ),
                                      ),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(
                                      left: 15,
                                      right: 16,
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.max,
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceEvenly,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(bottom: 14),
                                          child: Text(
                                            prod.name!,
                                            textAlign: TextAlign.left,
                                            style: GoogleFonts.rubik(
                                              color: AppColors.k010101,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Container(
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                                color: AppColors.kf4f4f4,
                                              ),
                                              child: Padding(
                                                padding: const EdgeInsets.only(
                                                  left: 7,
                                                  right: 7,
                                                  top: 3,
                                                  bottom: 2,
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                        '${order.pharmacyCurrency} '),
                                                    Text(
                                                      prod.unitPrice.toString(),
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 18,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            Text(order
                                                    .products![index].pivot!.qty
                                                    .toString() +
                                                'x'),
                                          ],
                                        )
                                      ],
                                    ),
                                  ),
                                )
                              ],
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                  divider(),
                ],
              );
            },
          ),
          Container(
            color: AppColors.k0cbcc5.withOpacity(0.1),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 15,
              ),
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
                        '${order.pharmacyCurrency} ${order.subTotal}',
                        style: GoogleFonts.rubik(
                            fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  SizedBox(
                    height: 5,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        S.of(context).deliveryFees,
                        style: GoogleFonts.rubik(fontSize: 12),
                      ),
                      Text(
                        '${order.pharmacyCurrency} ${order.deliveryFee}',
                        style: GoogleFonts.rubik(
                            fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  SizedBox(
                    height: 5,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(S.of(context).orderTotal,
                          style: GoogleFonts.rubik(
                              fontSize: 12, fontWeight: FontWeight.w500)),
                      Text(
                        '${order.pharmacyCurrency} ${order.orderTotal}',
                        style: GoogleFonts.rubik(
                            fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  SizedBox(
                    height: 10,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        style: ButtonStyle(
                          backgroundColor:
                              MaterialStateProperty.all(AppColors.kffffff),
                          shape: MaterialStateProperty.all(
                            RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(9),
                            ),
                          ),
                          side: MaterialStateProperty.all(
                            BorderSide(color: AppColors.k0cbcc5),
                          ),
                          overlayColor: MaterialStateProperty.all(
                              AppColors.k0cbcc5.withOpacity(0.2)),
                        ),
                        onPressed: () {
                          purchasesStore.orderId = order.id ?? 0;

                          Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (context) => getIt<PurchaseViewReceipt>(
                                param1: PurchaseViewReceiptParams(
                                  purchasesStore.orderId,
                                  order.pharmacyCurrency!,
                                ),
                              ),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            S.of(context).viewReceipt,
                            style: GoogleFonts.rubik(
                              color: AppColors.k0cbcc5,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      TextButton(
                        style: ButtonStyle(
                          backgroundColor:
                              MaterialStateProperty.all(AppColors.k0cbcc5),
                          shape: MaterialStateProperty.all(
                            RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(9),
                            ),
                          ),
                        ),
                        onPressed: () async {
                          var reOrdered = await widget.services.store
                              .reOrder(order, widget.services.api);
                          if (reOrdered) {
                            await showModalBottomSheet(
                              backgroundColor: Colors.white,
                              context: context,
                              isDismissible: true,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(16),
                                    topRight: Radius.circular(16)),
                              ),
                              builder: (BuildContext context) =>
                                  getIt<EShopPaymentBottomSheet>(
                                param1: EShopPaymentBottomSheetParams(
                                  order: order,
                                ),
                              ),
                            );
                            await purchasesStore.getOrders(widget.services.api);
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            S.of(context).orderAgain,
                            style: GoogleFonts.rubik(
                              color: AppColors.kffffff,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    });
  }

  Widget divider() {
    return Container(
      height: 0.5,
      width: MediaQuery.of(context).size.width,
      color: AppColors.k5e5e5e.withOpacity(0.3),
    );
  }
}
