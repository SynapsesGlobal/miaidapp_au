import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:injectable/injectable.dart';
import 'package:miaid/component/nav_bar_icons.dart';
import 'package:miaid/component/progress_indicator.dart';
import 'package:miaid/config/app_colors.dart';
import 'package:miaid/generated/l10n.dart';
import 'package:miaid/store/static_pages/static_pages_store.dart';

class PrivacyPolicyParams {
  const PrivacyPolicyParams(this.key);

  final Key key;
}

@injectable
class PrivacyPolicyServices {
  PrivacyPolicyServices(this.store);

  final StaticPageStore store;
}

@injectable
class PrivacyPolicy extends StatefulWidget {
  PrivacyPolicy({
    @factoryParam this.params,
    required this.services,
  }) : super(key: params?.key);

  final PrivacyPolicyParams? params;
  final PrivacyPolicyServices services;

  @override
  _PrivacyPolicyState createState() => _PrivacyPolicyState();
}

class _PrivacyPolicyState extends State<PrivacyPolicy> {
  @override
  void initState() {
    super.initState();
    widget.services.store.fetchStaticPages();
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.services.store;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.kffffff,
        centerTitle: true,
        title: Text(
          S.of(context).privacy,
          style: GoogleFonts.rubik(
            color: AppColors.k010101,
            fontSize: 15,
            fontWeight: FontWeight.normal,
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
      body: SingleChildScrollView(
        child: Observer(
          builder: (context) => Padding(
            padding: const EdgeInsets.only(left: 20, right: 20, top: 20),
            child: store.isLoading
                ? Center(child: progressIndicator())
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Html(
                        data: store.pages.isNotEmpty
                            ? '''${store.pages[1].value}'''
                            : 'Privacy Policy not available',
                        style: {
                          'p': Style(
                            fontSize: FontSize.medium,
                            color: AppColors.k010101,
                          ),
                        },
                      ),
                      SizedBox(
                        height: 17,
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
