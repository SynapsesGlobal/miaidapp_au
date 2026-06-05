import 'package:collection/src/iterable_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:injectable/injectable.dart';
import 'package:miaid/component/miaid_drawer.dart';
import 'package:miaid/component/miaid_card.dart';
import 'package:miaid/component/nav_bar_icons.dart';
import 'package:miaid/config/app_colors.dart';
import 'package:miaid/generated/l10n.dart';
import 'package:miaid/generated_api_code/api_client.swagger.dart';
import 'package:miaid/payment/additional_services.dart';
import 'package:miaid/payment/payment_bottom_sheet.dart';
import 'package:miaid/store/home/active_subscription_store.dart';
import 'package:miaid/store/payment/payment_store.dart';
import 'package:miaid/store/user/calling/call_history/travel_care_packages_store.dart';
import 'package:miaid/utils/configure_dependencies.dart';
import 'package:tap_debouncer/tap_debouncer.dart';

class CorporateCarePackagesParams {
  const CorporateCarePackagesParams(this.key);

  final Key key;
}

@injectable
class CorporateCarePackagesServices {
  CorporateCarePackagesServices(
    this.store,
    this.activeSubscriptionStore,
  );

  final TravelCarePackagesStore store;
  final ActiveSubscriptionStore activeSubscriptionStore;
}

@injectable
class CorporateCarePackages extends StatefulWidget {
  CorporateCarePackages({
    @factoryParam this.params,
    required this.services,
  }) : super(key: params?.key);

  final CorporateCarePackagesParams? params;
  final CorporateCarePackagesServices services;

  @override
  _CorporateCarePackagesState createState() => _CorporateCarePackagesState();
}

class _CorporateCarePackagesState extends State<CorporateCarePackages> {
  static const homecareType = 'home care';
  static const travelType = 'travel care';

  List<SubscriptionDetail?> activeHomeCareSubscription = [];
  List<SubscriptionDetail?> activeTravelSubscription = [];

