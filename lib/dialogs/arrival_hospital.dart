import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../main.dart';
import '../api_utils/api_provider.dart';
import '../config/app_colors.dart';
import 'package:http/http.dart' as http;
import '../generated/l10n.dart';
import '../utils/configure_dependencies.dart';

class ArrivalHospitalDialog {
  static void show({required String taskId}) {
    final context = navigatorKey.currentState!.overlay!.context;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ArrivalDialogContent(taskId: taskId),
    );
  }
}

class _ArrivalDialogContent extends StatefulWidget {
  final String taskId;

  const _ArrivalDialogContent({required this.taskId});

  @override
  State<_ArrivalDialogContent> createState() => _ArrivalDialogContentState();
}

class _ArrivalDialogContentState extends State<_ArrivalDialogContent> {
  bool _arrived = false;
  bool _notArrived = false;

  bool get _isLoading => _arrived || _notArrived;

  Future<void> _submit(bool arrived) async {
    if (!mounted) return;
    Navigator.pop(context);

    final api = getIt<ApiProvider>();
    try {
      await http.post(
        Uri.parse('${api.baseUrl}/api/v1/consultation/reply'),
        headers: {
          'Content-Type': 'application/json',
          'x-user-id': api.userProvider.user!.id.toString(),
          'x-api-key': api.apiKey,
        },
        body: jsonEncode({
          'notificationId': widget.taskId,
          'userId': api.userProvider.user!.id.toString(),
          'response': arrived ? 'arrived' : 'not_arrived',
        }),
      );
    } catch (e) {
      debugPrint('Submit error: $e');
      if (!mounted) return;
    }
  }

  Widget _buildButton({
    required String label,
    required Color color,
    required bool loading,
    required VoidCallback? onPressed,
  }) {
    return Expanded(child: MaterialButton(
      color: color,
      onPressed: _isLoading ? null : onPressed,
      child: loading ? SizedBox(
        height: 18,
        width: 18,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Colors.white,
        ),
      ) : Text(
        label,
        style: GoogleFonts.rubik(
          color: AppColors.kffffff,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
    ),);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: Column(children: [
        Text(
          S.of(context).system_info,
          style: GoogleFonts.rubik(
            color: AppColors.k0cbcc5,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        Divider(),
      ],),
      content: Text(
        S.of(context).emergency_fllowup_msg,
        style: GoogleFonts.rubik(
          color: AppColors.k010101,
          fontSize: 15,
          fontWeight: FontWeight.normal,
        ),
      ),
      actions: [
        Row(children: [
          _buildButton(
            label: S.of(context).arrived,
            color: AppColors.k0cbcc5,
            loading: _arrived,
            onPressed: () => _submit(true),
          ),
          SizedBox(width: 10),
          _buildButton(
            label: S.of(context).not_arrived,
            color: AppColors.ke63030,
            loading: _notArrived,
            onPressed: () => _submit(false),
          ),
        ],),
      ],
    );
  }
}