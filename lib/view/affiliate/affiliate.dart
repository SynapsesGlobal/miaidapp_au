import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../../api_utils/api_provider.dart';
import '../../api_utils/http_exception.dart';
import '../../config/app_colors.dart';
import '../../component/nav_bar_icons.dart';
import '../../generated/l10n.dart';
import '../../utils/configure_dependencies.dart';
import 'affiliate_detail.dart';

class AffiliateItem {
  final int id;
  final String merchantAvatar;
  final String merchantCampaignName;
  final String campaignName;
  final String description;
  final String targetUrl;
  final String? couponCode;
  final String type;
  final String? startDate;
  final String? endDate;

  const AffiliateItem({
    required this.id,
    required this.merchantAvatar,
    required this.merchantCampaignName,
    required this.campaignName,
    required this.description,
    required this.targetUrl,
    this.couponCode,
    required this.type,
    this.startDate,
    this.endDate,
  });

  bool get isCoupon => type == 'coupon';

  factory AffiliateItem.fromJson(Map<String, dynamic> json) {
    return AffiliateItem(
      id: json['id'] as int,
      merchantAvatar: json['merchant_avatar'] as String? ?? '',
      merchantCampaignName: json['merchant_campaign_name'] as String? ?? '',
      campaignName: json['campaign_name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      targetUrl: json['target_url'] as String? ?? '',
      couponCode: json['coupon_code'] as String?,
      type: json['type'] as String? ?? 'promotion',
      startDate: json['start_date'] as String?,
      endDate: json['end_date'] as String?,
    );
  }
}

class _TabData {
  List<AffiliateItem> items = [];
  int currentPage = 0;
  int lastPage = 1;
  bool isLoading = false;

  bool get hasMore => currentPage < lastPage;

  void reset() {
    items = [];
    currentPage = 0;
    lastPage = 1;
    isLoading = false;
  }
}

const List<String?> _tabTypeFilter = [null, 'promotion', 'coupon'];

class AffiliatePage extends StatefulWidget {
  const AffiliatePage({super.key});

