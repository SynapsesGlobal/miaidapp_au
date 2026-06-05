import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:miaid/view/marketing/product_detail.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../api_utils/api_provider.dart';
import '../../api_utils/consts.dart';
import '../../api_utils/http_exception.dart';
import '../../component/nav_bar_icons.dart';
import '../../config/app_colors.dart';
import '../../generated/l10n.dart';
import '../../utils/configure_dependencies.dart';
import 'package:http/http.dart' as http;
import 'package:map_launcher/map_launcher.dart' as ml;

class OrderDetail extends StatefulWidget {
  final String orderId;
  const OrderDetail({super.key, required this.orderId});

  @override
  State<OrderDetail> createState() => _OrderDetailState();
}

class _OrderDetailState extends State<OrderDetail> {

  Map<String, dynamic> detail = {};

  Future<void> _getOrderDtl() async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'x-api-key': Consts.marketingApiKey,
    };

    await EasyLoading.show(
      status: 'Loading',
      maskType: EasyLoadingMaskType.black,
    );

    try {
      final api = getIt<ApiProvider>();
      final url = Uri.parse(Consts.marketingApiHost+'/order/detail').replace(queryParameters: {
        'userId': api.userProvider.user?.id.toString(),
        'orderId': widget.orderId
      });
      final response = await http.get(url, headers: headers);

      await EasyLoading.dismiss();

      if (response.statusCode == 200) {
        var responseData = jsonDecode(response.body);
        setState(() => detail = responseData);
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
    _getOrderDtl();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        automaticallyImplyLeading: false,
        elevation: 0,
        backgroundColor: AppColors.kffffff,
        centerTitle: true,
        title: Text(
          '${S.of(context).order_detail}',
          style: GoogleFonts.rubik(
            color: AppColors.k010101,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        leading: Builder(
          builder: (BuildContext context) => InkWell(
            onTap: () {
              Navigator.pop(context);
            },
            child: navBarIcon(iconAssetName: 'ic_nb_back.png'),
          ),
        ),
      ),
      body: detail.isNotEmpty ? SingleChildScrollView(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildOrderBriefLayout(),
          SizedBox(height: 8),
          ...List.generate(detail['products'].length, (pIndex) {
            final product = detail['products'][pIndex];
            return _buildOrderItemLayout(product);
          }),
          _buildPaymentDetails(),
          _buildHelpSection(),
          SizedBox(height: 50,)
        ],
      ),) : Offstage(),
    );
  }

  Widget _buildOrderItemLayout(dynamic product) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      elevation: 0,
      child: Padding(
        padding: EdgeInsets.all(8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                height: 100,
                width: 100,
                fit: BoxFit.cover,
                imageUrl: product['image'],
              ),
            ),
            SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product['title'], style: GoogleFonts.rubik(
                  color: AppColors.k010101,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                )),
                SizedBox(height: 4),
                Text(
                  product['description'],
                  style: GoogleFonts.rubik(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 4,),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(children: [
                      Text(product['currency'], style: GoogleFonts.rubik(
                        color: AppColors.k0cbcc5,
                        fontSize: 14,
                        fontWeight: FontWeight.normal,
                      )),
                      SizedBox(width: 3,),
                      Text(product['price'].toString(), style: GoogleFonts.rubik(
                        color: AppColors.k0cbcc5,
                        fontSize: 14,
                        fontWeight: FontWeight.normal,
                      ))
                    ],),
                    Text('x '+product['quantity'].toString(), style: GoogleFonts.rubik(
                      color: AppColors.k0cbcc5,
                      fontSize: 14,
                      fontWeight: FontWeight.normal,
                    ))
                  ],
                ),
              ],
            ),),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderBriefLayout() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      color: AppColors.k0cbcc5,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildOrderStatus(detail),
          SizedBox(height: 8),
          Text('${S.of(context).order_date}: '+detail['created_at'], style: GoogleFonts.rubik(
              color: Colors.white
          ),),
          detail['status'].toString() == '3' ? SizedBox(height: 8) : Offstage(),
          detail['status'].toString() == '3' && detail['refund_date'] != null ? Text('${S.of(context).refund_date}: '+detail['refund_date'], style: GoogleFonts.rubik(
              color: Colors.white
          ),) : Offstage(),
          SizedBox(height: 5,),
          Text('#'+detail['orderNbr'], style: GoogleFonts.rubik(
            color: Colors.white,
          ),),
        ],
      ),
    );
  }

  // Payment Details Section
  Widget _buildPaymentDetails() {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      elevation: 0,
      child: Padding(
        padding: EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${S.of(context).payment_detail}', style: GoogleFonts.rubik(
                fontWeight: FontWeight.w500,
                fontSize: 14
            )),
            Divider(color: Colors.grey[200],),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${S.of(context).total_amount}', style: GoogleFonts.rubik(color: Colors.grey[600])),
                Row(children: [
                  Text(detail['currency'], style: GoogleFonts.rubik(
                      fontSize: 14,
                      fontWeight: FontWeight.bold
                  )),
                  SizedBox(width: 4,),
                  Text(detail['amount'].toString(), style: GoogleFonts.rubik(
                    color: AppColors.k010101,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ))
                ],),
              ],
            ),
            SizedBox(height: 6,),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${S.of(context).payment_method}', style: GoogleFonts.rubik(color: Colors.grey[600])),
                Row(children: [
                  Icon(Icons.credit_card, size: 18, color: Colors.grey),
                  SizedBox(width: 5),
                  Text('${S.of(context).credit_card}', style:GoogleFonts.rubik(color: Colors.grey)),
                ],),
              ],
            )
          ],
        ),
      ),
    );
  }

  // Help Section
  Widget _buildHelpSection() {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      elevation: 0,
      child: Padding(
        padding: EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${S.of(context).need_help}', style: GoogleFonts.rubik(
                fontWeight: FontWeight.w500,
                fontSize: 14
            )),
            Divider(color: Colors.grey[200],),
            InkWell(
              onTap: (){
                var company = detail['company'];
                showModalBottomSheet(
                  context: context,
                  isDismissible: false,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  builder: (BuildContext context) => Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(16),
                    height: 320,
                    child: Column(children: [
                      Align(
                        alignment: Alignment.centerRight,
                        child: InkWell(
                          onTap: ()=> Navigator.of(context).pop(),
                          child: Icon(Icons.close, color: Colors.grey,),
                        ),
                      ),
                      SizedBox(height: 5,),
                      Divider(color: Colors.grey[200],),
                      SizedBox(height: 5,),
                      Row(children: [
                        ClipOval(child: CachedNetworkImage(
                          height:  MediaQuery.of(context).size.width*0.25,
                          width: MediaQuery.of(context).size.width*0.25,
                          fit: BoxFit.cover,
                          imageUrl: company['image'],
                        ),),
                        SizedBox(width: 10,),
                        SizedBox(
                          width: MediaQuery.of(context).size.width*0.60,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(company['name'], style: GoogleFonts.rubik(
                                color: AppColors.k010101,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),),
                              SizedBox(height: 8),
                              Text(company['phone'], style: GoogleFonts.rubik(
                                color: AppColors.k010101,
                                fontSize: 14,
                                fontWeight: FontWeight.normal,
                              ),),
                              SizedBox(height: 2),
                              Text(company['address'], style: GoogleFonts.rubik(
                                color: Colors.grey,
                                fontSize: 14,
                                fontWeight: FontWeight.normal,
                              ),),
                              SizedBox(height: 2),
                              Text(company['website'] ?? '', style: GoogleFonts.rubik(
                                color: AppColors.k010101,
                                fontSize: 14,
                                fontWeight: FontWeight.normal,
                              ),)
                            ],
                          ),
                        )
                      ],),
                      Divider(color: Colors.grey[200],),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Expanded(child: MaterialButton(
                            padding: EdgeInsets.symmetric(vertical: 6),
                            shape:
                            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            onPressed: () async {
                              final availableMaps = await ml.MapLauncher.installedMaps;
                              if (availableMaps.isNotEmpty) {
                                await availableMaps.first.showMarker(
                                    coords: ml.Coords(company['latitude'], company['longitude']),
                                    title: company['name'],
                                    description: company['address']
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(S.of(context).installMap),),
                                );
                              }
                            },
                            color: AppColors.k0cbcc5,
                            child: Text(S.of(context).getDirection, style: GoogleFonts.rubik(color: Colors.white),),
                          )),
                          SizedBox(width: 10,),
                          Expanded(child: MaterialButton(
                            padding: EdgeInsets.symmetric(vertical: 6),
                            shape:
                            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            onPressed: () {
                              if (company['phone'] != null) {
                                launch('tel://${company['phone']}');
                              }
                            },
                            color: AppColors.k0cbcc5,
                            child: Text('拨打电话', style: GoogleFonts.rubik(color: Colors.white),),
                          ))
                        ],
                      ),
                      SizedBox(height: 10,),
                      Text('注意： 想要获取路线请首先在您的手机上安装导航工具，比如苹果地图、谷歌地图、百度地图、高德地图等', style: GoogleFonts.rubik(
                        color: Colors.grey,
                        fontSize: 14,
                        fontWeight: FontWeight.normal,
                      ),),
                    ],),
                  ),
                );
              },
              child: Row(children: [
                Icon(Icons.chat, color: Colors.grey),
                SizedBox(width: 6),
                Expanded(child: Text('${S.of(context).contact_shop}')),
                Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
              ],),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildOrderStatus(dynamic  detail) {
    var status = detail['status'].toString();
    if (status == '1') return Text(S.of(context).paid, style: GoogleFonts.rubik(color: AppColors.kffffff, fontSize: 20, fontWeight: FontWeight.bold));
    if (status == '2') return Text(S.of(context).refunding, style: GoogleFonts.rubik(color: AppColors.kffffff, fontSize: 20, fontWeight: FontWeight.bold));
    if (status == '3') return Text(S.of(context).refunded, style: GoogleFonts.rubik(color: AppColors.kffffff, fontSize: 20, fontWeight: FontWeight.bold));
    if (status == '4') {
      return Row(children: [
        Text('${S.of(context).refused}', style: GoogleFonts.rubik(color: AppColors.kffffff, fontSize: 20, fontWeight: FontWeight.bold)),
        SizedBox(width: 5,),
        detail['reject_reason'] != null ? SizedBox(
          width: MediaQuery.of(context).size.width * 0.6,
          child: Text('(${detail['reject_reason']})', style: GoogleFonts.rubik(color: AppColors.kffffff, fontSize: 15)),
        ) : Offstage()
      ],);
    }
    return Offstage();
  }
}
