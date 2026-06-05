import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

import '../../api_utils/consts.dart';
import '../../api_utils/http_exception.dart';
import '../../component/nav_bar_icons.dart';
import '../../config/app_colors.dart';
import '../../generated/l10n.dart';

class SubCategories extends StatefulWidget {
  final String mainCateId;
  final String mainCateTitle;
  const SubCategories({super.key, required this.mainCateId, required this.mainCateTitle});

  @override
  State<SubCategories> createState() => _SubCategoriesState();
}

class _SubCategoriesState extends State<SubCategories> {
  String no_data = '';
  List categories = [];

  Future<void> _getSubCategories() async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'x-api-key': Consts.marketingApiKey,
    };

    await EasyLoading.show(
      status: 'Loading',
      maskType: EasyLoadingMaskType.black,
    );

    try {
      final url = Uri.parse(Consts.marketingApiHost+'/categories/sub').replace(queryParameters: {
        'mainCateId': widget.mainCateId.toString(),
      });;
      final response = await http.get(url, headers: headers,);

      await EasyLoading.dismiss();

      if (response.statusCode == 200) {
        var responseData = jsonDecode(response.body)['subCategories'];
        setState(() {
          categories = responseData;
          no_data = responseData.length > 0 ? '' : 'No data available.';
        });
      } else {
        await EasyLoading.dismiss();
        await HttpExceptionNotifyUser.showInfo(S.of(context).somethingWentWrong);
      }
    } catch (e) {
      await EasyLoading.dismiss();
    }
  }

  @override
  void initState() {
    super.initState();
    _getSubCategories();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        elevation: 0,
        backgroundColor: AppColors.kffffff,
        centerTitle: true,
        title: Text(widget.mainCateTitle, style: GoogleFonts.rubik(
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
      body: categories.isNotEmpty ? MasonryGridView.count(
        padding: EdgeInsets.all(10),
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        itemCount: categories.length,
        itemBuilder: (context, index) => InkWell(
          onTap: (){

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
                  imageUrl: categories[index]['subImg'],
                ),
                SizedBox(height: 8),
                Text(
                  categories[index]['subCate'],
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ) : Center(child: Text(no_data, style: GoogleFonts.rubik(
      color: Colors.grey,
      fontSize: 14,
      fontWeight: FontWeight.normal,
    )),),
    );
  }
}




