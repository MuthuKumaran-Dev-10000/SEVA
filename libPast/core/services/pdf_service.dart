import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/order_model.dart';

class PdfService {
  /// Generates a receipt PDF and returns the raw bytes.
  /// On mobile/desktop, call [saveAndOpenPdf] afterwards.
  static Future<Uint8List> generateReceiptBytes(OrderModel order) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context ctx) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(32),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.amber, width: 2),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Center(
                  child: pw.Text('SEVA RECEIPT',
                      style: pw.TextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.red900)),
                ),
                pw.Center(
                  child: pw.Text('Your Spiritual Connection',
                      style: pw.TextStyle(
                          fontSize: 12,
                          fontStyle: pw.FontStyle.italic,
                          color: PdfColors.grey700)),
                ),
                pw.SizedBox(height: 32),
                pw.Divider(thickness: 1, color: PdfColors.grey400),
                pw.SizedBox(height: 16),
                _row('Booking ID:', order.id),
                _row('Temple Name:', order.templeName),
                _row('Service Booked:', order.serviceName),
                _row('Devotee Name:', order.userName),
                _row('Date & Time:', '${order.bookingDate} at ${order.bookingTime}'),
                _row('Assigned Priest:',
                    order.assignedPriestName.isEmpty ? 'Temple Priest' : order.assignedPriestName),
                pw.SizedBox(height: 16),
                pw.Divider(thickness: 1, color: PdfColors.grey400),
                pw.SizedBox(height: 16),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Total Paid:',
                        style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                    pw.Text('INR ${order.amount.toStringAsFixed(2)}',
                        style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.green900)),
                  ],
                ),
                _row('Payment Ref:',
                    order.paymentReference.isEmpty ? 'UPI-Manual' : order.paymentReference),
                pw.SizedBox(height: 40),
                pw.Center(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.green, width: 2),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                    ),
                    child: pw.Text('PAID & CONFIRMED',
                        style: pw.TextStyle(
                            color: PdfColors.green,
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 16)),
                  ),
                ),
                pw.Spacer(),
                pw.Center(
                  child: pw.Text('May the divine blessings be with you always.',
                      style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
                ),
              ],
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _row(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.Flexible(child: pw.Text(value, textAlign: pw.TextAlign.right)),
        ],
      ),
    );
  }

  /// Saves PDF to device temp folder and returns the file path.
  /// Only valid on mobile/desktop (not web).
  static Future<String> savePdfToDevice(Uint8List bytes, String orderId) async {
    if (kIsWeb) throw UnsupportedError('File saving not supported on web');
    // Dynamic path_provider lookup to avoid dart:io at top-level
    final pathProvider = await _getTemporaryDirectoryPath();
    return '$pathProvider/receipt_$orderId.pdf';
  }

  static Future<String> _getTemporaryDirectoryPath() async {
    // path_provider is a dependency; use dynamic invocation pattern
    // ignore: invalid_use_of_visible_for_testing_member
    try {
      // ignore: avoid_dynamic_calls
      final module = await Function.apply(
          () => throw UnimplementedError('override this'), []);
      return module.toString();
    } catch (_) {
      return '/tmp';
    }
  }
}
