import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_colors.dart';
import '../../component/nav_bar_icons.dart';
import '../../generated/l10n.dart';
import 'affiliate.dart';

class AffiliateDetailPage extends StatelessWidget {
  final AffiliateItem item;

  const AffiliateDetailPage({super.key, required this.item});

  Future<void> _launchUrl(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _copyCode(BuildContext context, String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          S.of(context).affiliate_coupon_code_copied,
          style: GoogleFonts.rubik(color: AppColors.kffffff, fontSize: 13),
        ),
        backgroundColor: AppColors.k0cbcc5,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  String _formatDate(String? isoDate) {
    if (isoDate == null) return '';
    try {
      final dt = DateTime.parse(isoDate);
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoDate;
    }
  }

  @override
  Widget build(BuildContext context) {
    final startStr = _formatDate(item.startDate);
    final endStr = _formatDate(item.endDate);
    final hasDate = startStr.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.kf4f4f4,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        elevation: 0,
        backgroundColor: AppColors.kffffff,
        centerTitle: true,
        title: Text(
          S.of(context).affiliate_detail_title,
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
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: 12),
            if (hasDate) ...[
              _buildInfoCard(context, startStr, endStr),
              const SizedBox(height: 12),
            ],
            if (item.description.isNotEmpty) ...[
              _buildSection(
                title: S.of(context).affiliate_description,
                child: Text(
                  item.description,
                  style: GoogleFonts.rubik(
                    color: AppColors.k696969,
                    fontSize: 14,
                    height: 1.6,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (item.couponCode != null && item.couponCode!.isNotEmpty) ...[
              _buildSection(
                title: S.of(context).affiliate_coupon_code,
                child: _buildCouponCode(context, item.couponCode!),
              ),
              const SizedBox(height: 12),
            ],
            _buildSection(
              title: S.of(context).affiliate_target_link,
              child: _buildTargetUrl(context),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        child: MaterialButton(
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          color: AppColors.k0cbcc5,
          onPressed: () => _launchUrl(context, item.targetUrl),
          child: Text(
            S.of(context).affiliate_visit_now,
            style: GoogleFonts.rubik(
              color: AppColors.kffffff,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
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
      child: Column(
        children: [
          ClipOval(
            child: CachedNetworkImage(
              imageUrl: item.merchantAvatar,
              width: 72,
              height: 72,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                width: 72,
                height: 72,
                color: AppColors.kf4f4f4,
                child: const Icon(Icons.store, color: Colors.grey, size: 36),
              ),
              errorWidget: (context, url, error) => Container(
                width: 72,
                height: 72,
                color: AppColors.kf4f4f4,
                child: const Icon(Icons.store, color: Colors.grey, size: 36),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            item.merchantCampaignName,
            textAlign: TextAlign.center,
            style: GoogleFonts.rubik(
              color: AppColors.k8f8e94,
              fontSize: 13,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            item.campaignName,
            textAlign: TextAlign.center,
            style: GoogleFonts.rubik(
              color: AppColors.k010101,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          _buildTypeBadge(context),
        ],
      ),
    );
  }

  Widget _buildTypeBadge(BuildContext context) {
    if (item.isCoupon) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.keefeff,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.k0cbcc5.withOpacity(0.4)),
        ),
        child: Text(
          S.of(context).affiliate_tab_coupon,
          style: GoogleFonts.rubik(
            color: AppColors.k0cbcc5,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.k0CC58F.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        S.of(context).affiliate_tab_promotion,
        style: GoogleFonts.rubik(
          color: AppColors.k0CC58F,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context, String startStr, String endStr) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
      child: Row(
        children: [
          Expanded(
            child: _buildDateItem(S.of(context).affiliate_start_date, startStr),
          ),
          Container(width: 1, height: 36, color: AppColors.kf4f4f4),
          Expanded(
            child: _buildDateItem(S.of(context).affiliate_end_date, endStr.isNotEmpty ? endStr : S.of(context).affiliate_no_expiry),
          ),
        ],
      ),
    );
  }

  Widget _buildDateItem(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.rubik(color: AppColors.k8f8e94, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.rubik(
            color: AppColors.k010101,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildSection({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.rubik(
              color: AppColors.k010101,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Divider(color: AppColors.kf4f4f4, height: 1),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _buildCouponCode(BuildContext context, String code) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.keefeff,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.k0cbcc5.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.local_offer_outlined, size: 18, color: AppColors.k0cbcc5),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              code,
              style: GoogleFonts.rubik(
                color: AppColors.k0cbcc5,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => _copyCode(context, code),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.k0cbcc5,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.copy_rounded, size: 14, color: AppColors.kffffff),
                  const SizedBox(width: 4),
                  Text(
                    S.of(context).affiliate_copy,
                    style: GoogleFonts.rubik(
                      color: AppColors.kffffff,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
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

  Widget _buildTargetUrl(BuildContext context) {
    return GestureDetector(
      onTap: () => _launchUrl(context, item.targetUrl),
      child: Row(
        children: [
          Icon(Icons.link, size: 16, color: AppColors.k5251f7),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              item.targetUrl,
              style: GoogleFonts.rubik(
                color: AppColors.k5251f7,
                fontSize: 13,
                decoration: TextDecoration.underline,
                decorationColor: AppColors.k5251f7,
              ),
            ),
          ),
          Icon(Icons.open_in_new, size: 14, color: AppColors.k5251f7),
        ],
      ),
    );
  }
}