import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:miaid/view/chatbot/chartbot.dart';
import 'package:miaid/view/chatbot/chatbot_history_dtl.dart';

import '../../api_utils/api_provider.dart';
import '../../api_utils/http_exception.dart';
import '../../component/nav_bar_icons.dart';
import '../../config/app_colors.dart';
import '../../generated/l10n.dart';
import 'package:http/http.dart' as http;

import '../../utils/configure_dependencies.dart';
import 'package:miaid/config/api_settings.dart';

class ChatbotHistory extends StatefulWidget {
  final dynamic services;
  const ChatbotHistory({super.key, required this.services});

  @override
  State<ChatbotHistory> createState() => _ChatbotHistoryState();
}

class _ChatbotHistoryState extends State<ChatbotHistory> {
  List histories = [];
  bool _loading = false;
  Map<dynamic, String> _formattedTimes = {};

  @override
  void initState() {
    super.initState();
    _getHistoryChats();
  }

  Future<void> _getHistoryChats() async {
    final headers = <String, String>{
      'X-Custom-Token': getIt<ApiSettings>().chatBotApiToken
    };

    final api = getIt<ApiProvider>();
    var userId = api.userProvider.user!.id.toString();
    final requestBody = <String, dynamic>{
      'userId': userId + '_au',
    };

    try {
      _loading = true;
      await EasyLoading.show(
        status: 'Loading...',
        maskType: EasyLoadingMaskType.black,
      );

      final url = Uri.parse(getIt<ApiSettings>().chatBotApiHost + '/app/chat_history');
      final response = await http.post(url, headers: headers, body: requestBody);

      if (response.statusCode == 200) {
        var responseData = jsonDecode(utf8.decode(response.bodyBytes));
        List chatList = responseData['data'];
        final formattedTimes = _convertTimes(chatList);

        setState(() {
          histories = chatList;
          _formattedTimes = formattedTimes;
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
        await HttpExceptionNotifyUser.showInfo(S.of(context).somethingWentWrong);
      }
    } catch (e) {
      setState(() => _loading = false);
      debugPrint('$e');
    } finally {
      await EasyLoading.dismiss();
    }
  }

  Map<dynamic, String> _convertTimes(List chatList) {
    final result = <dynamic, String>{};
    for (var item in chatList) {
      try {
        final localTime = DateTime.parse(item['created_at']).toLocal();
        result[item['id']] = DateFormat('yyyy-MM-dd HH:mm').format(localTime);
      } catch (e) {
        debugPrint('时间转换失败: $e');
        result[item['id']] = item['created_at'] ?? '';
      }
    }
    return result;
  }

  Future<void> _deleteHistoryChat(String historyId) async {
    final headers = <String, String>{
      'X-Custom-Token': getIt<ApiSettings>().chatBotApiToken
    };

    final requestBody = <String, dynamic>{
      'history_id': historyId.toString(),
    };

    try {
      await EasyLoading.show(
        status: 'Loading...',
        maskType: EasyLoadingMaskType.black,
      );

      var url_path = getIt<ApiSettings>().chatBotApiHost+'/app/del_history/$historyId';
      final url = Uri.parse(url_path);
      final response = await http.delete(url, headers: headers, body: requestBody);
      await EasyLoading.dismiss();
      if (response.statusCode == 200) {
        histories.removeWhere((item) => item['id'] == historyId);
        setState(() => histories);
      } else {
        await HttpExceptionNotifyUser.showInfo(S.of(context).somethingWentWrong);
      }
    } catch (e) {
      await EasyLoading.dismiss();
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
        title: Text(S.of(context).chat_history, style: GoogleFonts.rubik(
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
      body: Column(children: [
        _buildChatListLayout(),
        _buildCreateNewChatLayout()
      ],),
    );
  }

  Widget _buildCreateNewChatLayout() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 15),
      child: MaterialButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => ChatBot(services: widget.services)),
          );

          if (result == true) {
            await _getHistoryChats(); // 重新加载数据
          }
        },
        minWidth: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        color: AppColors.k0cbcc5,
        child: Text(S.of(context).create_new_chat, style: GoogleFonts.rubik(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        )),
      ),
    );
  }

  ///chat list layout
  Widget _buildChatListLayout() {
    return Expanded(child: histories.isNotEmpty ? ListView.separated(
      padding: EdgeInsets.all(20),
      itemBuilder: (content, index) => Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        InkWell(
          onTap: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => ChatBotHistoryDtl(chatDtl: histories[index], services: widget.services)),
            );
            if (result == true) {
              await _getHistoryChats(); // 重新加载数据
            }
          },
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(histories[index]['title'], style: GoogleFonts.rubik(
              color: AppColors.k010101,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            )),
            SizedBox(height: 5,),
            Text(_formattedTimes[histories[index]['id']] ?? '', style: GoogleFonts.rubik(
              color: Colors.grey,
              fontSize: 14,
              fontWeight: FontWeight.normal,
            ),)
          ],),
        ),
        InkWell(
          child: Icon(Icons.delete_rounded, color: AppColors.k0cbcc5,),
          onTap: (){
            var historyId = histories[index]['id'].toString();
            showAlertDialog(context, historyId);
          },
        ),
      ],),
      separatorBuilder: (context, index) => Divider(color: Colors.grey[200],),
      itemCount: histories.length
    ) : Center(child: _loading ? Offstage() : Text(S.of(context).no_more_chats),));
  }

  void showAlertDialog(BuildContext context, String historyId) {
    Widget okButton = Padding(
      padding: EdgeInsets.only(left: 64.5, right: 63.5, bottom: 24.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: MediaQuery.of(context).size.width,
            height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: AppColors.k0cbcc5.withOpacity(0.2),
                  blurRadius: 10.0,
                  spreadRadius: 0.0, //extend the shadow
                  offset: Offset(0.0, 4,),
                ),
              ],
            ),
            child: TextButton(
              style: ButtonStyle(
                backgroundColor: MaterialStateProperty.all(AppColors.k0cbcc5),
                shape: MaterialStateProperty.all(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9),
                  ),
                ),
              ),
              onPressed: () => Navigator.pop(context),
              child: Text(S.of(context).no, style: GoogleFonts.rubik(
                color: AppColors.kffffff,
                fontSize: 14,
              ),),
            ),
          ),
          Center(child: TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(S.of(context).yes, style: GoogleFonts.rubik(
              color: AppColors.k0cbcc5,
              fontSize: 14,
            ),),
          ),),
        ],
      ),
    );
    var alert = AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      title: Text(
        S.of(context).delete_chat,
        textAlign: TextAlign.center,
        style: GoogleFonts.rubik(
          color: AppColors.k010101,
          fontWeight: FontWeight.w600,
          fontSize: 16
        ),
      ),
      content: Text(
        S.of(context).delete_chat_confirmation,
        textAlign: TextAlign.center,
        style: GoogleFonts.rubik(
          fontSize: 13,
        ),
      ),
      actions: [okButton],
    );

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return alert;
      }
    ).then((value) async {
      if (value ?? false) {
        await _deleteHistoryChat(historyId);
      }
    });
  }
}

