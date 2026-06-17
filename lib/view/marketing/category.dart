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
import 'package:miaid/view/marketing/subcategory.dart';
import 'package:miaid/view/marketing/wishes.dart';

import '../../api_utils/http_exception.dart';
import '../../component/nav_bar_icons.dart';
import '../../config/app_colors.dart';
import '../../generated/l10n.dart';
import 'company_products.dart';

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
      'x-api-key': Consts.marketingApiKey,
    };
    print(headers);

    await EasyLoading.show(
      status: 'Loading',
      maskType: EasyLoadingMaskType.black,
    );

    try {
      final url = Uri.parse(Consts.marketingApiHost+'/categories/main');
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
              onTap: ()=> Navigator.push(context, MaterialPageRoute<void>(
                builder: (context) => Orders(),
              ),),
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: AppColors.k0cbcc5
                ),
                child: Icon(Icons.list_alt, color: Colors.white, size: 20,),
              ),
            ),
          ),
          SizedBox(width: 10,),
          Tooltip(
            message: 'My wishes',
            child: InkWell(
              onTap: ()=> Navigator.push(context, MaterialPageRoute<void>(
                builder: (context) => Wishes(),
              ),),
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: AppColors.k0cbcc5
                ),
                child: Icon(Icons.favorite, color: Colors.white, size: 20),
              ),
            ),
          ),
          SizedBox(width: 10,)
        ],
      ),
      body: MasonryGridView.count(
        padding: EdgeInsets.all(10),
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        itemCount: categories.length,
        itemBuilder: (context, index) => InkWell(
          onTap: (){
            var slug = categories[index]['slug'].toString().toUpperCase();
            if (slug == Consts.MiSpaceAirLine.toString().toUpperCase()) {
              Navigator.push(context, MaterialPageRoute<void>(
                builder: (context) => CategoryAirline(),
              ),);
            } else {
              Navigator.push(context, MaterialPageRoute<void>(
                builder: (context) => Companies(categoryId: categories[index]['mainCateId'], category: categories[index]['mainCate']),
              ),);
            }
          },
          child: Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(color: Colors.grey.withOpacity(0.2), blurRadius: 5, spreadRadius: 2),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CachedNetworkImage(
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  imageUrl: categories[index]['mainImg'],
                ),
                SizedBox(height: 8),
                Text(
                  categories[index]['mainCate'],
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}