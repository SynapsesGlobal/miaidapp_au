import 'dart:core';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:injectable/injectable.dart';
import 'package:miaid/api_utils/api_provider.dart';
import 'package:miaid/api_utils/user_provider.dart';
import 'package:miaid/config/stream_settings.dart';
import 'package:miaid/generated_api_code/api_client.swagger.dart';
import 'package:mobx/mobx.dart';
import 'package:cometchat/cometchat_sdk.dart' as cometchat;
import 'dart:developer' as developer;

part 'chat_screen_store.g.dart';

class GroupedMessages = _GroupedMessages with _$GroupedMessages;

abstract class _GroupedMessages with Store {
  _GroupedMessages(this.user);

  final cometchat.User user;

  @observable
  ObservableList<dynamic> messages = ObservableList<dynamic>();
}

@singleton
class ChatScreenStore = _ChatScreenStore with _$ChatScreenStore;

abstract class _ChatScreenStore
    with Store, cometchat.MessageListener, cometchat.GroupListener {
  static final minMarginFromTopForRemoteVideo = 25.0;

  _ChatScreenStore(this.api, this.user, this.streamSettings);

  final ApiProvider api;
  final UserProvider user;
  final StreamSettings streamSettings;

  final scrollController = ScrollController();

  bool initialized = false;
  bool hasJoinedGroup = false;
  cometchat.User? chatUser;
  String GUID = '';

  final _listenerID = 'chat_calling_cometchat_message_listener';
  final _groupListenerID = 'chat_calling_cometchat_group_listener';

  @observable
  ObservableList<GroupedMessages> messages = ObservableList<GroupedMessages>();

  @observable
  double? remoteVideoPositionFromLeft;

  @observable
  double remoteVideoPositionFromTop = minMarginFromTopForRemoteVideo;

  @observable
  String? errorMessage;

  @action
  Future<void> dispose() async {
    messages.clear();
    cometchat.CometChat.removeMessageListener(_listenerID);
    cometchat.CometChat.removeMessageListener(_groupListenerID);

    await cometchat.CometChat.logout(onSuccess: (successMessage) {
      debugPrint("CometChat Logout successful with message $successMessage");
    }, onError: (cometchat.CometChatException e) {
      debugPrint("CometChat Logout failed with exception:  ${e.message}");
    });
    initialized = false;
    GUID = '';
    errorMessage = null;
  }

  @action
  Future<void> initChatClientFromCall(Call call) async {
    developer.log('preparing initChatClientFromCall');
    if (!initialized &&
        call.guid != null &&
        user.user?.cometchatToken != null &&
        call.$Operator != null) {
      developer.log('initChatClientFromCall');

      initialized = true;
      GUID = call.guid!;

      try {
        cometchat.CometChat.addMessageListener(_listenerID, this);
        cometchat.CometChat.addGroupListener(_groupListenerID, this);

        await initChatClient(chatGroupToken: GUID);
      } catch (e) {
        debugPrint('initChatClientFromCall error: $e');
        cometchat.CometChat.removeMessageListener(_listenerID);
        cometchat.CometChat.removeMessageListener(_groupListenerID);

        initialized = false;
      }
    }
  }

  @action
  Future<void> initChatClient({
    required String chatGroupToken,
  }) async {
    try {
      String authToken = user.user?.cometchatToken ?? '';
      // login to comet chat
      chatUser = await cometchat.CometChat.getLoggedInUser(
          onSuccess: (_) {}, onError: (_) {});
      if (chatUser != null) {
        // logout user
        await cometchat.CometChat.logout(
            onSuccess: (successMessage) {},
            onError: (cometchat.CometChatException e) {
              throw Exception('Chat init failed: ${e.code}');
            });
      }

      if (authToken != null) {
        chatUser = await cometchat.CometChat.loginWithAuthToken(authToken,
            onSuccess: (cometchat.User loggedInUser) {
          debugPrint('Login successful : ${loggedInUser.toString()}');
        }, onError: (cometchat.CometChatException e) {
          throw Exception('Login failed: ${e.code}');
        });

        // Fetch Previous Messages from the joined group
        final messageRequest =
            (cometchat.MessagesRequestBuilder()..guid = GUID).build();

        await messageRequest.fetchPrevious(
          onSuccess: (List<cometchat.BaseMessage> list) {
            hasJoinedGroup = true;
            for (cometchat.BaseMessage message in list) {
              addMessage(message);
            }
          },
          onError: (cometchat.CometChatException e) {
            throw Exception('Message fetching failed: ${e.code}');
          },
        );
      } else {
        throw Exception('Token is null');
      }
    } catch (e) {
      debugPrint('initChatClient error: $e');
      errorMessage = e.toString();
    }
  }

  @action
  Future<void> sendMessage(String message) async {
    if (hasJoinedGroup == false) {
      debugPrint('sendFile: hasJoinedGroup == false');
      errorMessage = 'Message sending failed: Has not joined group';

      return;
    }

    final textMessage = cometchat.TextMessage(
        text: message,
        receiverUid: GUID,
        receiverType: cometchat.CometChatReceiverType.group,
        type: cometchat.CometChatMessageType.text);

    debugPrint('sendMessage: ${textMessage.type}');

    await cometchat.CometChat.sendMessage(textMessage,
        onSuccess: (cometchat.TextMessage message) {
      debugPrint("Message sent successfully:  ${message.toString()}");

      addMessage(message);
    }, onError: (cometchat.CometChatException e) {
      debugPrint("Message sending failed with exception:  ${e.message}");
      errorMessage = 'Message sending failed: ${e.code}';
    });
    await scrollMessagesToBottom();
  }

  @action

  /// @fileType: image, video or file
  Future<void> sendFile(
    String filePath,
    String fileType,
    int fileSize,
  ) async {
    if (hasJoinedGroup == false) {
      debugPrint('sendFile: hasJoinedGroup == false');
      errorMessage = 'File sending failed: Has not joined group';

      return;
    }

    if (fileSize > 100 * 1024 * 1024) {
      debugPrint('sendFile: fileSize > 100MB');
      errorMessage = 'File size is too large, max size is 100MB';

      return;
    }

    final type = fileType == 'image'
        ? cometchat.CometChatMessageType.image
        : fileType == 'video'
            ? cometchat.CometChatMessageType.video
            : cometchat.CometChatMessageType.file;

    // if platform is ios, add file:// to the path

    final finalFilePath = Platform.isIOS ? 'file://$filePath' : filePath;

    final mediaMessage = cometchat.MediaMessage(
      receiverType: cometchat.CometChatReceiverType.group,
      receiverUid: GUID,
      file: finalFilePath,
      type: type,
    );

    final message = await cometchat.CometChat.sendMediaMessage(
      mediaMessage,
      onSuccess: (cometchat.MediaMessage message) async {
        debugPrint("Media message sent successfully:${mediaMessage.metadata}");
        addMessage(message);
        await scrollMessagesToBottom();
      },
      onError: (e) {
        debugPrint("Media message sending failed with exception: ${e.message}");
        errorMessage = 'Message sending failed: ${e.code}';
      },
    );
  }

  @action
  void addMessage(dynamic message) {
    if (message != null) {
      if (messages.isNotEmpty &&
          messages.last.user.uid == message.sender?.uid) {
        messages.last.messages.add(message);
      } else {
        final groupedMessage = GroupedMessages(message.sender!);
        groupedMessage.messages.add(message);
        messages.add(groupedMessage);
      }
    }
  }

  @action
  void clearError() {
    errorMessage = null;
  }

  @action
  void updateRemoteVideoPosition(DraggableDetails draggableDetails) {
    remoteVideoPositionFromLeft = draggableDetails.offset.dx;
    remoteVideoPositionFromTop = draggableDetails.offset.dy;
  }

  @action
  void resetRemoteVideoPosition() {
    remoteVideoPositionFromLeft = null;
    remoteVideoPositionFromTop = minMarginFromTopForRemoteVideo;
  }

  @override
  void onTextMessageReceived(cometchat.TextMessage textMessage) async {
    debugPrint("Text message received successfully: $textMessage");
    addMessage(textMessage);
    await scrollMessagesToBottom();
  }

  @override
  void onMediaMessageReceived(cometchat.MediaMessage mediaMessage) async {
    debugPrint("Media message received successfully: $mediaMessage");
    addMessage(mediaMessage);
    await scrollMessagesToBottom();
  }

  @override
  void onCustomMessageReceived(cometchat.CustomMessage customMessage) async {
    debugPrint("Custom message received successfully: $customMessage");
    addMessage(customMessage);
    await scrollMessagesToBottom();
  }

  @override
  void onGroupMemberJoined(cometchat.Action action, cometchat.User joinedUser,
      cometchat.Group joinedGroup) async {
    debugPrint("onGroupMemberJoined: ${joinedUser.toString()}");
    addMessage(action);
    await scrollMessagesToBottom();
  }

  @override
  void onMemberAddedToGroup(cometchat.Action action, cometchat.User addedby,
      cometchat.User userAdded, cometchat.Group addedTo) async {
    {
      debugPrint("onGroupMemberJoined: ${action.toString()}");
      addMessage(action);
      await scrollMessagesToBottom();
    }
  }

  Future<void> scrollMessagesToBottom() async {
    await Future.delayed(const Duration(milliseconds: 200), () {});
    await scrollController.animateTo(
      scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }
}
