// ignore: library_prefixes
import 'dart:io';
import 'package:agora_rtc_engine/rtc_remote_view.dart' as RtcRemoteView;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart' as pick;
import 'package:injectable/injectable.dart';
import 'package:intl/intl.dart';
import 'package:miaid/component/nav_bar_icons.dart';
import 'package:miaid/config/app_colors.dart';
import 'package:miaid/generated/l10n.dart';
import 'package:miaid/store/user/calling/ongoing_call_store.dart';
import 'package:miaid/store/user/chat/chat_screen_store.dart';
import 'package:mime/mime.dart';
import 'package:tap_debouncer/tap_debouncer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cometchat/cometchat_sdk.dart';
import 'package:cometchat/cometchat_sdk.dart' as cometchat;

class ChatScreenParams {
  const ChatScreenParams(this.key);

  final Key key;
}

@injectable
class ChatScreenServices {
  ChatScreenServices(this.store, this.ongoingCallStore);

  final ChatScreenStore store;
  final OngoingCallStore ongoingCallStore;
}

@injectable
class ChatScreen extends StatefulWidget {
  ChatScreen({
    @factoryParam this.params,
    required this.services,
  }) : super(key: params?.key);

  final ChatScreenParams? params;
  final ChatScreenServices services;

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final dateFormat = DateFormat.jm();

  final sendMessageController = TextEditingController();

