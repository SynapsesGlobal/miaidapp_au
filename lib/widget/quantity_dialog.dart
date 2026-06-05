import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/app_colors.dart';
import '../generated/l10n.dart';

Future<void> showQuantityDialog({
  required BuildContext context,
  required String title,
  required Function(int qty) onConfirm,
}) async {
  final _qtyController = TextEditingController();
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,  // 允许弹窗撑满屏幕高度
    backgroundColor: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) {
      // 这里用 MediaQuery.of(context).viewInsets.bottom 获取键盘高度
      final bottomInset = MediaQuery.of(context).viewInsets.bottom;

      return Padding(
        padding: EdgeInsets.only(bottom: bottomInset),  // 动态底部内边距
        child: Container(
          constraints: BoxConstraints(
            minHeight: 100,
            maxHeight: MediaQuery.of(context).size.height * 0.5,
          ),
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min, // 内容最小高度，避免撑满整个屏幕
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: Text(title, style: GoogleFonts.rubik(
                    color: AppColors.k010101,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),),),
                  InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Icon(Icons.close, color: Colors.grey),
                  )
                ],
              ),
              const SizedBox(height: 10),
              Divider(color: Colors.grey[300]),
              const SizedBox(height: 10),
              SizedBox(
                height: 40,
                child: TextField(
                  controller: _qtyController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: S.of(context).enter_quantity,
                    hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.black12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: AppColors.k0cbcc5, width: 1),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 20),
              SizedBox(height: 10,),
              MaterialButton(
                onPressed: () {
                  final qty = int.tryParse(_qtyController.text.trim()) ?? 1;
                  Navigator.pop(context);
                  onConfirm(qty);
                },
                minWidth: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                color: AppColors.k0cbcc5,
                child: Text(
                  S.of(context).confirm,
                  style: GoogleFonts.rubik(color: Colors.white),
                ),
              )
            ],
          ),
        ),
      );
    },
  );

}
