import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/models/order_model.dart';
import '../../core/services/pdf_service.dart';

class BookingSuccessScreen extends StatefulWidget {
  final String devoteeName;
  final String templeName;
  final String upiReference;

  const BookingSuccessScreen({
    super.key,
    required this.devoteeName,
    required this.templeName,
    required this.upiReference,
  });

  @override
  State<BookingSuccessScreen> createState() => _BookingSuccessScreenState();
}

class _BookingSuccessScreenState extends State<BookingSuccessScreen> {
  bool _isGeneratingPdf = false;

  Future<void> _downloadPdfReceipt() async {
    setState(() => _isGeneratingPdf = true);
    try {
      // Create a temporary mock OrderModel to generate the PDF receipt
      final mockOrder = OrderModel(
        id: 'BKG_${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}',
        userId: 'temp_user',
        userName: widget.devoteeName,
        templeId: 'temp_temple',
        templeName: widget.templeName,
        priestId: '',
        serviceId: 'temp_service',
        serviceName: 'Temple Worship (Group Sevas)',
        assignedPriest: '',
        assignedPriestName: 'Temple Priest',
        bookingDate: DateTime.now().add(const Duration(days: 1)).toString().split(' ')[0],
        bookingTime: '10:00 AM',
        amount: 0.0, // Amount is hidden or custom in success mockup
        status: 'pending',
        paymentStatus: 'success',
        paymentReference: widget.upiReference,
        jitsiLink: 'https://meet.jit.si/seva_${DateTime.now().millisecondsSinceEpoch}',
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );

      final bytes = await PdfService.generateReceiptBytes(mockOrder);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Receipt PDF generated (${bytes.length} bytes)'),
            action: SnackBarAction(
              label: 'OK',
              textColor: DivineTheme.gold,
              onPressed: () {},
            ),
            backgroundColor: DivineTheme.maroon,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating receipt: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGeneratingPdf = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              // Beautiful glowing diya lamp check circle
              Center(
                child: Container(
                  height: 100,
                  width: 100,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: DivineTheme.gold, width: 3),
                    boxShadow: DivineTheme.diyaGlow,
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    color: DivineTheme.saffron,
                    size: 64,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Booking Submitted!',
                style: Theme.of(context).textTheme.displayMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Your seva booking has been registered with the temple. Once verified by the administration, you will receive a notification and priest details.',
                style: TextStyle(color: DivineTheme.textLight, height: 1.5, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              // Booking Details summary Card
              Card(
                color: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      _buildDetailRow('Temple', widget.templeName),
                      const SizedBox(height: 10),
                      _buildDetailRow('Devotee', widget.devoteeName),
                      const SizedBox(height: 10),
                      _buildDetailRow('UPI Reference ID', widget.upiReference),
                      const SizedBox(height: 10),
                      _buildDetailRow('Status', 'Pending Verification', isHighlight: true),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              _isGeneratingPdf
                  ? const Center(child: CircularProgressIndicator(color: DivineTheme.maroon))
                  : ElevatedButton.icon(
                      onPressed: _downloadPdfReceipt,
                      icon: const Icon(Icons.picture_as_pdf),
                      label: const Text('DOWNLOAD PDF RECEIPT'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: DivineTheme.maroon,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                child: const Text(
                  'GO TO HOME',
                  style: TextStyle(color: DivineTheme.saffron, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isHighlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w500, color: DivineTheme.textLight),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isHighlight ? DivineTheme.saffron : DivineTheme.textDark,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}
