import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:miaid/api_utils/consts.dart';
import 'package:miaid/view/marketing/category_airline.dart';
import 'package:miaid/view/marketing/companies.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:miaid/view/marketing/orders.dart';
import 'package:miaid/view/marketing/wishes.dart';

import '../../api_utils/http_exception.dart';
import '../../component/nav_bar_icons.dart';
import '../../config/app_colors.dart';
import '../../generated/l10n.dart';
import 'package:miaid/config/api_settings.dart';
import 'package:miaid/utils/configure_dependencies.dart';

class MarketingCategory extends StatefulWidget {
  const MarketingCategory({super.key});

  @override
  State<MarketingCategory> createState() => _MarketingCategoryState();
}

class _MarketingCategoryState extends State<MarketingCategory> {
  List categories = [];

  Future<void> _getMarketingCategories() async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'x-api-key': getIt<ApiSettings>().marketingApiKey,
    };

    await EasyLoading.show(
      status: 'Loading',
      maskType: EasyLoadingMaskType.black,
    );

    try {
      final url = Uri.parse(getIt<ApiSettings>().marketingApiHost+'/categories/main');
      final response = await http.get(url, headers: headers,);

      await EasyLoading.dismiss();

      var responseData = jsonDecode(response.body);
      if (response.statusCode == 200) {
        setState(() => categories = responseData['mainCategories']);
      } else {
        await EasyLoading.dismiss();
        await HttpExceptionNotifyUser.showInfo(responseData['message']);
      }
    } catch (e) {
      await EasyLoading.dismiss();
    }
  }

  @override
  void initState() {
    super.initState();
    _getMarketingCategories();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F9),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        elevation: 0,
        backgroundColor: AppColors.kffffff,
        centerTitle: true,
        title: Text(S.of(context).marketing, style: GoogleFonts.rubik(
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
          Tooltip(
            message: 'My orders',
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: ()=> Navigator.push(context, MaterialPageRoute<void>(
                builder: (context) => Orders(),
              ),),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.k0cbcc5.withOpacity(0.12),
                ),
                child: Icon(Icons.receipt_long_outlined, color: AppColors.k0cbcc5, size: 18,),
              ),
            ),
          ),
          SizedBox(width: 10,),
          Tooltip(
            message: 'My wishes',
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: ()=> Navigator.push(context, MaterialPageRoute<void>(
                builder: (context) => Wishes(),
              ),),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.k0cbcc5.withOpacity(0.12),
                ),
                child: Icon(Icons.favorite_border, color: AppColors.k0cbcc5, size: 18),
              ),
            ),
          ),
          SizedBox(width: 12,)
        ],
      ),
      body: MasonryGridView.count(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
        crossAxisCount: 2,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        itemCount: categories.length,
        itemBuilder: (context, index) => _buildCategoryCard(categories[index]),
      ),
    );
  }

  Widget _buildCategoryCard(Map category) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          var slug = category['slug'].toString().toUpperCase();
          if (slug == Consts.MiSpaceAirLine.toString().toUpperCase()) {
            Navigator.push(context, MaterialPageRoute<void>(
              builder: (context) => CategoryAirline(),
            ),);
          } else {
            Navigator.push(context, MaterialPageRoute<void>(
              builder: (context) => Companies(
                categoryId: category['mainCateId'],
                category: category['mainCate']
              ),
            ),);
          }
        },
        child: Stack(
          children: [
            AspectRatio(
              aspectRatio: 4 / 5,
              child: CachedNetworkImage(
                width: double.infinity,
                fit: BoxFit.cover,
                imageUrl: category['mainImg'] ?? '',
                placeholder: (context, url) => Container(
                  color: const Color(0xFFEDEFF2),
                  child: Icon(Icons.category_outlined,
                      size: 36, color: Colors.grey.shade400),
                ),
                errorWidget: (context, url, error) => Container(
                  color: const Color(0xFFEDEFF2),
                  child: Icon(Icons.category_outlined,
                      size: 36, color: Colors.grey.shade400),
                ),
              ),
            ),
            // 底部渐变压暗，保证图上的分类名可读
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.5, 1.0],
                    colors: [Colors.transparent, Colors.black.withOpacity(0.6)],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 12, right: 12, bottom: 12,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      category['mainCate']?.toString() ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.rubik(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.25),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_forward,
                        size: 15, color: Colors.white),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
