import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../config/app_colors.dart';
import '../../../generated/l10n.dart';
import '../models/mental_workflow_content.dart';
import 'chat_card_widgets.dart';
import 'hospital_cards.dart';
import 'mental_resource_cards.dart';

/// 心理工作流（Level5 Q7）消息：一条服务端消息在界面上拆成最多三个气泡
/// 1. recommendation：就医建议文本
/// 2. mental_resources：热线 / 在线平台 / 附近医院三组卡片（全部为空时整个气泡隐藏）
/// 3. follow_up_question：后续询问文本
class MentalWorkflowMessage extends StatelessWidget {
  final MentalWorkflowContent content;

  const MentalWorkflowMessage({super.key, required this.content});

  @override
  Widget build(BuildContext context) {
    final bubbles = <Widget>[
      if (content.recommendation != null)
        _DoctorBubble(child: _BubbleText(content.recommendation!)),
      if (content.hasResources)
        _DoctorBubble(
          wide: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (content.hotlines.isNotEmpty) ...[
                ChatCardSectionTitle(text: S.of(context).mentalHotlines),
                MentalResourceCards(items: content.hotlines),
              ],
              if (content.onlinePlatforms.isNotEmpty) ...[
                ChatCardSectionTitle(text: S.of(context).mentalOnlinePlatforms),
                MentalResourceCards(items: content.onlinePlatforms),
              ],
              if (content.clinics.isNotEmpty) ...[
                ChatCardSectionTitle(text: S.of(context).mentalNearbyHospitals),
                HospitalCards(hospitals: content.clinics),
              ],
            ],
          ),
        ),
      if (content.followUpQuestion != null)
        _DoctorBubble(child: _BubbleText(content.followUpQuestion!)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < bubbles.length; i++) ...[
          // 与列表项之间的间距保持一致，看起来就是三条独立消息
          if (i > 0) const SizedBox(height: 20),
          bubbles[i],
        ],
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
