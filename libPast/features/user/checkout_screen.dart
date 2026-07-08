import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../../core/theme.dart';
import '../../core/services/auth_provider.dart';
import '../../core/services/app_provider.dart';
import 'booking_success_screen.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  final _upiRefController = TextEditingController();
  final List<String> _selectedParticipants = [];

  late Razorpay _razorpay;
  String _selectedPaymentMethod = 'razorpay'; // 'razorpay' or 'upi_manual'

  @override
  void initState() {
    super.initState();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    _nameController = TextEditingController(text: auth.currentUser?.name);
    _phoneController = TextEditingController(text: auth.currentUser?.phone);
    _emailController = TextEditingController(text: auth.currentUser?.email);

    if (auth.currentUser != null) {
      _selectedParticipants.add(auth.currentUser!.name);
    }

    // Initialize Razorpay
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _upiRefController.dispose();
    _razorpay.clear(); // Clear Razorpay instance
    super.dispose();
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    final app = Provider.of<AppProvider>(context, listen: false);
    final auth = Provider.of<AuthProvider>(context, listen: false);

    final paymentId = response.paymentId ?? 'pay_razorpay_${DateTime.now().millisecondsSinceEpoch}';
    final name = _nameController.text.trim();

    String templeName = 'Divine Service';
    if (app.cart.isNotEmpty) {
      final firstItem = app.cart.first;
      try {
        templeName = app.temples.firstWhere((t) => t.id == firstItem.service.templeId).name;
      } catch (_) {}
    }

    await app.bookCartServices(
      userId: auth.currentUser!.uid,
      userName: name,
      paymentRef: paymentId,
      participants: _selectedParticipants,
    );

    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => BookingSuccessScreen(
            devoteeName: name,
            templeName: templeName,
            upiReference: paymentId,
          ),
        ),
        (route) => route.isFirst,
      );
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment Failed: ${response.message ?? "User cancelled payment"}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('External Wallet Selected: ${response.walletName}'),
          backgroundColor: DivineTheme.saffron,
        ),
      );
    }
  }

  void _payWithRazorpay(double amount) {
    if (!_formKey.currentState!.validate()) return;

    var options = {
      'key': 'rzp_test_SzBkemjjVqb8Ap',
      'amount': (amount * 100).toInt(), // amount in paise
      'name': 'SevaSetu',
      'description': 'Payment for spiritual services',
      'prefill': {
        'contact': _phoneController.text.trim(),
        'email': _emailController.text.trim(),
      },
      'external': {
        'wallets': ['paytm']
      }
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      debugPrint("Razorpay Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not initialize payment gateway: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _submitBookingUPI(AppProvider app, AuthProvider auth) async {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final upiRef = _upiRefController.text.trim();

    String templeName = 'Divine Service';
    if (app.cart.isNotEmpty) {
      final firstItem = app.cart.first;
      try {
        templeName = app.temples.firstWhere((t) => t.id == firstItem.service.templeId).name;
      } catch (_) {}
    }

    await app.bookCartServices(
      userId: auth.currentUser!.uid,
      userName: name,
      paymentRef: upiRef,
      participants: _selectedParticipants,
    );

    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => BookingSuccessScreen(
            devoteeName: name,
            templeName: templeName,
            upiReference: upiRef,
          ),
        ),
        (route) => route.isFirst,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final app = Provider.of<AppProvider>(context);

    // Bill Calculations
    final double itemTotal = app.cartTotal;
    final double sacredFee = itemTotal * 0.05; // 5% Sacred Maintenance Fee
    final double platformFee = itemTotal > 0 ? 10.0 : 0.0;
    final double grandTotal = itemTotal + sacredFee + platformFee;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      appBar: AppBar(
        title: const Text('Review Cart', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
        backgroundColor: DivineTheme.maroon,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. SELECTED SERVICES (Cart items summary)
                    Text('Puja Bookings (${app.cart.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: DivineTheme.textDark)),
                    const SizedBox(height: 10),
                    Card(
                      color: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          children: app.cart.map((item) {
                            return ListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              leading: const Icon(Icons.circle, color: DivineTheme.saffron, size: 8),
                              title: Text('${item.service.name} (Qty: ${item.quantity})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: DivineTheme.textDark)),
                              subtitle: Text('Slot: ${item.selectedDate} @ ${item.selectedTimeSlot}', style: const TextStyle(fontSize: 10, color: DivineTheme.textLight)),
                              trailing: Text('₹${(item.service.amount * item.quantity).toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: DivineTheme.textDark)),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 2. DEVOTEE BILLING CARD
                    const Text('Devotee Billing Info', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: DivineTheme.textDark)),
                    const SizedBox(height: 10),
                    Card(
                      color: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _nameController,
                              style: const TextStyle(fontSize: 13),
                              decoration: const InputDecoration(
                                labelText: 'Devotee Name',
                                prefixIcon: Icon(Icons.person, color: DivineTheme.maroon, size: 20),
                                contentPadding: EdgeInsets.all(12),
                              ),
                              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _phoneController,
                              style: const TextStyle(fontSize: 13),
                              decoration: const InputDecoration(
                                labelText: 'Contact Phone',
                                prefixIcon: Icon(Icons.phone, color: DivineTheme.maroon, size: 20),
                                contentPadding: EdgeInsets.all(12),
                              ),
                              keyboardType: TextInputType.phone,
                              validator: (v) => v == null || v.length < 10 ? 'Enter valid phone number' : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _emailController,
                              style: const TextStyle(fontSize: 13),
                              decoration: const InputDecoration(
                                labelText: 'Billing Email',
                                prefixIcon: Icon(Icons.email, color: DivineTheme.maroon, size: 20),
                                contentPadding: EdgeInsets.all(12),
                              ),
                              keyboardType: TextInputType.emailAddress,
                              validator: (v) => v == null || !v.contains('@') ? 'Enter valid email' : null,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 2b. SELECT DEVOTEES (FAMILY MEMBERS & SELF)
                    const Text('Select Devotees (Participants)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: DivineTheme.textDark)),
                    const SizedBox(height: 10),
                    Card(
                      color: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Column(
                          children: [
                            if (auth.currentUser != null)
                              CheckboxListTile(
                                activeColor: DivineTheme.maroon,
                                title: Text('${auth.currentUser!.name} (Self)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: DivineTheme.textDark)),
                                subtitle: const Text('Account Holder', style: TextStyle(fontSize: 10, color: DivineTheme.textLight)),
                                value: _selectedParticipants.contains(auth.currentUser!.name),
                                onChanged: (selected) {
                                  setState(() {
                                    if (selected == true) {
                                      _selectedParticipants.add(auth.currentUser!.name);
                                    } else {
                                      _selectedParticipants.remove(auth.currentUser!.name);
                                    }
                                  });
                                },
                              ),
                            if (app.familyMembers.isNotEmpty) ...[
                              Divider(height: 1, color: Colors.grey.shade100),
                              ...app.familyMembers.map((member) {
                                final isSelected = _selectedParticipants.contains(member.name);
                                return CheckboxListTile(
                                  activeColor: DivineTheme.maroon,
                                  title: Text(member.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: DivineTheme.textDark)),
                                  subtitle: Text('${member.relationship} • Rasi: ${member.rasi.isEmpty ? "N/A" : member.rasi} • Nakshatra: ${member.nakshatra.isEmpty ? "N/A" : member.nakshatra}', style: const TextStyle(fontSize: 10, color: DivineTheme.textLight)),
                                  value: isSelected,
                                  onChanged: (selected) {
                                    setState(() {
                                      if (selected == true) {
                                        _selectedParticipants.add(member.name);
                                      } else {
                                        _selectedParticipants.remove(member.name);
                                      }
                                    });
                                  },
                                );
                              }),
                            ] else ...[
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                                child: Row(
                                  children: [
                                    const Icon(Icons.info_outline, color: DivineTheme.maroon, size: 16),
                                    const SizedBox(width: 8),
                                    const Expanded(
                                      child: Text(
                                        'No family members added. You can add them under the Family Profiles tab on the home screen.',
                                        style: TextStyle(fontSize: 11, color: DivineTheme.textLight),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 3. PAYMENT METHOD SELECTOR
                    const Text('Select Payment Mode', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: DivineTheme.textDark)),
                    const SizedBox(height: 10),
                    Card(
                      color: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
                      child: Column(
                        children: [
                          RadioListTile<String>(
                            title: const Text('Instant Gateway (Razorpay)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: DivineTheme.textDark)),
                            subtitle: const Text('UPI, Netbanking, Cards (Test Mode)', style: TextStyle(fontSize: 11, color: DivineTheme.textLight)),
                            value: 'razorpay',
                            groupValue: _selectedPaymentMethod,
                            activeColor: DivineTheme.saffron,
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedPaymentMethod = val);
                            },
                          ),
                          Divider(height: 1, color: Colors.grey.shade100),
                          RadioListTile<String>(
                            title: const Text('Manual UPI Reference ID', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: DivineTheme.textDark)),
                            subtitle: const Text('Scan QR & enter 12-digit transaction ID', style: TextStyle(fontSize: 11, color: DivineTheme.textLight)),
                            value: 'upi_manual',
                            groupValue: _selectedPaymentMethod,
                            activeColor: DivineTheme.saffron,
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedPaymentMethod = val);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Manual UPI block if selected
                    if (_selectedPaymentMethod == 'upi_manual') ...[
                      Center(
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: DivineTheme.gold, width: 1.5),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: DivineTheme.softShadow,
                          ),
                          child: Column(
                            children: [
                              Container(
                                height: 120,
                                width: 120,
                                color: DivineTheme.creamDark,
                                child: const Icon(Icons.qr_code_2, size: 90, color: DivineTheme.maroon),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'UPI ID: sevasetu@upi',
                                style: TextStyle(fontWeight: FontWeight.bold, color: DivineTheme.maroon, fontSize: 13),
                              ),
                              Text(
                                'Amount to pay: ₹${grandTotal.toStringAsFixed(2)}',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _upiRefController,
                        style: const TextStyle(fontSize: 13),
                        decoration: const InputDecoration(
                          labelText: 'UPI 12-digit Reference ID',
                          prefixIcon: Icon(Icons.receipt, color: DivineTheme.maroon, size: 20),
                          hintText: 'e.g. 234567890123',
                          contentPadding: EdgeInsets.all(12),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          if (_selectedPaymentMethod == 'upi_manual') {
                            if (v == null || v.length != 12 || int.tryParse(v) == null) {
                              return 'Must be exact 12-digit number';
                            }
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                    ],

                    // 4. BILL DETAILS (SWIGGY-STYLE)
                    const Text('Bill Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: DivineTheme.textDark)),
                    const SizedBox(height: 10),
                    Card(
                      color: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Item Total', style: TextStyle(fontSize: 12, color: DivineTheme.textLight)),
                                Text('₹${itemTotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, color: DivineTheme.textDark, fontWeight: FontWeight.w500)),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Sacred / Temple Maintenance (5%)', style: TextStyle(fontSize: 12, color: DivineTheme.textLight)),
                                Text('₹${sacredFee.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, color: DivineTheme.textDark, fontWeight: FontWeight.w500)),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Convenience/Platform Donation', style: TextStyle(fontSize: 12, color: DivineTheme.textLight)),
                                Text('₹${platformFee.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, color: DivineTheme.textDark, fontWeight: FontWeight.w500)),
                              ],
                            ),
                            const Divider(height: 24, thickness: 0.8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Grand Total', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: DivineTheme.textDark)),
                                Text('₹${grandTotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.green)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
          ),
          
          // Sticky Bottom Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, -4)),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('₹${grandTotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: DivineTheme.textDark)),
                        const Text('Grand Total', style: TextStyle(fontSize: 10, color: DivineTheme.textLight, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () {
                        if (_selectedPaymentMethod == 'razorpay') {
                          _payWithRazorpay(grandTotal);
                        } else {
                          _submitBookingUPI(app, auth);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: DivineTheme.saffron,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        _selectedPaymentMethod == 'razorpay' ? 'PAY WITH RAZORPAY' : 'SUBMIT UPI REF',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white, letterSpacing: 0.5),
                      ),
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
}