  @override
  State<AffiliatePage> createState() => _AffiliatePageState();
}

class _AffiliatePageState extends State<AffiliatePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<_TabData> _tabs = List.generate(3, (_) => _TabData());
  final List<ScrollController> _scrollControllers = List.generate(3, (_) => ScrollController());

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);

    for (var i = 0; i < 3; i++) {
      _scrollControllers[i].addListener(() => _onScroll(i));
    }

    _loadPage(0);
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    for (final sc in _scrollControllers) {
      sc.dispose();
    }
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    final i = _tabController.index;
    if (_tabs[i].items.isEmpty && !_tabs[i].isLoading) {
      _loadPage(i);
    }
  }

  void _onScroll(int tabIndex) {
    final sc = _scrollControllers[tabIndex];
    if (sc.position.pixels >= sc.position.maxScrollExtent - 200) {
      _loadPage(tabIndex);
    }
  }

  Future<void> _loadPage(int tabIndex) async {
    final tab = _tabs[tabIndex];
    if (tab.isLoading || !tab.hasMore) return;

    setState(() => tab.isLoading = true);

    final api = getIt<ApiProvider>();
    final nextPage = tab.currentPage + 1;

    final queryParams = <String, String>{'page': nextPage.toString()};
    final typeFilter = _tabTypeFilter[tabIndex];
    if (typeFilter != null) queryParams['type'] = typeFilter;

    try {
      final url = Uri.parse('${api.baseUrl}/api/v1/affiliate/campaigns')
          .replace(queryParameters: queryParams);

      final response = await http.get(url, headers: {
        'Content-Type': 'application/json',
        'x-user-id': api.userProvider.user!.id.toString(),
        'x-api-key': api.apiKey,
      });

      if (!mounted) return;

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final payload = (body['payload'] as List).cast<Map<String, dynamic>>();
        final paginator = body['paginator'] as Map<String, dynamic>;

        setState(() {
          tab.items.addAll(payload.map(AffiliateItem.fromJson));
          tab.currentPage = paginator['current_page'] as int;
          tab.lastPage = paginator['last_page'] as int;
          tab.isLoading = false;
        });
      } else {
        setState(() => tab.isLoading = false);
        await HttpExceptionNotifyUser.showInfo(S.of(context).somethingWentWrong);
      }
    } catch (e) {
      debugPrint('affiliate error: $e');
      if (mounted) setState(() => tab.isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.kf4f4f4,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        elevation: 0,
        backgroundColor: AppColors.kffffff,
        centerTitle: true,
        title: Text(
          S.of(context).affiliate_title,
          style: GoogleFonts.rubik(
            color: AppColors.k010101,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        leading: InkWell(
          onTap: () => Navigator.pop(context),
          child: navBarIcon(iconAssetName: 'ic_nb_back.png'),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: AppColors.kffffff,
            child: TabBar(
              controller: _tabController,
              labelColor: AppColors.k0cbcc5,
              unselectedLabelColor: AppColors.k8f8e94,
              indicatorColor: AppColors.k0cbcc5,
              indicatorWeight: 2,
              labelStyle: GoogleFonts.rubik(fontSize: 14, fontWeight: FontWeight.w500),
              unselectedLabelStyle: GoogleFonts.rubik(fontSize: 14, fontWeight: FontWeight.normal),
              tabs: [
                Tab(text: S.of(context).affiliate_tab_all),
                Tab(text: S.of(context).affiliate_tab_promotion),
                Tab(text: S.of(context).affiliate_tab_coupon),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: List.generate(3, (i) => _buildTabContent(i)),
      ),
    );
  }

  Widget _buildTabContent(int tabIndex) {
    final tab = _tabs[tabIndex];

    if (tab.items.isEmpty && tab.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (tab.items.isEmpty && !tab.isLoading) {
      return _buildEmpty();
    }

    return ListView.builder(
      controller: _scrollControllers[tabIndex],
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      itemCount: tab.items.length + (tab.isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == tab.items.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return _buildCard(tab.items[index]);
      },
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inbox_outlined, size: 56, color: AppColors.kb1b1b1),
          const SizedBox(height: 12),
          Text(
            S.of(context).affiliate_no_items,
            style: GoogleFonts.rubik(color: AppColors.k8f8e94, fontSize: 15),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(AffiliateItem item) {
    return GestureDetector(
      onTap: () => Navigator.push<void>(
        context,
        MaterialPageRoute<void>(builder: (_) => AffiliateDetailPage(item: item)),
      ),
      child: _buildCardContent(item),
    );
  }

  Widget _buildCardContent(AffiliateItem item) {
    final accentColor = item.isCoupon ? AppColors.k0cbcc5 : AppColors.k0CC58F;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.kffffff,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 左侧色条
              Container(width: 4, color: accentColor),
              // 内容区
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 头部：头像 + 商家/活动名
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          ClipOval(
                            child: CachedNetworkImage(
                              imageUrl: item.merchantAvatar,
                              width: 38,
                              height: 38,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => _avatarPlaceholder(),
                              errorWidget: (context, url, error) => _avatarPlaceholder(),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.merchantCampaignName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.rubik(
                                    color: AppColors.k8f8e94,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  item.campaignName,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.rubik(
                                    color: AppColors.k010101,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.chevron_right,
                            size: 18,
                            color: AppColors.kb1b1b1,
                          ),
                        ],
                      ),

                      // 描述
                      if (item.description.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          item.description,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.rubik(
                            color: AppColors.k696969,
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                      ],

                      // 底部：coupon chip（可选）+ 类型 tag
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          if (item.isCoupon && item.couponCode != null && item.couponCode!.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.keefeff,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppColors.k0cbcc5.withOpacity(0.35)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.local_offer_outlined, size: 12, color: AppColors.k0cbcc5),
                                  const SizedBox(width: 4),
                                  Text(
                                    item.couponCode!,
                                    style: GoogleFonts.rubik(
                                      color: AppColors.k0cbcc5,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Spacer(),
                          ] else
                            const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: accentColor.withOpacity(0.10),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              item.isCoupon ? S.of(context).affiliate_tab_coupon : S.of(context).affiliate_tab_promotion,
                              style: GoogleFonts.rubik(
                                color: accentColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _avatarPlaceholder() {
    return Container(
      width: 38,
      height: 38,
      color: AppColors.kf4f4f4,
      child: const Icon(Icons.store, color: Colors.grey, size: 20),
    );
  }
}