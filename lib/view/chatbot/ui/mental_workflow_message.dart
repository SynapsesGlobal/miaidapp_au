import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../config/app_colors.dart';
import '../../../generated/l10n.dart';
import '../models/mental_workflow_content.dart';
import 'chat_card_widgets.dart';
import 'hospital_cards.dart';
import 'mental_resource_cards.dart';

/// 心理工作流（Level5 Q7）消息：一条服务端消息在界面上拆成最多五个气泡
/// 1. recommendation：就医建议文本
/// 2. mental_resources.m2_list：心理援助热线卡片
/// 3. mental_resources.m3_list：在线支持平台卡片
/// 4. mental_resources.m4_list：附近医院卡片
/// 5. follow_up_question：后续询问文本
/// 某一项没有内容时对应气泡不生成，其余气泡顺序不变
class MentalWorkflowMessage extends StatelessWidget {
  final MentalWorkflowContent content;

  /// 当前显示前几个气泡。null 表示全部显示（历史记录、分段显示已结束）。
  /// 各段内容是服务端一次返回的，新消息到达时由 ViewModel 逐个放出，
  /// 避免资源卡片一出现就把前面的建议文本顶出屏幕
  final int? visibleBubbles;

  /// 还有气泡未显示时挂在末尾的"输入中"动画
  final Widget? pendingIndicator;

  const MentalWorkflowMessage({
    super.key,
    required this.content,
    this.visibleBubbles,
    this.pendingIndicator,
  });

  @override
  Widget build(BuildContext context) {
    final bubbles = <Widget>[
      if (content.recommendation != null)
        _DoctorBubble(child: _BubbleText(content.recommendation!)),
      // 三组资源各占一个气泡；生成条件与顺序要和 MentalWorkflowContent.bubbleCount 保持一致
      if (content.hotlines.isNotEmpty)
        _DoctorBubble(
          wide: true,
          child: _ResourceSection(
            title: S.of(context).mentalHotlines,
            child: MentalResourceCards(items: content.hotlines),
          ),
        ),
      if (content.onlinePlatforms.isNotEmpty)
        _DoctorBubble(
          wide: true,
          child: _ResourceSection(
            title: S.of(context).mentalOnlinePlatforms,
            child: MentalResourceCards(items: content.onlinePlatforms),
          ),
        ),
      if (content.clinics.isNotEmpty)
        _DoctorBubble(
          wide: true,
          child: _ResourceSection(
            title: S.of(context).mentalNearbyHospitals,
            child: HospitalCards(hospitals: content.clinics),
          ),
        ),
      if (content.followUpQuestion != null)
        _DoctorBubble(child: _BubbleText(content.followUpQuestion!)),
    ];

    final shown = visibleBubbles == null
        ? bubbles.length
        : visibleBubbles!.clamp(1, bubbles.length);
    final hasPending = shown < bubbles.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < shown; i++) ...[
          // 与列表项之间的间距保持一致，看起来就是几条独立消息
          if (i > 0) const SizedBox(height: 20),
          bubbles[i],
        ],
        if (hasPending && pendingIndicator != null) ...[
          const SizedBox(height: 20),
          pendingIndicator!,
        ],
      ],
    );
  }
}

/// 资源气泡的内容：分组标题 + 该组卡片
class _ResourceSection extends StatelessWidget {
  final String title;
  final Widget child;

  const _ResourceSection({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ChatCardSectionTitle(text: title),
        child,
      ],
    );
  }
}

class _BubbleText extends StatelessWidget {
  final String text;

  const _BubbleText(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.left,
      style: GoogleFonts.rubik(color: Colors.black, fontSize: 15),
    );
  }
}

/// 与 DoctorMessage 相同的头像 + 灰色气泡样式
class _DoctorBubble extends StatelessWidget {
  final Widget child;

  /// 卡片气泡放宽，避免地址硬折行
  final bool wide;

  const _DoctorBubble({required this.child, this.wide = false});

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
        Flexible(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * (wide ? 0.85 : 0.7),
            ),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(10),
              ),
              child: child,
            ),
          ),
        ),
      ],
    );
  }
}
