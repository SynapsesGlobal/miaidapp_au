import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:miaid/api_utils/user_provider.dart';
import 'package:miaid/config/app_colors.dart';
import 'package:miaid/generated/l10n.dart';
import 'package:miaid/generated_api_code/api_client.swagger.dart';
import 'package:miaid/store/home/home_screen_store.dart';
import 'package:miaid/store/user/calling/ongoing_call_store.dart';
import 'package:miaid/store/user/consultation_language_service.dart';
import 'package:miaid/utils/configure_dependencies.dart';
import 'package:miaid/utils/language_native_name.dart';

class ConsultationLanguageDialog {
  ConsultationLanguageDialog._();

  static bool _didTriggerOnLaunch = false;
  static bool _isShowing = false;
  static Future<void> showOnHomeEntry(
    BuildContext context, {
    required bool isColdLaunch,
  }) async {
    if (isColdLaunch) {
      if (_didTriggerOnLaunch) return;
      _didTriggerOnLaunch = true;
    }

    if (_isShowing) return;
    _isShowing = true;
    try {
      final user = getIt<UserProvider>();
      if (!user.isLoggedIn || !user.isCustomer) return;

      if (getIt<OngoingCallStore>().hasOngoingCall) return;

      final needSelect = await ConsultationLanguageService.needSelect();
      if (!needSelect || !context.mounted) return;

      await _pickAndSave(context);
    } finally {
      _isShowing = false;
    }
  }

  /// 拉取后端可选语言列表，弹出选择框，并把所选语言写回账号。
  static Future<void> _pickAndSave(BuildContext context) async {
    var languages = <Language>[];
    try {
      languages = await ConsultationLanguageService.fetchLanguages();
    } catch (e) {
      return;
    }
    if (languages.isEmpty || !context.mounted) return;

    final selected = await _showPicker(
      context,
      languages,
      ConsultationLanguageService.current,
    );
    if (selected == null) return;

    try {
      // 把所选语言映射到 App 界面 locale（与首页右上角语言切换器一致）。
      // 注意：后端 Language.language 返回的是英文名（如 "Korean"），之前用母语写法
      // （'한국인' 等）比较永远不命中，导致除中/英外的语言都不切换界面。这里同时兼容
      // 英文名与母语写法。
      final selectedLang = _appLocaleCode(selected.language);
      await getIt<HomeScreenStore>().setLanguageCode(selectedLang);
      await ConsultationLanguageService.update(selected);
    } catch (e) {
      return;
    }
  }

  /// 把后端语言名（英文名或母语写法）映射为 App 支持的界面 locale code。
  /// 支持：en / zh(简体) / zh_Hant(繁体) / ko / id / el；未识别回退英文。
  static String _appLocaleCode(String? language) {
    switch ((language ?? '').trim().toLowerCase()) {
      case 'english':
        return 'en';
      case 'chinese':
      case 'mandarin':
      case 'simplified chinese':
      case '中文':
      case '简体中文':
        return 'zh';
      case 'traditional chinese':
      case 'cantonese':
      case '繁体中文':
      case '繁體中文':
      case '廣東話':
      case '广东话':
        return 'zh_Hant';
      case 'korean':
      case '한국어':
      case '한국인':
        return 'ko';
      case 'indonesian':
      case 'indonesia':
      case 'bahasa indonesia':
        return 'id';
      case 'greek':
      case 'ελληνικά':
        return 'el';
      default:
        return 'en';
    }
  }

  /// 居中卡片式弹框：顶部图标徽标 + 标题/说明 + 可滚动的胶囊语言列表 + 底部「取消/确认」。
  ///
  /// 点击语言项只是**选中**（高亮），不触发切换；只有点「确认」才返回所选语言，
  /// 由调用方写回账号并切换 App 语言。点「取消」返回 null。
  static Future<Language?> _showPicker(
    BuildContext context,
    List<Language> languages,
    Language? current,
  ) {
    // 弹框内的本地选中态，默认预选当前语言。
    var selected = current;

    return showDialog<Language>(
      context: context,
      builder: (dialogContext) {
        final maxHeight = MediaQuery.of(dialogContext).size.height * 0.7;
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return Dialog(
              backgroundColor: Colors.white,
              elevation: 8,
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxHeight),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        S.of(context).consultationLanguageTitle,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.rubik(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.k010101,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        S.of(context).consultationLanguageMessage,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.rubik(
                          fontSize: 13,
                          color: AppColors.k8f8e94,
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // 语言列表（胶囊样式，可滚动）：点击仅切换本地选中态
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: languages.length,
                        itemBuilder: (_, index) {
                          final lang = languages[index];
                          final isSelected =
                              selected?.id != null && selected?.id == lang.id;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Material(
                              color: isSelected
                                  ? AppColors.k0cbcc5
                                  : AppColors.kf4f4f4,
                              borderRadius: BorderRadius.circular(12),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () =>
                                    setLocalState(() => selected = lang),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          nativeLanguageName(lang.language),
                                          style: GoogleFonts.rubik(
                                            fontSize: 16,
                                            fontWeight: isSelected
                                                ? FontWeight.w600
                                                : FontWeight.w500,
                                            color: isSelected
                                                ? Colors.white
                                                : AppColors.k010101,
                                          ),
                                        ),
                                      ),
                                      if (isSelected)
                                        Icon(
                                          Icons.check_circle,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 6),
                    // 底部按钮：取消（描边）+ 确认（填充）。仅「确认」触发切换。
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 13),
                                side: BorderSide(
                                  color: AppColors.k0cbcc5.withOpacity(0.4),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                S.of(context).cancel,
                                style: GoogleFonts.rubik(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.k0cbcc5,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              // 未选中时禁用，避免误触发空切换。
                              onPressed: selected == null
                                  ? null
                                  : () => Navigator.pop(dialogContext, selected),
                              style: ElevatedButton.styleFrom(
                                elevation: 0,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 13),
                                backgroundColor: AppColors.k0cbcc5,
                                disabledBackgroundColor:
                                    AppColors.k0cbcc5.withOpacity(0.4),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                S.of(context).confirm,
                                style: GoogleFonts.rubik(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
