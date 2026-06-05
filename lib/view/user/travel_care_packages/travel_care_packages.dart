import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
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
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../api_utils/api_provider.dart';
import '../../../api_utils/http_exception.dart';
import '../../../services/square_payment_backend_service.dart';
import '../../../store/home/home_screen_store.dart';

class TravelCarePackagesParams {
  const TravelCarePackagesParams(this.key);

  final Key key;
}

@injectable
class TravelCarePackagesServices {
  TravelCarePackagesServices(
    this.store,
    this.activeSubscriptionStore,
  );

  final TravelCarePackagesStore store;
  final ActiveSubscriptionStore activeSubscriptionStore;
}

@injectable
class TravelCarePackages extends StatefulWidget {
  TravelCarePackages({
    @factoryParam this.params,
    required this.services,
  }) : super(key: params?.key);

  final TravelCarePackagesParams? params;
  final TravelCarePackagesServices services;

  @override
  _TravelCarePackagesState createState() => _TravelCarePackagesState();
}

class _TravelCarePackagesState extends State<TravelCarePackages> {
  @override
  void initState() {
    _getActiveSubscriptions();
    widget.services.store.fetchAvailableSubscriptions();
    super.initState();
  }

  List subscriptions = [];
  int remainCount = 0;
  bool loaded = false;
  bool open_square_payment = false;
  Future<void> _getActiveSubscriptions() async {
    final api = getIt<ApiProvider>();
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'x-user-id': api.userProvider.user!.id.toString(),
      'x-api-key': api.apiKey,
      'x-access-token': api.userProvider.user!.accessToken.toString()
    };

    await EasyLoading.show(
      status: 'Loading',
      maskType: EasyLoadingMaskType.black,
    );

