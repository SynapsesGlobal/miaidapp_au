import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:miaid/view/marketing/company_products.dart';

import '../../api_utils/consts.dart';
import '../../api_utils/http_exception.dart';
import '../../component/nav_bar_icons.dart';
import '../../config/app_colors.dart';
import 'package:http/http.dart' as http;

import '../../generated/l10n.dart';
import '../../store/home/home_screen_store.dart';

class Companies extends StatefulWidget {
  final int categoryId;
  final String category;
  const Companies({super.key, required this.categoryId, required this.category});

  @override
  State<Companies> createState() => _CompaniesState();
}

class _CompaniesState extends State<Companies> {
  List companies = [];
  String no_data = '';
  String keywords = '';
  final TextEditingController _controller = TextEditingController();

  Future<void> _getCompanies() async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'x-api-key': Consts.marketingApiKey,
    };

    await EasyLoading.show(
      status: 'Loading',
      maskType: EasyLoadingMaskType.black,
    );

    try {
      final position = await determinePosition(desiredAccuracy: LocationAccuracy.medium);
      final url = Uri.parse(Consts.marketingApiHost+'/companies').replace(queryParameters: {
        'mainCateId': widget.categoryId.toString(),
        'latitude': position.latitude.toString(),
        'longitude': position.longitude.toString(),
        'keywords': keywords
      });
      final response = await http.get(url, headers: headers);

      await EasyLoading.dismiss();

      if (response.statusCode == 200) {
        print(response.body);
        var responseData = jsonDecode(response.body)['companies'];
        setState(() {
          companies = responseData;
          no_data = responseData.length > 0 ? '' : 'No data available.';
        });
      } else {
        await EasyLoading.dismiss();
        await HttpExceptionNotifyUser.showInfo(S.of(context).somethingWentWrong);
      }
    } catch (e) {
      print(e.toString());
      await EasyLoading.dismiss();
    }
  }

  @override
  void initState() {
    super.initState();
    _getCompanies();
  }

  @override
  void dispose() {
    _controller.dispose();
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
        title: Text(widget.category, style: GoogleFonts.rubik(
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
      body: Column(children: [
        _buildSearch(),
        Expanded(child: _buildListView())
      ],),
    );
  }

  Widget _buildListView() {
    return companies.isNotEmpty ? MasonryGridView.count(
      shrinkWrap: true,
      padding: EdgeInsets.all(10),
      crossAxisCount: 2,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      itemCount: companies.length,
      itemBuilder: (context, index) => InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute<void>(
          builder: (context) => CompanyProducts(company: companies[index]),
        ),),
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
                imageUrl: companies[index]['image'],
              ),
              SizedBox(height: 8),
              Text(companies[index]['name'], style: GoogleFonts.rubik(
                color: AppColors.k010101,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),),
              SizedBox(height: 8),
              Text(companies[index]['phone'], textAlign: TextAlign.center, style: GoogleFonts.rubik(
                color: AppColors.k010101,
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),),
              SizedBox(height: 8),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Text(companies[index]['address'], textAlign: TextAlign.center, style: GoogleFonts.rubik(
                  color: Colors.grey,
                  fontSize: 14,
                  fontWeight: FontWeight.normal,
                ),),
              ),
            ],
          ),
        ),
      ),
    ) : Center(child: Text(no_data, style: GoogleFonts.rubik(
      color: Colors.grey,
      fontSize: 14,
      fontWeight: FontWeight.normal,
    )),);
  }

  /// Search widget
  Widget _buildSearch() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(10),
      child: TextField(
        controller: _controller,
        decoration: InputDecoration(
          contentPadding: EdgeInsets.all(2),
          hintText: S.of(context).keywords,
          hintStyle: TextStyle(fontSize: 14),
          prefixIcon: Icon(Icons.search, color: AppColors.k0cbcc5,),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.black12),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: AppColors.k0cbcc5, width: 1),
          ),
          suffixIcon: _controller.text.isNotEmpty ? InkWell(
            onTap: (){
              _controller.text = '';
              setState(() => keywords = '');
              _getCompanies();
            },
            child: Icon(Icons.close, size: 20, color: Colors.grey,),
          ) : null
        ),
        onChanged: (value) => setState(() => keywords = value),
        textInputAction: TextInputAction.search,
        keyboardType: TextInputType.text,
        onSubmitted: (value) {
          setState(() => keywords = value);
          _getCompanies();
        },
      ),
    );
  }
}