  @override
  void initState() {
    widget.services.store.resetRemoteVideoPosition();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) {
        widget.services.store.scrollMessagesToBottom();
      },
    );
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.services.store;

    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        body: Stack(
          children: [
            Positioned(
              top: 0,
              child: Container(
                width: MediaQuery.of(context).size.width,
                height: MediaQuery.of(context).size.height,
                child: Column(
                  children: [
                    AppBar(
                      backgroundColor: Colors.white,
                      elevation: 0,
                      leading: InkWell(
                        onTap: () {
                          Navigator.pop(context);
                        },
                        child: Padding(
                          padding: const EdgeInsets.only(top: 10, left: 13),
                          child: navBarIcon(iconAssetName: 'ic_nb_back.png'),
                        ),
                      ),
                      title: Text(
                        S.of(context).chat,
                        style: GoogleFonts.rubik(
                          color: AppColors.k010101,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      centerTitle: true,
                    ),
                    Expanded(
                      child: Observer(
                        builder: (context) => ListView(
                          controller: store.scrollController,
                          shrinkWrap: true,
                          physics: ClampingScrollPhysics(),
                          children: [
                            Align(
                              alignment: Alignment.topCenter,
                              child: Text(
                                S.of(context).today,
                                style: GoogleFonts.rubik(
                                  fontSize: 12,
                                  color: AppColors.kb1b1b1,
                                ),
                              ),
                            ),
                            SizedBox(height: 18),
                            ...[
                              for (final groupedMessage in store.messages)
                                ...groupedMessageWidgets(groupedMessage)
                            ],
                            SizedBox(height: 80),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                color: AppColors.kffffff,
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: sendMessageController,
                        autofocus: false,
                        decoration: InputDecoration(
                          contentPadding: EdgeInsets.only(bottom: 10, left: 20),
                          border: InputBorder.none,
                          hintText: S.of(context).typeAMessage,
                          hintStyle: GoogleFonts.sourceSerifPro(
                            fontSize: 15,
                            color: AppColors.k808080.withOpacity(0.8),
                            fontWeight: FontWeight.w300,
                          ),
                          filled: true,
                          fillColor: Colors.transparent,
                        ),
                        maxLines: null,
                        keyboardType: TextInputType.multiline,
                      ),
                    ),
                    SizedBox(
                      width: 5,
                    ),
                    TapDebouncer(
                      onTap: () async {
                        await pickFile();
                      },
                      builder: (context, onTap) => InkWell(
                        onTap: onTap,
                        child: Image(
                          image: AssetImage(
                            'assets/images/ic_chat_attachments.png',
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 5,
                    ),
                    InkWell(
                      onTap: () {
                        final action = CupertinoActionSheet(
                          message: Text(
                            S.of(context).select,
                            style: TextStyle(
                              fontSize: 13.0,
                              color: AppColors.k8f8e94,
                            ),
                          ),
                          actions: <Widget>[
                            CupertinoActionSheetAction(
                              isDefaultAction: true,
                              onPressed: () async {
                                await pickPicture(pick.ImageSource.camera);
                              },
                              child: Text(
                                S.of(context).camera,
                                style: GoogleFonts.rubik(
                                  color: AppColors.k0cbcc5,
                                  fontSize: 20,
                                  fontWeight: FontWeight.normal,
                                ),
                              ),
                            ),
                            CupertinoActionSheetAction(
                              isDestructiveAction: true,
                              onPressed: () async {
                                await pickPicture(pick.ImageSource.gallery);
                              },
                              child: Text(
                                S.of(context).chooseFromAlbums,
                                style: GoogleFonts.rubik(
                                  color: AppColors.k0cbcc5,
                                  fontSize: 20,
                                ),
                              ),
                            )
                          ],
                          cancelButton: CupertinoActionSheetAction(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            child: Text(
                              S.of(context).cancel,
                              style: GoogleFonts.rubik(
                                color: AppColors.k0cbcc5,
                                fontSize: 20,
                              ),
                            ),
                          ),
                        );
                        showCupertinoModalPopup(
                            context: context, builder: (context) => action);
                      },
                      child: Image(
                        image: AssetImage('assets/images/ic_chat_camera.png'),
                      ),
                    ),
                    SizedBox(
                      width: 5,
                    ),
                    TapDebouncer(
                      onTap: () async {
                        final text = sendMessageController.text.trim();
                        if (text.isNotEmpty) {
                          sendMessageController.clear();
                          await store.sendMessage(text);
                        }
                        FocusManager.instance.primaryFocus?.unfocus();
                      },
                      builder: (context, onTap) => InkWell(
                        onTap: onTap,
                        child: Image(
                          image: AssetImage('assets/images/ic_chat_send.png'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Observer(
              builder: (context) => _remoteVideo(store),
            ),
            Observer(
              builder: (context) {
                if (store.errorMessage != null) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: Text(
                            S.of(context).error,
                          ),
                          content: Text(store.errorMessage!),
                          actions: [
                            TextButton(
                              onPressed: () {
                                store.clearError(); // 清除错误信息
                                Navigator.of(context).pop(); // 关闭对话框
                              },
                              child: Text(
                                S.of(context).okay,
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  });
                }
                return Container(); // 显示正常内容
              },
            )
          ],
        ),
      ),
    );
  }

  List<Widget> groupedMessageWidgets(GroupedMessages groupedMessage) {
    var messageCount = 0;

    var messageFn = myMessage;
    if (groupedMessage.user.uid !=
        widget.services.store.user.user?.id.toString()) {
      messageFn = otherMessage;
    }

    return groupedMessage.messages.map<Widget>((message) {
      messageCount++;
      final showAvatar = messageCount == 1;
      if (message is MediaMessage && message.attachment?.fileUrl != null) {
        final attachmentType = message.type;
        if (attachmentType == CometChatMessageType.video) {
          return messageFn(message, showAvatar, videoWidget(message));
        } else if (attachmentType == CometChatMessageType.image) {
          return messageFn(message, showAvatar, imageWidget(message));
        } else {
          return messageFn(message, showAvatar, documentWidget(message));
        }
      } else if (message is TextMessage) {
        return messageFn(message, showAvatar, textWidget(message));
      } else if (message is cometchat.Action) {
        if (message.action == 'added') {
          return messageFn(message, showAvatar, actionWidget(message));
        }
      }

      return Container();
    }).toList();
  }

  Future<void> pickFile() async {
    final pickedFile = await FilePicker.platform.pickFiles();

    if (pickedFile != null) {
      final pickedFilePath = Platform.isIOS
          ? Uri.encodeFull(pickedFile.files.first.path!)
          : pickedFile.files.first.path!;
      debugPrint(pickedFilePath);

      final mimeType = lookupMimeType(pickedFilePath); // 'image/jpeg'
      await widget.services.store.sendFile(
          pickedFilePath, mimeType ?? 'file', pickedFile.files.first.size);
    }
    FocusManager.instance.primaryFocus?.unfocus();
  }

  Future<void> pickPicture(pick.ImageSource source) async {
    Navigator.pop(context);
    final picker = pick.ImagePicker();

    final pickedFile = await picker.pickImage(
      source: source,
      maxWidth: 2024,
      maxHeight: 2024,
      imageQuality: 95,
    );

    if (pickedFile != null) {
      final fileSize = await pickedFile.length();

      await widget.services.store.sendFile(
        pickedFile.path,
        'image',
        fileSize,
      );
    }
    FocusManager.instance.primaryFocus?.unfocus();
  }

  Widget myMessage(BaseMessage message, bool showAvatar, Widget child) {
    return Padding(
      padding: const EdgeInsets.only(
        right: 18,
        top: 12,
        left: 30,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.k0cbcc5,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.k010101.withOpacity(0.18),
                        offset: Offset(
                          0,
                          0,
                        ),
                        blurRadius: 8,
                        spreadRadius: 0,
                      )
                    ],
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(8),
                      topRight: Radius.circular(8),
                      bottomLeft: Radius.circular(8),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.only(
                      top: 11,
                      bottom: 11,
                      right: 14,
                      left: 14,
                    ),
                    child: child,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(
                    top: 4,
                  ),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      dateFormat
                          .format(message.sentAt?.toLocal() ?? DateTime.now()),
                      style: GoogleFonts.sourceSerifPro(
                        fontSize: 11,
                        color: AppColors.k808080.withOpacity(0.8),
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 9,
          ),
          avatarFromMessage(message, showAvatar),
        ],
      ),
    );
  }

  Widget otherMessage(BaseMessage message, bool showAvatar, Widget child) {
    return Padding(
      padding: const EdgeInsets.only(
        left: 21,
        top: 12,
        right: 30,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          avatarFromMessage(message, showAvatar),
          SizedBox(
            width: 9,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    child: Padding(
                      padding: const EdgeInsets.only(
                        top: 0,
                        bottom: 4,
                        right: 0,
                        left: 0,
                      ),
                      child: Text(
                        message.sender!.name,
                        style: GoogleFonts.sourceSerifPro(
                          fontSize: 10,
                          color: AppColors.k010101,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.kffffff,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.k010101.withOpacity(0.18),
                          offset: Offset(
                            0,
                            0,
                          ),
                          blurRadius: 8,
                          spreadRadius: 0,
                        )
                      ],
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(8),
                        topRight: Radius.circular(8),
                        bottomRight: Radius.circular(8),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.only(
                        top: 11,
                        bottom: 11,
                        right: 14,
                        left: 14,
                      ),
                      child: child,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(
                      top: 4,
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        dateFormat.format(
                            message.sentAt?.toLocal() ?? DateTime.now()),
                        style: GoogleFonts.sourceSerifPro(
                          fontSize: 11,
                          color: AppColors.k808080.withOpacity(0.8),
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget videoWidget(MediaMessage message) {
    if (message.attachment?.fileUrl != null) {
      return TextButton(
        onPressed: () async {
          await launch(message.attachment!.fileUrl, forceWebView: true);
        },
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: Image(
                fit: BoxFit.cover,
                image: AssetImage('assets/images/logo_auth.png'),
              ),
            ),
            Positioned(
              bottom: 35,
              right: 35,
              child: Image(
                image: AssetImage('assets/images/btn_chat_play.png'),
              ),
            ),
          ],
        ),
      );
    }
    return Container();
  }

  Widget documentWidget(MediaMessage message) {
    if (message.attachment?.fileUrl != null) {
      return TextButton(
        onPressed: () async {
          await launch(
            message.attachment!.fileUrl,
            forceWebView: true,
          );
        },
        child: Row(
          children: [
            navBarIcon(iconAssetName: 'ic_nb_purchases.png'),
            SizedBox(width: 6),
            Text(
              S.of(context).viewAttachedDocument,
              style: GoogleFonts.sourceSerifPro(
                fontSize: 14,
                color: AppColors.k010101,
                fontWeight: FontWeight.w300,
              ),
            ),
          ],
        ),
      );
    }
    return Container();
  }

  Widget imageWidget(MediaMessage message) {
    if (message.attachment?.fileUrl != null) {
      return CachedNetworkImage(
        imageUrl: message.attachment!.fileUrl ?? '',
        fit: BoxFit.contain,
        progressIndicatorBuilder: (context, url, downloadProgress) => Center(
          child: CircularProgressIndicator(
            value: downloadProgress.progress,
          ),
        ),
      );
    }
    return Container();
  }

  Widget textWidget(TextMessage message) {
    return Text(
      message.text ?? '',
      style: GoogleFonts.sourceSerifPro(
        fontSize: 14,
        color: AppColors.k010101,
        fontWeight: FontWeight.w300,
      ),
    );
  }

  Widget actionWidget(cometchat.Action message) {
    return Text(
      message.message ?? '',
      style: GoogleFonts.sourceSerifPro(
        fontSize: 14,
        color: AppColors.k010101,
        fontWeight: FontWeight.w300,
      ),
    );
  }

  Widget avatarFromMessage(BaseMessage message, bool showAvatar) {
    if (!showAvatar) {
      return Container(
        height: 34,
        width: 34,
      );
    }
    String? userImageUrl;
    // get avatar from message
    if (message.sender?.uid != null) {
      userImageUrl = message.sender?.avatar;
    }

    if (userImageUrl != null) {
      return CachedNetworkImage(
        height: 34,
        width: 34,
        imageUrl: userImageUrl,
        errorWidget: (context, url, error) => Image(
          height: 34,
          width: 34,
          image: AssetImage('assets/images/ph_call_user.png'),
        ),
      );
    }

    return Image(
      height: 34,
      width: 34,
      image: AssetImage('assets/images/ph_call_user.png'),
    );
  }

  Widget avatarFromId(String? userIdString, bool showAvatar) {
    final userId = int.tryParse(userIdString ?? '0') ?? 0;

    final call = widget.services.ongoingCallStore.ongoingCall;

    final customerUserId = call?.customer?.user?.id;
    final doctorUserId = call?.doctor?.user?.id;
    final translatorUserId = call?.translator?.user?.id;
    final operatorUserId = call?.$Operator?.user?.id;

    if (!showAvatar) {
      return Container(
        height: 34,
        width: 34,
      );
    }

    String? userImageUrl;
    if (userId == customerUserId) {
      userImageUrl = call?.customer?.user?.avatarUrl;
    } else if (userId == doctorUserId) {
      userImageUrl = call?.doctor?.user?.avatarUrl;
    } else if (userId == translatorUserId) {
      userImageUrl = call?.doctor?.user?.avatarUrl;
    } else if (userId == operatorUserId) {
      userImageUrl = call?.$Operator?.user?.avatarUrl;
    }

    if (userImageUrl != null) {
      return CachedNetworkImage(
        height: 34,
        width: 34,
        imageUrl: userImageUrl,
        errorWidget: (context, url, error) => Image(
          height: 34,
          width: 34,
          image: AssetImage('assets/images/ph_call_user.png'),
        ),
      );
    }

    return Image(
      height: 34,
      width: 34,
      // image: AssetImage('assets/images/ic_service_assistance.png'),
      image: AssetImage('assets/images/ph_call_user.png'),
    );
  }

  Widget _remoteVideo(ChatScreenStore store) {
    final call = widget.services.ongoingCallStore.ongoingCall;

    final remoteUserId = call?.doctor?.user?.id ??
        call?.translator?.user?.id ??
        call?.$Operator?.user?.id;

    return Positioned(
      top: store.remoteVideoPositionFromTop,
      right: store.remoteVideoPositionFromLeft == null ? 0 : null,
      left: store.remoteVideoPositionFromLeft,
      child: Draggable(
        onDragEnd: (draggableDetails) {
          widget.services.store.updateRemoteVideoPosition(draggableDetails);
        },
        feedback: _remoteVideoSmallWidget(remoteUserId, false),
        child: _remoteVideoSmallWidget(remoteUserId, true),
      ),
    );
  }

  Widget _remoteVideoSmallWidget(int? remoteUserId, bool touchable) {
    final stack = Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: remoteUserId != null
              ? RtcRemoteView.SurfaceView(
                  key: UniqueKey(),
                  uid: remoteUserId,
                  channelId: widget
                      .services.ongoingCallStore.ongoingCall!.channelName!)
              : Image(
                  fit: BoxFit.cover,
                  image: AssetImage('assets/images/ic_call_operator.png'),
                ),
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.k0cbcc5.withOpacity(0.5),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(5),
                bottomRight: Radius.circular(15),
              ),
            ),
            child: Padding(
              padding:
                  const EdgeInsets.only(top: 2, left: 2, right: 5, bottom: 2),
              child: Image(
                image: AssetImage(
                  'assets/images/ic_call_turnonvideo_copy.png',
                ),
                width: 25,
                height: 25,
              ),
            ),
          ),
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            width: 1,
            color: AppColors.k0cbcc5,
          ),
        ),
        child: touchable
            ? InkWell(
                onTap: () {
                  Navigator.pop(context);
                },
                child: stack)
            : stack,
      ),
    );
  }
}
