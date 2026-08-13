import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:miaid/view/marketing/credits_transfer.dart';

import '../../api_utils/api_provider.dart';
import '../../api_utils/http_exception.dart';
import '../../component/nav_bar_icons.dart';
import '../../config/app_colors.dart';
import '../../generated/l10n.dart';
import '../../utils/configure_dependencies.dart';
import 'package:miaid/config/api_settings.dart';

class Credits extends StatefulWidget {
  const Credits({super.key});

  @override
  State<Credits> createState() => _CreditsState();
}

class _CreditsState extends State<Credits> {
  late List credits = [];
  var rules;
  String no_data = '';
  var _loaded = false;
  bool _hasMore = true;
  bool _loading = false;
  bool _rulesLoaded = false;
  int _currentPage = 1;
  final int _pageSize = 10;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    _getCredits();
    _getCreditsRules();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 50) {
        _getCredits();
      }
    });
    super.initState();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _getCredits() async {
    if (_loading || !_hasMore) return;

    setState(() => _loading = true);

    final headers = <String, String>{
      'Content-Type': 'application/json',
      'x-api-key': getIt<ApiSettings>().marketingApiKey,
    };

    if (_currentPage == 1) {
      await EasyLoading.show(
        status: 'Loading',
        maskType: EasyLoadingMaskType.black,
      );
    }

    try {
      final api = getIt<ApiProvider>();
      final url = Uri.parse(getIt<ApiSettings>().marketingApiHost+'/credits').replace(queryParameters: {
        'userId': api.userProvider.user!.id.toString(),
        'page': _currentPage.toString(),
        'pageSize': _pageSize.toString()
      });
      final response = await http.get(url, headers: headers);

      if (_currentPage == 1) await EasyLoading.dismiss();
      if (response.statusCode == 200) {
        var responseData = jsonDecode(response.body)['credits'];
        setState(() {
          credits.addAll(responseData);
          _loaded = true;
          _currentPage++;
          _hasMore = responseData.isNotEmpty;
        });
      } else {
        await HttpExceptionNotifyUser.showInfo(S.of(context).somethingWentWrong);
      }
    } catch (e) {
      if (_currentPage == 1) await EasyLoading.dismiss();
    }
    setState(() => _loading = false);
  }

  Future<void> _getCreditsRules() async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'x-api-key': getIt<ApiSettings>().marketingApiKey,
    };

    try {
      final url = Uri.parse(getIt<ApiSettings>().marketingApiHost+'/credit/rules');
      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        setState(() {
          _rulesLoaded = true;
          rules = jsonDecode(response.body);
        });
      } else {
        await HttpExceptionNotifyUser.showInfo(S.of(context).somethingWentWrong);
      }
    } catch (e) {
      print(e);
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
        title: Text(S.of(context).credit_detail, style: GoogleFonts.rubik(
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
        actions: [
          IconButton(
            onPressed: (){
              _showCustomPointsRuleDialog(context);
            },
            icon: Icon(Icons.info, color: AppColors.k0cbcc5,)
          )
        ],
      ),
      body: Column(children: [
        _buildMainScreenView(),
        _buildActionView()
      ],),
    );
  }

  Widget _buildMainScreenView() {
    if (_loaded && credits.isNotEmpty) {
      return Expanded(child: ListView.builder(
        controller: _scrollController,
        itemBuilder: (context, int index) {
          if (index < credits.length) {
            return Container(
              margin: EdgeInsets.symmetric(horizontal: 20),
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(width: 1, color: Colors.black12))
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SizedBox(
                    width: MediaQuery.of(context).size.width * 0.45,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(credits[index]['description'], style: GoogleFonts.rubik(
                        color: AppColors.k010101,
                        fontSize: 15,
                        fontWeight: FontWeight.normal,
                      ),),
                      SizedBox(height: 5,),
                      Text(credits[index]['created_at'], style: GoogleFonts.rubik(
                        color: Colors.grey,
                        fontSize: 14,
                        fontWeight: FontWeight.normal,
                      ),),
                    ],),
                  ),
                  Row(children: [
                    Text(
                      credits[index]['point'].toString(),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.rubik(
                        color: int.parse(credits[index]['point'].toString()) > 0 ?AppColors.k0cbcc5 : AppColors.ke63030,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '(${credits[index]['type']})',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.rubik(
                        color: int.parse(credits[index]['point'].toString()) > 0 ? AppColors.k0cbcc5 : AppColors.ke63030,
                        fontSize: 14,
                        fontWeight: FontWeight.normal,
                      ),
                    )
                  ],)
                ],
              ),
            );
          }

          if (_loading && _currentPage > 1) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CupertinoActivityIndicator()),
            );
          }

          if (!_hasMore) {
            return Padding(
              padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 32),
              child: Center(child: Text('—— ${S.of(context).no_more_credit_data} ——', style: GoogleFonts.rubik(
                color: Colors.grey,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ))),
            );
          }

          return const SizedBox.shrink();
        },
        itemCount: credits.length+1
      ));
    }

    if (_loaded && credits.isEmpty) {
      return Expanded(child: Center(child: Text(
        S.of(context).no_credit_data,
        textAlign: TextAlign.center,
        style: GoogleFonts.rubik(
          color: AppColors.k808080,
          fontSize: 14,
          fontWeight: FontWeight.normal,
        ),
      ),));
    }

    return Offstage();
  }

  Widget _buildActionView() {
    if(!_loaded) return Offstage();
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 15),
      child: MaterialButton(
        onPressed: () async {
          final result = await Navigator.push(context, MaterialPageRoute(
            builder: (context) => CreditsTransfer(),
          ),);
          if (result == true) {
            setState(() {
              _loaded = false;
              _loading = false;
              _currentPage = 1;
              _hasMore = true;
              credits = [];
            });
            await _getCredits();
          }
        },
        minWidth: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        color: AppColors.k0cbcc5,
        child: Text(S.of(context).credit_transfer, style: GoogleFonts.rubik(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        )),
      ),
    );
  }

  void _showCustomPointsRuleDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9, // 占屏幕90%宽度
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.card_giftcard, color: AppColors.k0cbcc5, size: 18),
                  const SizedBox(width: 8),
                  Text(S.of(context).point_rule, style: GoogleFonts.rubik(
                    color: AppColors.k0cbcc5,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ))
                ],
              ),
              const Divider(height: 20, thickness: 1),
              // 规则内容（可滚动）
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 积分来源
                      Text(S.of(context).point_source, style: GoogleFonts.rubik(
                        color: AppColors.k0cbcc5,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      )),
                      SizedBox(height: 8),
                      Text('• '+S.of(context).point_from_product_view(rules['product_view_reward_points'].toString(), rules['product_view_time_threshold'].toString(), rules['product_point_cooldown_days'].toString()), style: GoogleFonts.rubik(
                        fontSize: 14,
                        fontWeight: FontWeight.normal,
                      )),
                      SizedBox(height: 4),
                      Text('• '+S.of(context).point_from_bind_emergency(rules['invitation_reward_points'].toString()), style: GoogleFonts.rubik(
                        fontSize: 14,
                        fontWeight: FontWeight.normal,
                      )),
                      SizedBox(height: 4),
                      Text('• '+S.of(context).point_from_invitation(rules['invitation_reward_points'].toString()), style: GoogleFonts.rubik(
                        fontSize: 14,
                        fontWeight: FontWeight.normal,
                      )),
                      SizedBox(height: 16),
                      Text(S.of(context).point_usage_rule, style: GoogleFonts.rubik(
                        color: AppColors.k0cbcc5,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      )),
                      SizedBox(height: 8),
                      Text('• '+S.of(context).point_deduction_rule(rules['max_deduction_ratio'].toString()), style: GoogleFonts.rubik(
                        fontSize: 14,
                        fontWeight: FontWeight.normal,
                      )),
                      SizedBox(height: 4),
                      Text('• '+S.of(context).point_return_rule, style: GoogleFonts.rubik(
                        fontSize: 14,
                        fontWeight: FontWeight.normal,
                      )),
                      SizedBox(height: 16),
                      // 其他说明
                      Text(S.of(context).point_other_instruction, style: GoogleFonts.rubik(
                        color: AppColors.k0cbcc5,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      )),
                      SizedBox(height: 8),
                      Text('• '+S.of(context).point_other_instruction1, style: GoogleFonts.rubik(
                        fontSize: 14,
                        fontWeight: FontWeight.normal,
                      )),
                      SizedBox(height: 4),
                      Text('• '+S.of(context).point_other_instruction2, style: GoogleFonts.rubik(
                        fontSize: 14,
                        fontWeight: FontWeight.normal,
                      )),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // 关闭按钮
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.k0cbcc5,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text('我知道了', style: GoogleFonts.rubik(
                    fontSize: 14,
                    fontWeight: FontWeight.normal,
                    color: AppColors.kffffff
                  )),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