    try {
      final position = await _getPosition();
      final countryCode = await getCountryCodeFromLocation(position);
      final url = Uri.parse(api.baseUrl+'/api/v1/active/packages?country_code=$countryCode');
      final response = await http.get(url, headers: headers,);

      await EasyLoading.dismiss();

      var responseData = jsonDecode(response.body);
      if (response.statusCode == 200) {
        setState(() {
          subscriptions = responseData['subscriptions'];
          remainCount = int.parse(responseData['consultationCount'].toString());
          open_square_payment = responseData['open_square_payment'];
          loaded = true;
        });
      } else {
        await EasyLoading.dismiss();
        await HttpExceptionNotifyUser.showInfo(responseData['message']);
      }
    } catch (e) {
      print(e.toString());
      await EasyLoading.dismiss();
    }
  }

  Future<Position> _getPosition() =>
      determinePosition(desiredAccuracy: LocationAccuracy.medium);

  @override
  Widget build(BuildContext context) {
    final store = widget.services.store;
    return Scaffold(
      backgroundColor: Colors.white,
      drawer: getDrawer(store.user),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        elevation: 0,
        backgroundColor: AppColors.kffffff,
        centerTitle: true,
        title: Text(
          '${S.of(context).travelCarePackages}',
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
                Navigator.pop(context);
              },
              child: navBarIcon(iconAssetName: 'ic_nb_back.png'),
            );
          },
        ),
      ),
      body: loaded ? Observer(
        builder: (context) => ListView(children: [
          SizedBox(height: 15,),
          Padding(
            padding: const EdgeInsets.only(
              left: 20,
              right: 20,
            ),
            child: Text(S.of(context).activePackage, style: GoogleFonts.rubik(
              color: AppColors.k010101,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),),
          ),
          subscriptions.isEmpty ? _noActivePackage(context) : _activePackage(context),
          SizedBox(height: 28.4,),
          remainCount > 0 ? Offstage() : Padding(
            padding: const EdgeInsets.only(
              left: 20,
              right: 20,
            ),
            child: Text(
              '${S.of(context).availablePackages}',
              style: GoogleFonts.rubik(
                color: AppColors.k010101,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          remainCount > 0 ? Offstage() : Padding(
            padding: const EdgeInsets.only(
              left: 20,
              right: 20,
              bottom: 10,
            ),
            child: Observer(
              builder: (context) => ListView.builder(
                shrinkWrap: true,
                physics: ClampingScrollPhysics(),
                itemCount: store.availableSubscriptions.length,
                itemBuilder: (BuildContext context, index) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 19,
                    ),
                    _packageDetails(context, store.availableSubscriptions[index]),
                  ],
                ),
              ),
            ),
          ),
        ]),
      ) : Offstage(),
    );
  }

  Widget _packageDetails(BuildContext context, SubscriptionDetail subscriptionDetail) {
    return miAidCard(
      Padding(
        padding: const EdgeInsets.only(left: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 15, bottom: 11,),
              child: Text(subscriptionDetail.name ?? 'N/A', style: GoogleFonts.rubik(
                color: AppColors.k010101,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),),
            ),
            Text(subscriptionDetail.description ?? '', style: GoogleFonts.rubik(
              color: AppColors.k696969,
              fontSize: 14,
            ),),
            Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 14, right: 15,),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: AppColors.kf4f4f4,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.only(left: 7, right: 7, bottom: 7, top: 7,),
                      child: RichText(
                        text: TextSpan(
                          style: GoogleFonts.rubik(
                            color: AppColors.k010101,
                          ),
                          children: [
                            TextSpan(
                              text: subscriptionDetail.currency?.currency ?? 'N/A',
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
                    onTap: () async {
                      if (open_square_payment && Platform.isIOS && await canLaunchUrl(Uri.parse('square-commerce-v1://'))) {
                        await _subscribeWithSquare(context, subscriptionDetail);
                      } else {
                        await _subscribeWithStripe(context, subscriptionDetail);
                      }
                    },
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

  Padding _activePackage(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 20),
      child: ListView.builder(
        itemCount: subscriptions.length,
        shrinkWrap: true,
        physics: ClampingScrollPhysics(),
        itemBuilder: (BuildContext context, index) => Container(
          margin: EdgeInsets.only(top: 10),
          child: activeSubscriptionCard(
            Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 15, bottom: 11,),
                    child: Text(subscriptions[index]['name'] ?? '', style: GoogleFonts.rubik(
                      color: AppColors.kffffff,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),),
                  ),
                  Text(subscriptions[index]['description'] ?? '', style: GoogleFonts.rubik(
                    color: AppColors.kffffff.withOpacity(0.75),
                    fontSize: 14,
                  ),),
                  Padding(
                    padding: const EdgeInsets.only(top: 16, bottom: 14, right: 15,),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            color: AppColors.kffffff.withOpacity(0.3),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.only(left: 7, right: 7, bottom: 7, top: 7,),
                            child: RichText(
                              text: TextSpan(
                                style: GoogleFonts.rubik(
                                  color: AppColors.kffffff.withOpacity(0.75),
                                ),
                                children: [
                                  TextSpan(
                                    text: subscriptions[index]['currency'] ?? 'N/A',
                                    style: GoogleFonts.rubik(
                                      fontSize: 12,
                                    ),
                                  ),
                                  TextSpan(
                                    text: " ${subscriptions[index]['amount'].toString()}",
                                    style: GoogleFonts.rubik(
                                      color: AppColors.kffffff,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Container(
                          height: 24,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(3),
                            color: AppColors.kffffff.withOpacity(0.3),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.only(left: 10, right: 10,),
                            child: Align(
                              alignment: Alignment.center,
                              child: Text(S.of(context).nDaysRemaining(subscriptions[index]['remainingDays']), style: GoogleFonts.rubik(
                                color: AppColors.kffffff,
                                fontSize: 12,
                              ),),
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
        ),
      ),
    );
  }

  Column _noActivePackage(BuildContext context) {
    return Column(
      children: [
        Image(image: AssetImage('assets/images/Img_signin_travelcare_active.png'),),
        SizedBox(height: 10,),
        Center(child: Text('${S.of(context).noActivePackage}', style: GoogleFonts.rubik(
          color: AppColors.k696969,
          fontSize: 17,
        ),),),
      ],
    );
  }

  Future<void> _subscribeWithStripe(BuildContext context, SubscriptionDetail subscriptionDetail) async {
    final parentContext = context;
    var is_success = await showModalBottomSheet<bool>(
      backgroundColor: Colors.white,
      context: context,
      isDismissible: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
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
    if (is_success == true) await _getActiveSubscriptions();
  }

  Future<void> _subscribeWithSquare(BuildContext context, SubscriptionDetail subscriptionDetail) async {
    final didSubscribe = await PaymentBackend.subscribeWithSquare(
      context,
      packageId: subscriptionDetail.id.toString(),
    );
    if (!mounted) return;
    if (didSubscribe) {
      await _getActiveSubscriptions();
      unawaited(widget.services.store.fetchAvailableSubscriptions());
    }
  }
}
