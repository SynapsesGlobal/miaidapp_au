import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:injectable/injectable.dart';
import 'package:miaid/api_utils/api_provider.dart';
import 'package:miaid/api_utils/http_exception.dart';
import 'package:miaid/component/nav_bar_icons.dart';
import 'package:miaid/config/api_settings.dart';
import 'package:miaid/config/app_colors.dart';
import 'package:miaid/generated_api_code/api_client.swagger.dart';
import 'package:miaid/services/facebook_service.dart';
import 'package:miaid/store/payment/payment_store.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:miaid/generated/l10n.dart';
import 'package:miaid/main.dart';
import 'dart:developer' as developer;

@injectable
class PaymentPaypal extends StatefulWidget {
  PaymentPaypal({@factoryParam this.params, required this.service});
  // PaymentPaypal(this.params);
  // final PaypalScreenParams params;

  final PaymentPaypalParams? params;
  final PaymentPaypalService? service;

  @override
  _PaymentPaypalState createState() => _PaymentPaypalState();
}

class PaymentPaypalParams {
  PaymentPaypalParams({
    required this.customerId,
    required this.paymentId,
    required this.order,
    required this.purchaseRequest,
  });
  final int customerId;
  final int paymentId;
  final Order? order;
  final PurchaseRequest? purchaseRequest;
}

@injectable
class PaymentPaypalService {
  PaymentPaypalService(
    this.apiProvider,
  );
  ApiProvider apiProvider;
}

class _PaymentPaypalState extends State<PaymentPaypal> {
  late String selectedUrl;
  double value = 0.0;
  bool _canRedirect = true;
  bool _isLoading = true;
  final Completer<WebViewController> _controller =
      Completer<WebViewController>();
  late WebViewController controllerGlobal;

  @override
  void initState() {
    selectedUrl = widget.service!.apiProvider.baseUrl +
        "/paypal?customer_id=" +
        widget.params!.customerId.toString() +
        "&payment_id=" +
        widget.params!.paymentId.toString();

    super.initState();
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
          S.of(context).payment,
          style: GoogleFonts.rubik(
            color: AppColors.k010101,
            fontSize: 15,
          ),
        ),
      ),
      body: WebView(
        javascriptMode: JavascriptMode.unrestricted,
        initialUrl: selectedUrl,
        gestureNavigationEnabled: true,
        //
        // userAgent: 'Mozilla/5.0 (iPhone; CPU iPhone OS 9_3 like Mac OS X) AppleWebKit/601.1.46 (KHTML, like Gecko) Version/9.0 Mobile/13E233 Safari/601.1',
        onWebResourceError: (error) {},
        onWebViewCreated: (WebViewController webViewController) {
          _controller.future.then((value) => controllerGlobal = value);
          _controller.complete(webViewController);
          //_controller.future.catchError(onError)
        },
        onProgress: (int progress) {},
        onPageStarted: (String url) {
          setState(() {
            _isLoading = true;
          });
          //developer.log("printing urls "+url.toString());
          _redirect(url);
        },
        onPageFinished: (String url) {
          setState(() {
            _isLoading = false;
          });
          _redirect(url);
        },
      ),
    );
  }

  void _redirect(String url) {
    //developer.log("redirect");
    //developer.log("URL" + url);
    if (_canRedirect) {
      bool _isSuccess = url.contains('success') &&
          url.contains(widget.service!.apiProvider.baseUrl);
      bool _isFailed = url.contains('fail') &&
          url.contains(widget.service!.apiProvider.baseUrl);
      bool _isCancel = url.contains('cancel') &&
          url.contains(widget.service!.apiProvider.baseUrl);
      if (_isSuccess || _isFailed || _isCancel) {
        _canRedirect = false;
      }
      if (_isSuccess) {
        // Get.offNamed(RouteHelper.getOrderSuccessRoute(widget.orderModel.id.toString(), 'success'));

        // if order is null, then it's a subscription payment
        if (widget.params!.order == null &&
            widget.params!.purchaseRequest != null) {
          LogEventService.purchaseSubscription(
            currency: widget.params!.purchaseRequest?.currency.currency ?? '',
            total: widget.params!.purchaseRequest?.amount.toDouble() ?? 0,
            orderId: widget.params!.paymentId.toString(),
          );
        } else if (widget.params!.order != null) {
          // else it's a shop payment
          LogEventService.purchase(
            orderItems: widget.params!.order?.products ?? <Product>[],
            currency: widget.params!.order?.pharmacyCurrency ?? '',
            total: widget.params!.order?.subTotal ?? 0,
            orderId: widget.params!.order?.id.toString() ?? '',
          );
        }

        Navigator.pop(context);
      } else if (_isFailed || _isCancel) {
        // Get.offNamed(RouteHelper.getOrderSuccessRoute(widget.orderModel.id.toString(), 'fail'));
      } else {
        //developer.log("Encountered problem");
      }
    }
  }

  Future<bool> _exitApp(BuildContext context) async {
    if (await controllerGlobal.canGoBack()) {
      controllerGlobal.goBack();
      return Future.value(false);
    } else {
      return true;
      // return Get.dialog(PaymentFailedDialog(orderID: widget.orderModel.id.toString()));
    }
  }
}
