import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:injectable/injectable.dart';
import 'package:miaid/api_utils/http_exception.dart';
import 'package:miaid/component/miaid_card.dart';
import 'package:miaid/component/nav_bar_icons.dart';
import 'package:miaid/config/app_colors.dart';
import 'package:miaid/generated/l10n.dart';
import 'package:miaid/generated_api_code/api_client.swagger.dart';
import 'package:miaid/payment/payment_bottom_sheet.dart';
import 'package:miaid/services/square_payment_backend_service.dart';
import 'package:miaid/store/payment/additional_services_store.dart';
import 'package:miaid/store/payment/payment_store.dart';
import 'package:miaid/utils/configure_dependencies.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:miaid/view/user/home/home_screen.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api_utils/api_provider.dart';
import 'package:http/http.dart' as http;

class AdditionalServicesParams {
  const AdditionalServicesParams(this.key);

  final Key key;
}

@injectable
class AdditionalServicesServices {
  AdditionalServicesServices(this.store);

  final AdditionalServicesStore store;
}

@injectable
class AdditionalServices extends StatefulWidget {
  AdditionalServices({
    @factoryParam this.params,
    required this.services,
  }) : super(key: params?.key);

  final AdditionalServicesParams? params;
  final AdditionalServicesServices services;

  @override
  _AdditionalServicesState createState() => _AdditionalServicesState();
}

class _AdditionalServicesState extends State<AdditionalServices> {
  bool _isLoading = true;
  bool open_square_payment = false;

  @override
  void initState() {
    super.initState();
    _loadServices();
  }

  Future<void> _checkCurrentUserCanUseSquarePayment() async {
    final api = getIt<ApiProvider>();
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'x-user-id': api.userProvider.user!.id.toString(),
      'x-api-key': api.apiKey,
      'x-access-token': api.userProvider.user!.accessToken.toString()
    };

    try {
      final url = Uri.parse(api.baseUrl+'/api/v1/square/check_enabled?userId='+api.userProvider.user!.id.toString());
      final response = await http.get(url, headers: headers,);

      await EasyLoading.dismiss();
      var responseData = jsonDecode(response.body);
      if (response.statusCode == 200) {
        setState(() {
          open_square_payment = responseData['open_square_payment'];
        });
      }
    } catch (e) {
      print(e.toString());
    }
  }

  Future<void> _loadServices() async {
    await EasyLoading.show(
      status: 'Loading...',
      maskType: EasyLoadingMaskType.black,
    );
    try {
      await _checkCurrentUserCanUseSquarePayment();
      await widget.services.store.fetchServices();
    } catch (e) {
      if (e is HttpException && e.statusCode == 401) {
        await widget.services.store.user.logOut();
        await HttpExceptionNotifyUser.showInfo(S.of(context).relogin);
      } else {
        await HttpExceptionNotifyUser.showInfo(S.of(context).somethingWentWrong);
      }
      if (mounted) {
        await Navigator.pushAndRemoveUntil(
          context,
          // ignore: inference_failure_on_instance_creation
          MaterialPageRoute(
            builder: (context) => getIt<HomeScreen>(),
          ),
          (route) => false,
        );
      }
    } finally {
      await EasyLoading.dismiss();
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.services.store;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.kffffff,
        elevation: 0,
        leading: InkWell(
          onTap: () {
            Navigator.pop(context);
          },
          child: navBarIcon(iconAssetName: 'ic_nb_back.png'),
        ),
        centerTitle: true,
        title: Text(
          S.of(context).otherService,
          style: GoogleFonts.rubik(
            color: AppColors.k010101,
            fontSize: 15,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 5),
        child: Observer(
          builder: (context) => _isLoading ? const SizedBox.shrink() : store.services.isNotEmpty ? ListView.builder(
            itemCount: store.services.length,
            physics: ClampingScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            itemBuilder: (BuildContext context, index) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ..._serviceCard(
                  context,
                  store.services[index].service,
                  store.services[index].purchaseType,
                ),
              ],
            ),
          ) : Column(children: [
            Image(
              image: AssetImage('assets/images/Img_signin_travelcare_active.png'),
            ),
            SizedBox(height: 10,),
            Center(child: Text(
              ' ${S.of(context).noAvailableService}',
              style: GoogleFonts.rubik(
                color: AppColors.k696969,
                fontSize: 17,
              ),
            ),),
          ],),
        ),
      ),
    );
  }

  Future<void> _refreshServices() async {
    try {
      await EasyLoading.show(
        status: 'Processing...',
        maskType: EasyLoadingMaskType.clear,
      );
      await widget.services.store.fetchServices();
    } catch (e) {
      print(e);
    } finally {
      await EasyLoading.dismiss();
    }
  }

  List<Widget> _serviceCard(BuildContext context, Service service, PurchaseType purchaseType) {
    final parentContext = context;
    return [
      miAidCard(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 15, 12, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                service.name ?? '',
                style: GoogleFonts.rubik(
                  color: AppColors.k010101,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 11,),
              Text(
                service.featureDescription ?? '',
                style: GoogleFonts.rubik(
                  color: AppColors.k5e5e5e,
                  fontSize: 14,
                ),
              ),
              SizedBox(height: 11,),
              Row(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: AppColors.kf4f4f4,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(9, 7, 9, 7),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(service.currency?.currency ?? 'N/A'),
                          Text(
                            amountDisplay(service.amount),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () async {
                      // 与 travel_care_packages 页面保持一致的判断逻辑：
                      // iOS 且已安装 Square POS 时走 Square 支付，否则走原有
                      // 的卡支付底部弹窗，确保正常功能不受影响。
                      if (open_square_payment && Platform.isIOS && await canLaunchUrl(Uri.parse('square-commerce-v1://'))) {
                        final paid = await PaymentBackend.subscribeWithSquare(
                          parentContext,
                          packageId: service.id!.toString(),
                          type: 'call',
                        );
                        if (paid) await _refreshServices();
                        return;
                      }
                      unawaited(showModalBottomSheet<void>(
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
                              purchaseType,
                              service.id!,
                              service.amount!,
                              service.currency!,
                            ),
                            onSuccess: _refreshServices,
                          ),
                        ),
                      ));
                    },
                    child: Container(
                      padding: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(9),
                        color: AppColors.k0cbcc5,
                      ),
                      child: Text(
                        S.of(context).getThisService,
                        style: GoogleFonts.rubik(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
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
      SizedBox(
        height: 20,
      ),
    ];
  }
}

String amountDisplay(int? amountCents) {
  if (amountCents == null) {
    return 'N/A';
  }
  final amount = amountCents / 100.0;
  return amount.toStringAsFixed(2);
}