  @override
  void initState() {
    // widget.services.store.fetchAvailableSubscriptions();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final activeSubscriptionStore = widget.services.activeSubscriptionStore;
    final store = widget.services.store;

    activeHomeCareSubscription = activeSubscriptionStore
        .activeCompanySubscriptionDetails!
        .where((element) => element!.type == homecareType)
        .toList();

    activeTravelSubscription = activeSubscriptionStore
        .activeCompanySubscriptionDetails!
        .where((element) => element!.type == travelType)
        .toList();

    return Scaffold(
      backgroundColor: Colors.white,
      drawer: getDrawer(store.user),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        elevation: 0,
        backgroundColor: AppColors.kffffff,
        centerTitle: true,
        title: Text(
          '${S.of(context).corporateCare}${S.of(context).package}',
          style: GoogleFonts.rubik(
            color: AppColors.k010101,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        leading: Builder(
          builder: (BuildContext context) {
            return InkWell(
              onTap: () {
                Scaffold.of(context).openDrawer();
              },
              child: navBarIcon(iconAssetName: 'ic_nb_menu.png'),
            );
          },
        ),
      ),
      body: Observer(
        builder: (context) => packageList(context),
      ),
    );
  }

  Widget packageList(BuildContext context) {
    if (widget.services.activeSubscriptionStore
                .activeCompanySubscriptionDetails ==
            null ||
        widget.services.activeSubscriptionStore
            .activeCompanySubscriptionDetails!.isEmpty) {
      return ListView(
        children: [
          SizedBox(
            height: 15,
          ),
          Padding(
            padding: const EdgeInsets.only(
              left: 20,
              right: 20,
            ),
            child: Text(
              S.of(context).activePackage,
              style: GoogleFonts.rubik(
                color: AppColors.k010101,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (widget.services.activeSubscriptionStore
                  .activeCustomerSubscriptionDetail ==
              null)
            _noActivePackage(context),
        ],
      );
    } else {
      var widgets = <Widget>[];

      if (activeHomeCareSubscription.isNotEmpty) {
        widgets.add(SizedBox(
          height: 15,
        ));
        widgets.add(Padding(
          padding: const EdgeInsets.only(
            left: 20,
            right: 20,
          ),
          child: Text(
            S.of(context).activeHomePackage,
            style: GoogleFonts.rubik(
              color: AppColors.k010101,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ));
        widgets.add(SizedBox(
          height: 15,
        ));
        widgets.add(ListView.builder(
          shrinkWrap: true,
          physics: ClampingScrollPhysics(),
          itemCount: activeHomeCareSubscription.length,
          itemBuilder: (context, index) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 19,
              ),
              _activePackage(activeHomeCareSubscription[index])
            ],
          ),
        ));
      }

      if (activeTravelSubscription.isNotEmpty) {
        widgets.add(SizedBox(
          height: 15,
        ));
        widgets.add(Padding(
          padding: const EdgeInsets.only(
            left: 20,
            right: 20,
          ),
          child: Text(
            S.of(context).activeTravelPackage,
            style: GoogleFonts.rubik(
              color: AppColors.k010101,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ));
        widgets.add(SizedBox(
          height: 15,
        ));
        widgets.add(ListView.builder(
          shrinkWrap: true,
          physics: ClampingScrollPhysics(),
          itemCount: activeTravelSubscription.length,
          itemBuilder: (context, index) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 19,
              ),
              _activePackage(activeTravelSubscription[index])
            ],
          ),
        ));
      }
      widgets.add(SizedBox(
        height: 40,
      ));

      return ListView(children: widgets);
    }
  }

  Widget _packageDetails(
      BuildContext context, SubscriptionDetail subscriptionDetail) {
    return miAidCard(
      Padding(
        padding: const EdgeInsets.only(left: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(
                top: 15,
                bottom: 11,
              ),
              child: Text(
                subscriptionDetail.name ?? 'N/A',
                style: GoogleFonts.rubik(
                  color: AppColors.k010101,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              subscriptionDetail.description ?? '',
              style: GoogleFonts.rubik(
                color: AppColors.k696969,
                fontSize: 14,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(
                top: 16,
                bottom: 14,
                right: 15,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: AppColors.kf4f4f4,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.only(
                        left: 7,
                        right: 7,
                        bottom: 7,
                        top: 7,
                      ),
                      child: RichText(
                        text: TextSpan(
                          style: GoogleFonts.rubik(
                            color: AppColors.k010101,
                          ),
                          children: [
                            TextSpan(
                              text: subscriptionDetail.currency?.currency ??
                                  'N/A',
                              style: GoogleFonts.rubik(
                                fontSize: 12,
                              ),
                            ),
                            TextSpan(
                              text: amountDisplay(subscriptionDetail.amount),
                              style: GoogleFonts.rubik(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  TapDebouncer(
                    onTap: () async =>
                        await _subscribe(context, subscriptionDetail),
                    builder: (context, onTap) => GestureDetector(
                      onTap: onTap,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(9),
                          color: AppColors.k0cbcc5,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.only(
                            left: 11,
                            right: 10,
                            bottom: 4,
                            top: 5,
                          ),
                          child: Text(
                            S.of(context).subscribe,
                            style: GoogleFonts.rubik(
                              color: AppColors.kffffff,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Padding _activePackage(SubscriptionDetail? subscriptionDetail) {
    return Padding(
      padding: const EdgeInsets.only(
        left: 20,
        right: 20,
      ),
      child: activeSubscriptionCard(
        Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(
                  top: 15,
                  bottom: 11,
                ),
                child: Text(
                  subscriptionDetail?.name ?? '',
                  style: GoogleFonts.rubik(
                    color: AppColors.kffffff,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                subscriptionDetail?.description ?? '',
                style: GoogleFonts.rubik(
                  color: AppColors.kffffff.withOpacity(0.75),
                  fontSize: 14,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(
                  top: 16,
                  bottom: 14,
                  right: 15,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: AppColors.kffffff.withOpacity(0.3),
                      ),
                      // child: Padding(
                      //   padding: const EdgeInsets.only(
                      //     left: 7,
                      //     right: 7,
                      //     bottom: 7,
                      //     top: 7,
                      //   ),
                      //   child: RichText(
                      //     text: TextSpan(
                      //       style: GoogleFonts.rubik(
                      //         color: AppColors.kffffff.withOpacity(0.75),
                      //       ),
                      //       children: [
                      //         TextSpan(
                      //           text: subscriptionDetail?.currency?.currency ??
                      //               'N/A',
                      //           style: GoogleFonts.rubik(
                      //             fontSize: 12,
                      //           ),
                      //         ),
                      //         TextSpan(
                      //           text: amountDisplay(subscriptionDetail?.amount),
                      //           style: GoogleFonts.rubik(
                      //             color: AppColors.kffffff,
                      //             fontSize: 18,
                      //             fontWeight: FontWeight.bold,
                      //           ),
                      //         ),
                      //       ],
                      //     ),
                      //   ),
                      // ),
                    ),
                    Container(
                      height: 24,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        color: AppColors.kffffff.withOpacity(0.3),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.only(
                          left: 10,
                          right: 10,
                        ),
                        child: Align(
                          alignment: Alignment.center,
                          child: Text(
                            S.of(context).nDaysRemaining(
                                _daysRemaining(subscriptionDetail)),
                            style: GoogleFonts.rubik(
                              color: AppColors.kffffff,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  // Padding _activePackage(BuildContext context) {
  //   final activeSubscription = widget
  //       .services.activeSubscriptionStore.activeCompanySubscriptionDetails ;
  //
  //
  //   return Padding(
  //     padding: const EdgeInsets.only(left: 20, right: 20),
  //     child: ListView.builder(
  //       itemCount: 1,
  //       shrinkWrap: true,
  //       physics: ClampingScrollPhysics(),
  //       itemBuilder: (BuildContext context, index) => Column(
  //         crossAxisAlignment: CrossAxisAlignment.start,
  //         children: [
  //           // activeSubscriptionCard(
  //           //   Padding(
  //           //     padding: const EdgeInsets.only(left: 16),
  //           //     child: Column(
  //           //       crossAxisAlignment: CrossAxisAlignment.start,
  //           //       children: [
  //           //         Padding(
  //           //           padding: const EdgeInsets.only(
  //           //             top: 15,
  //           //             bottom: 11,
  //           //           ),
  //           //           child: Text(
  //           //             activeSubscription?.name ?? '',
  //           //             style: GoogleFonts.rubik(
  //           //               color: AppColors.kffffff,
  //           //               fontSize: 18,
  //           //               fontWeight: FontWeight.w700,
  //           //             ),
  //           //           ),
  //           //         ),
  //           //         Text(
  //           //           activeSubscription?.description ?? '',
  //           //           style: GoogleFonts.rubik(
  //           //             color: AppColors.kffffff.withOpacity(0.75),
  //           //             fontSize: 14,
  //           //           ),
  //           //         ),
  //           //         Padding(
  //           //           padding: const EdgeInsets.only(
  //           //             top: 16,
  //           //             bottom: 14,
  //           //             right: 15,
  //           //           ),
  //           //           child: Row(
  //           //             mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //           //             children: [
  //           //               Container(
  //           //                 decoration: BoxDecoration(
  //           //                   borderRadius: BorderRadius.circular(4),
  //           //                   color: AppColors.kffffff.withOpacity(0.3),
  //           //                 ),
  //           //                 child: Padding(
  //           //                   padding: const EdgeInsets.only(
  //           //                     left: 7,
  //           //                     right: 7,
  //           //                     bottom: 7,
  //           //                     top: 7,
  //           //                   ),
  //           //                   child: RichText(
  //           //                     text: TextSpan(
  //           //                       style: GoogleFonts.rubik(
  //           //                         color: AppColors.kffffff.withOpacity(0.75),
  //           //                       ),
  //           //                       children: [
  //           //                         TextSpan(
  //           //                           text: activeSubscription
  //           //                               ?.currency?.currency ??
  //           //                               'N/A',
  //           //                           style: GoogleFonts.rubik(
  //           //                             fontSize: 12,
  //           //                           ),
  //           //                         ),
  //           //                         TextSpan(
  //           //                           text: amountDisplay(
  //           //                               activeSubscription?.amount),
  //           //                           style: GoogleFonts.rubik(
  //           //                             color: AppColors.kffffff,
  //           //                             fontSize: 18,
  //           //                             fontWeight: FontWeight.bold,
  //           //                           ),
  //           //                         ),
  //           //                       ],
  //           //                     ),
  //           //                   ),
  //           //                 ),
  //           //               ),
  //           //               Container(
  //           //                 height: 24,
  //           //                 decoration: BoxDecoration(
  //           //                   borderRadius: BorderRadius.circular(3),
  //           //                   color: AppColors.kffffff.withOpacity(0.3),
  //           //                 ),
  //           //                 child: Padding(
  //           //                   padding: const EdgeInsets.only(
  //           //                     left: 10,
  //           //                     right: 10,
  //           //                   ),
  //           //                   child: Align(
  //           //                     alignment: Alignment.center,
  //           //                     child: Text(
  //           //                       S.of(context).nDaysRemaining(
  //           //                           _daysRemaining(activeSubscription)),
  //           //                       style: GoogleFonts.rubik(
  //           //                         color: AppColors.kffffff,
  //           //                         fontSize: 12,
  //           //                       ),
  //           //                     ),
  //           //                   ),
  //           //                 ),
  //           //               ),
  //           //             ],
  //           //           ),
  //           //         )
  //           //       ],
  //           //     ),
  //           //   ),
  //           // ),
  //         ],
  //       ),
  //     ),
  //   );
  // }

  Column _noActivePackage(BuildContext context) {
    return Column(
      children: [
        Image(
          image: AssetImage('assets/images/Img_signin_travelcare_active.png'),
        ),
        SizedBox(
          height: 10,
        ),
        Center(
          child: Text(
            '${S.of(context).no} ${S.of(context).activePackage}',
            style: GoogleFonts.rubik(
              color: AppColors.k696969,
              fontSize: 17,
            ),
          ),
        ),
      ],
    );
  }

  int _daysRemaining(SubscriptionDetail? activeSubscription) {
    if (activeSubscription?.companyCustomerSubscription != null) {
      return DateTime.parse(
              activeSubscription!.companyCustomerSubscription!.endAt!)
          .difference(DateTime.now())
          .inDays;
    } else if (activeSubscription?.customerSubscription != null) {
      return DateTime.parse(activeSubscription!.customerSubscription!.endAt!)
          .difference(DateTime.now())
          .inDays;
    }
    return 0;
  }

  Future<void> _subscribe(
      BuildContext context, SubscriptionDetail subscriptionDetail) async {
    final parentContext = context;
    await showModalBottomSheet<void>(
      backgroundColor: Colors.white,
      context: context,
      isDismissible: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      builder: (BuildContext context) => getIt<PaymentBottomSheet>(
        param1: PaymentBottomSheetParams(
          context: parentContext,
          purchaseRequest: PurchaseRequest(
            PurchaseType.travelPackages,
            subscriptionDetail.id!,
            subscriptionDetail.amount!,
            subscriptionDetail.currency!,
          ),
        ),
      ),
    );
  }
}
