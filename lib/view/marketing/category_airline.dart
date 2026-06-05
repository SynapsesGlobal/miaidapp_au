import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../api_utils/api_provider.dart';
import '../../component/nav_bar_icons.dart';
import '../../config/app_colors.dart';
import '../../utils/configure_dependencies.dart';

class CategoryAirline extends StatefulWidget {
  const CategoryAirline({super.key});

  @override
  State<CategoryAirline> createState() => _CategoryAirlineState();
}

class _CategoryAirlineState extends State<CategoryAirline> {

  final Completer<WebViewController> _controller = Completer<WebViewController>();
  late WebViewController controllerGlobal;
  final api = getIt<ApiProvider>();
  var flightUrl = '';


  @override
  void initState() {
    setState(() {
      flightUrl = api.baseUrl+'/saml/serko/sso?userId='+api.userProvider.user!.id.toString();
    });
    super.initState();
  }

  @override
  void dispose() {
    EasyLoading.dismiss();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        elevation: 0,
        backgroundColor: AppColors.kffffff,
        centerTitle: true,
        title: Text('Airline', style: GoogleFonts.rubik(
          color: AppColors.k010101,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),),
        leading: Builder(
          builder: (BuildContext context) => InkWell(
            onTap: () => Navigator.pop(context),
            child: navBarIcon(iconAssetName: 'ic_nb_back.png'),
          ),
        ),
      ),
      body: flightUrl.isNotEmpty ? WebView(
        javascriptMode: JavascriptMode.unrestricted,
        initialUrl: flightUrl,
        gestureNavigationEnabled: true,
        onWebResourceError: (error) {},
        onWebViewCreated: (WebViewController webViewController) {
          _controller.future.then((value) => controllerGlobal = value);
          _controller.complete(webViewController);
        },
        onPageStarted: (String url) {
          if (!mounted) return;
          EasyLoading.show(
            status: 'Loading',
            maskType: EasyLoadingMaskType.black,
          );
        },
        onProgress: (int progress) {},
        onPageFinished: (String url) {
          if (!mounted) return;
          EasyLoading.dismiss();
        },
      ) : Offstage(),
    );
  }
}
