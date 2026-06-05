import 'dart:core';
import 'dart:io' as io;
import 'dart:ui';

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:injectable/injectable.dart';
import 'package:mobx/mobx.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share/share.dart';

part 'call_view_receipt_store.g.dart';

@injectable
class CallViewReceiptStore = _CallViewReceiptStore with _$CallViewReceiptStore;

abstract class _CallViewReceiptStore with Store {
  _CallViewReceiptStore();

  Future<void> printReceipt(GlobalKey globalKey) async {
    await shareReceipt(globalKey);
  }

  Future<void> shareReceipt(GlobalKey globalKey) async {
    final boundary =
        globalKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    final image = await boundary?.toImage();
    final path = (await getTemporaryDirectory()).path;
    final bytes = await image?.toByteData(format: ImageByteFormat.png);

    if (bytes != null) {
      final file = io.File('$path/receipt.png');
      await file.writeAsBytes(bytes.buffer.asInt8List());
      await Share.shareFiles([file.path],
          mimeTypes: ['image/png'], subject: 'Receipt for your appointment');
    }
  }

  Future<void> printReceiptCrashesAndroid(GlobalKey globalKey) async {
    final boundary =
    globalKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    final image = await boundary?.toImage();
    final bytes = await image?.toByteData(format: ImageByteFormat.png);

    final pdf = pw.Document();

    final imageForPdf = pw.MemoryImage(
      bytes!.buffer.asUint8List(),
    );

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Center(
            child: pw.Image(imageForPdf),
          ); // Center
        },
      ),
    ); // Page

    await Printing.layoutPdf(
      name: 'MiAid Receipt',
      onLayout: (PdfPageFormat format) async => await pdf.save(),
    );
  }
}
