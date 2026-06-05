import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../component/nav_bar_icons.dart';
import '../../config/app_colors.dart';
import '../../generated/l10n.dart';
import 'models/chat_message.dart';
import 'ui/doctor_message.dart';
import 'ui/patient_message.dart';
import 'viewmodel/chatbot_viewmodel.dart';

class ChatBot extends StatelessWidget {
  final dynamic services;
  const ChatBot({super.key, required this.services});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ChatBotViewModel(),
      child: _ChatBotView(services: services),
    );
  }
}

class _ChatBotView extends StatefulWidget {
  final dynamic services;
  const _ChatBotView({required this.services});

  @override
  State<_ChatBotView> createState() => _ChatBotViewState();
}

class _ChatBotViewState extends State<_ChatBotView> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _scrollController = ScrollController();
  ChatBotViewModel? _viewModel;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final vm = Provider.of<ChatBotViewModel>(context, listen: false);
    if (_viewModel != vm) {
      _viewModel?.streamingContent.removeListener(_scrollToBottom);
      _viewModel = vm;
      _viewModel!.streamingContent.addListener(_scrollToBottom);
    }
  }

  @override
  void dispose() {
    _viewModel?.streamingContent.removeListener(_scrollToBottom);
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send(ChatBotViewModel vm) async {
    final text = _controller.text;
    _controller.clear();
    FocusScope.of(context).requestFocus(_focusNode);
    await vm.sendMessage(text);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(context),
      body: Consumer<ChatBotViewModel>(
        builder: (context, vm, _) {
          if (vm.isLoading) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              EasyLoading.show(status: 'Loading...', maskType: EasyLoadingMaskType.black);
            });
          } else {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              EasyLoading.dismiss();
            });
          }

          if (vm.messages.isNotEmpty) _scrollToBottom();

          return Column(children: [
            if (vm.errorMessage != null)
              _ErrorBanner(
                message: vm.errorMessage!,
                onRetry: vm.createNewChat,
              ),
            Expanded(child: GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              behavior: HitTestBehavior.opaque,
              child: _MessageList(
                messages: vm.messages,
                services: widget.services,
                scrollController: _scrollController,
                chatbotId: vm.chatId.toString(),
                streamingNotifier: vm.streamingContent,
              ),
            )),
            _InputBar(
              controller: _controller,
              focusNode: _focusNode,
              enabled: !vm.isLoading,
              onSend: () => _send(vm),
            ),
          ]);
        },
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context) => AppBar(
    automaticallyImplyLeading: false,
    elevation: 0,
    backgroundColor: AppColors.kffffff,
    centerTitle: true,
    title: Text(
      S.of(context).virtualAssistance,
      style: GoogleFonts.rubik(
        color: AppColors.k010101,
        fontSize: 15,
        fontWeight: FontWeight.w500,
      ),
    ),
    leading: InkWell(
      onTap: () => Navigator.pop(context, true),
      child: navBarIcon(iconAssetName: 'ic_nb_back.png'),
    ),
  );
}

// ─── 子组件 ──────────────────────────────────────────────────

class _MessageList extends StatelessWidget {
  final List<ChatMessage> messages;
  final dynamic services;
  final ScrollController scrollController;
  final String chatbotId;
  final ValueNotifier<String> streamingNotifier;

  const _MessageList({
    required this.messages,
    required this.services,
    required this.scrollController,
    required this.chatbotId,
    required this.streamingNotifier,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: ListView.builder(
        controller: scrollController,
        itemCount: messages.length,
        itemBuilder: (context, index) {
          final msg = messages[index];
          // streaming 占位：由 ValueListenableBuilder 驱动，内容到达直接替换 typing indicator
          if (msg.isStreaming) {
            return Padding(
              padding: const EdgeInsets.only(top: 20),
              child: _StreamingDoctorBubble(contentNotifier: streamingNotifier),
            );
          }
          return Padding(
            padding: const EdgeInsets.only(top: 20),
            child: msg.role == MessageRole.doctor
                ? DoctorMessage(message: msg.toJson(), services: services, chatbotId: chatbotId)
                : PatientMessage(message: msg.toJson()),
          );
        },
      ),
    );
  }
}

// 流式气泡：content 为空时显示 typing indicator，有内容后逐字显示
class _StreamingDoctorBubble extends StatelessWidget {
  final ValueNotifier<String> contentNotifier;

  const _StreamingDoctorBubble({required this.contentNotifier});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: contentNotifier,
      builder: (context, content, _) {
        if (content.isEmpty) return const _TypingIndicator();
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              maxRadius: 16,
              backgroundColor: AppColors.k0cbcc5,
              child: Image.asset('assets/images/logo_auth.png'),
            ),
            const SizedBox(width: 10),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.7,
              ),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  content,
                  style: GoogleFonts.rubik(color: Colors.black, fontSize: 15),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with TickerProviderStateMixin {
  late final List<AnimationController> _controllers;
  late final List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      3,
      (i) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 500),
      ),
    );
    _animations = _controllers
        .map((c) => Tween<double>(begin: 0, end: -6).animate(
              CurvedAnimation(parent: c, curve: Curves.easeInOut),
            ))
        .toList();

    for (int i = 0; i < 3; i++) {
      Future.delayed(Duration(milliseconds: i * 160), () {
        if (mounted) _controllers[i].repeat(reverse: true);
      });
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        CircleAvatar(
          maxRadius: 16,
          backgroundColor: AppColors.k0cbcc5,
          child: Image.asset('assets/images/logo_auth.png'),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) {
              return AnimatedBuilder(
                animation: _animations[i],
                builder: (context, child) => Transform.translate(
                  offset: Offset(0, _animations[i].value),
                  child: child,
                ),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.grey[500],
                    shape: BoxShape.circle,
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final VoidCallback onSend;

  const _InputBar({
    required this.controller,
    required this.focusNode,
    required this.enabled,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        color: Colors.grey[100],
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(5),
          ),
          child: TextField(
            focusNode: focusNode,
            controller: controller,
            enabled: enabled,
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              hintText: S.of(context).enter_message,
              hintStyle: GoogleFonts.rubik(color: AppColors.kb1b1b1, fontSize: 16),
              suffixIcon: IconButton(
                icon: Icon(Icons.send_rounded, color: AppColors.k010101),
                onPressed: enabled ? onSend : null,
              ),
            ),
            onSubmitted: (_) => enabled ? onSend() : null,
            textInputAction: TextInputAction.send,
            keyboardType: TextInputType.text,
            maxLines: null,
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorBanner({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return MaterialBanner(
      content: Text(message),
      backgroundColor: Colors.red.shade50,
      actions: [
        TextButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    );
  }
}
