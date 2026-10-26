import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:miaid/api_utils/user_provider.dart';
import 'package:miaid/component/miaid_drawer.dart';
import 'package:miaid/config/app_colors.dart';
import 'package:miaid/generated/l10n.dart';
import 'package:miaid/utils/configure_dependencies.dart';
import 'package:miaid/view/marketing/category.dart';
import 'package:miaid/view/user/home/home_screen.dart';
import 'package:miaid/view/user/me/me_screen.dart';

/// 已登录客户的根页面：底部导航 Home / MiSpace / Me。
/// 三个 tab 常驻在 IndexedStack 里，tab 内再 push 的页面全屏显示、不带底栏。
/// 医生 / 翻译端的首页是通话记录，不走这里。
class MainTabs extends StatefulWidget {
  const MainTabs({super.key});

  /// 清空路由栈并以底部导航壳作为首页。登录成功、完善资料、抽屉「主页」等都走这里。
  static Future<void> pushAsRoot(BuildContext context) {
    return Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/'),
        builder: (_) => const MainTabs(),
      ),
      (route) => false,
    );
  }

  @override
  State<MainTabs> createState() => _MainTabsState();
}

class _MainTabsState extends State<MainTabs> {
  var _index = 0;

  /// tab 页首次切到时才创建并缓存：
  /// - HomeScreen 是 injectable，放在 build 里 getIt 每次都是新实例，store 状态会丢；
  /// - MiSpace 一进 initState 就拉接口并弹全局 loading，不能在启动时跟着首页一起初始化。
  final _pages = <int, Widget>{};

  Widget _page(int index) => _pages.putIfAbsent(index, () => switch (index) {
        0 => getIt<HomeScreen>(),
        1 => const MarketingCategory(showBackButton: false),
        _ => const MeScreen(),
      });

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);
    return Scaffold(
      // 抽屉挂在这一层才能盖住底部导航；首页左上角的菜单按钮打开的就是它
      drawer: getDrawer(getIt<UserProvider>()),
      drawerEnableOpenDragGesture: _index == 0,
      body: IndexedStack(
        index: _index,
        children: List.generate(
          3,
          (i) => _pages.containsKey(i) || i == _index ? _page(i) : const SizedBox.shrink(),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppColors.kffffff,
        selectedItemColor: AppColors.k0cbcc5,
        unselectedItemColor: AppColors.k8f8e94,
        selectedLabelStyle: GoogleFonts.rubik(fontSize: 12, fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.rubik(fontSize: 12),
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.home_outlined),
            activeIcon: const Icon(Icons.home),
            label: l10n.home,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.storefront_outlined),
            activeIcon: const Icon(Icons.storefront),
            label: l10n.marketing,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.person_outline),
            activeIcon: const Icon(Icons.person),
            label: l10n.me,
          ),
        ],
      ),
    );
  }
}
