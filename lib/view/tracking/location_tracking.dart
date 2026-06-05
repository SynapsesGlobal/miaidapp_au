import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:miaid/utils/utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../api_utils/api_provider.dart';
import '../../api_utils/http_exception.dart';
import '../../component/nav_bar_icons.dart';
import '../../config/app_colors.dart';
import '../../generated/l10n.dart';
import '../../location/background_location_service.dart';
import '../../store/home/home_screen_store.dart';
import '../../utils/configure_dependencies.dart';

import 'dart:convert';
import 'package:http/http.dart' as http;

class LocationTracking extends StatefulWidget {
  const LocationTracking({super.key});

  @override
  State<LocationTracking> createState() => _LocationTrackingState();
}

class _LocationTrackingState extends State<LocationTracking> {
  bool _open = false;
  final TextEditingController _controller = TextEditingController();
  int _frequency = 1;
  final formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _getPositionSetting();
  }

  Future<void> _getPositionSetting() async {
    final api = getIt<ApiProvider>();
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'x-user-id': api.userProvider.user!.id.toString(),
      'x-api-key': api.apiKey,
    };

    await EasyLoading.show(
      status: 'Loading...',
      maskType: EasyLoadingMaskType.black,
    );

    try {
      final url = Uri.parse(api.baseUrl+'/api/v1/position/index');
      final response = await http.post(url, headers: headers,);
      await EasyLoading.dismiss();

      if (response.statusCode == 200) {
        var responseData = jsonDecode(response.body)['payload'];
        var opened = responseData['open_position_tracking'].toString();
        var sharedPreferences = await SharedPreferences.getInstance();
        await sharedPreferences.setBool('open_position_tracking', _open);
        setState(() {
          _open = opened == '1' ? true : false;
          _controller.text = opened == '1' ? responseData['tracking_email'] : '';
          _frequency = opened == '1' ? int.parse(responseData['tracking_frequency']) : 1;
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
        title: Text(S.of(context).positionTracking, style: GoogleFonts.rubik(
          color: AppColors.k010101,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),),
        leading: Builder(
          builder: (BuildContext context) => InkWell(
            onTap: () {
              Navigator.pop(context);
            },
            child: navBarIcon(iconAssetName: 'ic_nb_back.png'),
          ),
        ),
      ),
      body: SingleChildScrollView(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            dense: true,
            leading: Icon(Icons.location_on, color: AppColors.k0cbcc5),
            title: Text(S.of(context).open_location_tracking, style: GoogleFonts.rubik(
              color: Colors.black,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),),
            trailing: Transform.scale(
              scale: 0.9,
              child: Switch(
                value: _open,
                activeColor: AppColors.k0cbcc5,
                inactiveTrackColor: Colors.grey[200],
                onChanged: (value) => setState(() {
                  _open = !_open;
                }),
              ),
            ),
          ),
          _open ? Padding(padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10), child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Divider(color: Colors.black12,),
              SizedBox(height: 10,),
              Text(S.of(context).email_receive_location, style: GoogleFonts.rubik(
                color: Colors.grey,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),),
              SizedBox(height: 10,),
              Form(
                key: formKey,
                child:  TextFormField(
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (_open && (_controller.text.isEmpty || !Utils.isValidEmail(_controller.text))) {
                      return S.of(context).entEmail;
                    } else {
                      return null;
                    }
                  },
                  controller: _controller,
                  decoration: InputDecoration(
                    hintText: 'yourname@example.com',
                    hintStyle: TextStyle(
                      color: AppColors.kb1b1b1,
                      fontSize: 14,
                    ),
                    contentPadding: EdgeInsets.only(
                      left: 16,
                      top: 5,
                      bottom: 5,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: AppColors.k010101,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: AppColors.kfa0020,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: AppColors.kb1b1b1,
                        width: 0.5,
                      ),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.red,),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),

              SizedBox(height: 20,),
              Text(S.of(context).email_frequency, style: GoogleFonts.rubik(
                color: Colors.grey,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),),
              SizedBox(height: 10,),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(S.of(context).every_six_hours, style: GoogleFonts.rubik(
                    color: Colors.black,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),),
                  Radio(
                    value: 1,
                    activeColor: AppColors.k0cbcc5,
                    groupValue: _frequency,
                    onChanged: (value)=> setState(() {
                      _frequency = 1;
                    })
                  )
                ],
              ),
              Divider(color: Colors.black12, height: 1,),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(S.of(context).every_twelve_hours, style: GoogleFonts.rubik(
                    color: Colors.black,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),),
                  Radio(
                    value: 2,
                    activeColor: AppColors.k0cbcc5,
                    groupValue: _frequency,
                    onChanged: (value)=> setState(() {
                      _frequency = 2;
                    })
                  )
                ],
              ),
              Divider(color: Colors.black12, height: 1,),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(S.of(context).every_day, style: GoogleFonts.rubik(
                    color: Colors.black,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),),
                  Radio(
                    value: 3,
                    activeColor: AppColors.k0cbcc5,
                    groupValue: _frequency,
                    onChanged: (value)=> setState(() {
                      _frequency = 3;
                    })
                  )
                ],
              ),
              Divider(color: Colors.black12, height: 1,),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(S.of(context).every_week, style: GoogleFonts.rubik(
                    color: Colors.black,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),),
                  Radio(
                    value: 4,
                    groupValue: _frequency,
                    activeColor: AppColors.k0cbcc5,
                    onChanged: (value)=> setState(() {
                      _frequency = 4;
                    })
                  ),
                ],
              ),
              SizedBox(height: 20,),
              Text(S.of(context).tracking_instruction, style: GoogleFonts.rubik(
                color: Colors.grey,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),),
            ],
          ),) : Offstage(),
          SizedBox(height: 20,),
          Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: Container(
            width: MediaQuery.of(context).size.width,
            height: 44,
            child: TextButton(
              onPressed: () async {
                if (_open && !formKey.currentState!.validate()) {
                  return;
                }

                final position = await determinePosition(desiredAccuracy: LocationAccuracy.medium);
                final api = getIt<ApiProvider>();

                final data = <String, dynamic>{
                  'tracking_email':_open ? _controller.text : '',
                  'open_position_tracking': _open ? 1 : 0,
                  'tracking_frequency': _open ? _frequency : 0,
                  'latitude': position.latitude,
                  'longitude': position.longitude,
                };

                final headers = <String, String>{
                  'Content-Type': 'application/json',
                  'x-access-token': api.userProvider.user!.accessToken!,
                  'x-user-id': api.userProvider.user!.id.toString(),
                  'x-api-key': api.apiKey,
                };

                await EasyLoading.show(
                  status: 'Submitting',
                  maskType: EasyLoadingMaskType.black,
                );

                try {
                  final url = Uri.parse(api.baseUrl+'/api/v1/position/setting');
                  final response = await http.post(
                    url,
                    headers: headers,
                    body: jsonEncode(data),
                  );
                  await EasyLoading.dismiss();

                  if (response.statusCode == 200 ) {
                    await BackgroundLocationService.sendPositionToBackend();
                    await HttpExceptionNotifyUser.showInfo(S.of(context).setup_success);
                  } else {
                    await HttpExceptionNotifyUser.showInfo(S.of(context).somethingWentWrong);
                  }
                } catch (e) {
                  await EasyLoading.dismiss();
                  await HttpExceptionNotifyUser.showInfo(S.of(context).somethingWentWrong);
                }
              },
              style: TextButton.styleFrom(
                backgroundColor: AppColors.k0cbcc5,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
              child: Text(S.of(context).confirm),
            ),
          ),)
        ],
      ),),
    );
  }
}
