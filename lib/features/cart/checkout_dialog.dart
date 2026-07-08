import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/providers/cart_provider.dart';
import '../../core/theme.dart';
import '../auth/login_signup_sheet.dart';

class CheckoutDialog extends StatefulWidget {
  const CheckoutDialog({super.key});

  @override
  State<CheckoutDialog> createState() => _CheckoutDialogState();
}

class _CheckoutDialogState extends State<CheckoutDialog> {
  
  @override
  void initState() {
    super.initState();
    // Fetch family members list immediately on open to ensure dropdown is fresh
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.isLoggedIn) {
      auth.fetchFamilyMembers();
    }
  }

  void _openLoginSheet() {
    Navigator.pop(context); // Close cart dialog first
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const LoginSignupSheet(),
    );
  }

  void _showRazorpaySheet(BuildContext context, AuthProvider auth, CartProvider cart) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            bool isProcessing = false;
            String statusText = "";
            String selectedMethod = "UPI"; // "UPI", "Card", "Netbanking"

            void startMockPayment() async {
              setSheetState(() {
                isProcessing = true;
                statusText = "Connecting with Razorpay Secure...";
              });
              await Future.delayed(const Duration(milliseconds: 1000));
              if (!context.mounted) return;
              setSheetState(() {
                statusText = "Authorizing Transaction...";
              });
              await Future.delayed(const Duration(milliseconds: 1000));
              if (!context.mounted) return;
              setSheetState(() {
                statusText = "Processing Booking Seats...";
              });
              
              // Proceed with actual database write
              final success = await cart.processCheckout(auth.currentUser!['id'], auth);
              if (!context.mounted) return;
              
              if (success) {
                Navigator.pop(context); // Close Razorpay sheet
                Navigator.pop(context); // Close Cart dialog
                
                // Show booking confirmation success dialog
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.green, size: 28),
                        const SizedBox(width: 8),
                        Text(
                          'Payment Success!',
                          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.green),
                        ),
                      ],
                    ),
                    content: Text(
                      'Razorpay Payment ID: pay_${DateTime.now().millisecondsSinceEpoch}\n\nYour Seva slots have been successfully locked and paid. Enjoy your divine experience!',
                      style: GoogleFonts.outfit(),
                    ),
                    actions: [
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Great'),
                      ),
                    ],
                  ),
                );
              } else {
                setSheetState(() {
                  isProcessing = false;
                  statusText = "";
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(cart.errorMessage ?? 'Payment checkout failed.')),
                );
              }
            }

            return Container(
              height: 400,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: isProcessing
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(color: Color(0xFF1E3A8A)),
                          const SizedBox(height: 20),
                          Text(
                            statusText,
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1E3A8A),
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Please do not close this window or click back.',
                            style: GoogleFonts.outfit(color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Razorpay Header Bar
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          decoration: const BoxDecoration(
                            color: Color(0xFF0F172A), // Dark Slate blue
                            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'RAZORPAY SECURE',
                                    style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      fontSize: 14,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                  Text(
                                    'Order: ord_${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}',
                                    style: GoogleFonts.outfit(color: Colors.white60, fontSize: 10),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  const Icon(Icons.shield, color: Colors.blueAccent, size: 16),
                                  const SizedBox(width: 4),
                                  Text(
                                    '100% SECURE',
                                    style: GoogleFonts.outfit(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              )
                            ],
                          ),
                        ),
                        
                        // Price Banner
                        Container(
                          color: const Color(0xFF1E293B),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Seva Booking Services',
                                style: GoogleFonts.outfit(color: Colors.white70, fontSize: 12),
                              ),
                              Text(
                                '₹${cart.totalPrice}',
                                style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ],
                          ),
                        ),
                        
                        // Payment Body
                        Expanded(
                          child: Row(
                            children: [
                              // Left sidebar of categories
                              Container(
                                width: 120,
                                color: Colors.grey.shade100,
                                child: Column(
                                  children: [
                                    _buildPaymentSidebarBtn(
                                      icon: Icons.qr_code,
                                      label: "UPI / QR",
                                      isSelected: selectedMethod == "UPI",
                                      onTap: () => setSheetState(() => selectedMethod = "UPI"),
                                    ),
                                    _buildPaymentSidebarBtn(
                                      icon: Icons.credit_card,
                                      label: "Cards",
                                      isSelected: selectedMethod == "Card",
                                      onTap: () => setSheetState(() => selectedMethod = "Card"),
                                    ),
                                    _buildPaymentSidebarBtn(
                                      icon: Icons.account_balance,
                                      label: "Netbanking",
                                      isSelected: selectedMethod == "Netbanking",
                                      onTap: () => setSheetState(() => selectedMethod = "Netbanking"),
                                    ),
                                  ],
                                ),
                              ),
                              
                              // Right panel of options
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  child: selectedMethod == "UPI"
                                      ? Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('Pay using UPI', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13)),
                                            const SizedBox(height: 10),
                                            ListTile(
                                              dense: true,
                                              contentPadding: EdgeInsets.zero,
                                              leading: const Icon(Icons.send_to_mobile, color: Colors.blueAccent),
                                              title: Text('Google Pay / PhonePe', style: GoogleFonts.outfit(fontSize: 12)),
                                              onTap: startMockPayment,
                                            ),
                                            ListTile(
                                              dense: true,
                                              contentPadding: EdgeInsets.zero,
                                              leading: const Icon(Icons.qr_code_scanner, color: Colors.blueAccent),
                                              title: Text('Scan QR Code', style: GoogleFonts.outfit(fontSize: 12)),
                                              onTap: startMockPayment,
                                            ),
                                          ],
                                        )
                                      : selectedMethod == "Card"
                                          ? Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text('Credit / Debit Card', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13)),
                                                const SizedBox(height: 10),
                                                TextFormField(
                                                  decoration: const InputDecoration(
                                                    labelText: 'Card Number',
                                                    hintText: '4312 •••• •••• 4312',
                                                    prefixIcon: Icon(Icons.credit_card),
                                                  ),
                                                  initialValue: "4312 8765 4321 8901",
                                                  readOnly: true,
                                                ),
                                                const SizedBox(height: 12),
                                                ElevatedButton(
                                                  onPressed: startMockPayment,
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: const Color(0xFF1E3A8A),
                                                    minimumSize: const Size.fromHeight(40),
                                                  ),
                                                  child: Text('Pay ₹${cart.totalPrice}', style: GoogleFonts.outfit(fontSize: 12)),
                                                )
                                              ],
                                            )
                                          : Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text('Netbanking', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13)),
                                                const SizedBox(height: 10),
                                                ListTile(
                                                  dense: true,
                                                  contentPadding: EdgeInsets.zero,
                                                  leading: const Icon(Icons.food_bank_outlined, color: Colors.green),
                                                  title: Text('State Bank of India', style: GoogleFonts.outfit(fontSize: 12)),
                                                  onTap: startMockPayment,
                                                ),
                                                ListTile(
                                                  dense: true,
                                                  contentPadding: EdgeInsets.zero,
                                                  leading: const Icon(Icons.food_bank_outlined, color: Colors.red),
                                                  title: Text('HDFC Bank', style: GoogleFonts.outfit(fontSize: 12)),
                                                  onTap: startMockPayment,
                                                ),
                                              ],
                                            ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
            );
          },
        );
      },
    );
  }

  Widget _buildPaymentSidebarBtn({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        color: isSelected ? Colors.white : Colors.transparent,
        child: Column(
          children: [
            Icon(icon, color: isSelected ? const Color(0xFF1E3A8A) : Colors.grey, size: 18),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? const Color(0xFF1E3A8A) : Colors.grey.shade700,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final cart = Provider.of<CartProvider>(context);

    return AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Seva Cart',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: SevaTheme.primaryMaroon),
          ),
          if (cart.items.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined, color: Colors.redAccent),
              tooltip: 'Clear Cart',
              onPressed: () => cart.clearCart(),
            ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: cart.items.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.shopping_basket_outlined, size: 48, color: SevaTheme.textMuted.withOpacity(0.5)),
                      const SizedBox(height: 12),
                      Text(
                        'Your cart is empty.',
                        style: GoogleFonts.outfit(color: SevaTheme.textMuted),
                      ),
                    ],
                  ),
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (cart.errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                      ),
                      child: Text(
                        cart.errorMessage!,
                        style: GoogleFonts.outfit(color: Colors.red[900], fontSize: 12),
                      ),
                    ),
                  
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: cart.items.length,
                      itemBuilder: (context, index) {
                        final item = cart.items[index];
                        
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          elevation: 1,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item.serviceName,
                                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                    ),
                                    IconButton(
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      icon: const Icon(Icons.close, size: 16, color: Colors.grey),
                                      onPressed: () => cart.removeItem(item.serviceId),
                                    ),
                                  ],
                                ),
                                Text(
                                  item.templeName,
                                  style: GoogleFonts.outfit(fontSize: 11, color: SevaTheme.secondaryGold, fontWeight: FontWeight.w500),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Date: ${item.bookingDate} | ${item.slotTime}',
                                      style: GoogleFonts.outfit(fontSize: 11, color: SevaTheme.textMuted),
                                    ),
                                    Text(
                                      '₹${item.price}',
                                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13, color: SevaTheme.primaryMaroon),
                                    ),
                                  ],
                                ),
                                
                                if (auth.isLoggedIn) ...[
                                  const SizedBox(height: 10),
                                  // Attendee Dropdown Selection
                                  (() {
                                    final devoteeName = auth.currentUser?['full_name'] ?? 'Devotee';
                                    final dropdownItems = auth.familyMembers.isEmpty
                                        ? [
                                            DropdownMenuItem<String>(
                                              value: devoteeName,
                                              child: Text(devoteeName, style: GoogleFonts.outfit(fontSize: 13)),
                                            )
                                          ]
                                        : auth.familyMembers.map<DropdownMenuItem<String>>((member) {
                                            return DropdownMenuItem<String>(
                                              value: member['name'] as String,
                                              child: Text(
                                                member['name'] as String,
                                                style: GoogleFonts.outfit(fontSize: 13),
                                              ),
                                            );
                                          }).toList();
 
                                    String activeAttendee = item.attendeeName.isEmpty ? devoteeName : item.attendeeName;
                                    final hasActiveVal = dropdownItems.any((e) => e.value == activeAttendee);
                                    if (!hasActiveVal && dropdownItems.isNotEmpty) {
                                      activeAttendee = dropdownItems.first.value ?? devoteeName;
                                    }
 
                                    return DropdownButtonFormField<String>(
                                      value: activeAttendee,
                                      decoration: const InputDecoration(
                                        labelText: 'Select Attendee *',
                                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      ),
                                      items: dropdownItems,
                                      onChanged: (val) {
                                        if (val != null) {
                                          cart.updateAttendee(item.serviceId, val);
                                        }
                                      },
                                    );
                                  }()),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Payable:',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      Text(
                        '₹${cart.totalPrice}',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18, color: SevaTheme.primaryMaroon),
                      ),
                    ],
                  ),
 
                  if (!auth.isLoggedIn) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: SevaTheme.secondaryGold.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: SevaTheme.secondaryGold.withOpacity(0.2)),
                      ),
                      child: Text(
                        '⚠️ You must sign in or register to set attendee details and finish booking.',
                        style: GoogleFonts.outfit(fontSize: 12, color: SevaTheme.textCharcoal),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Close', style: GoogleFonts.outfit(color: SevaTheme.textMuted)),
        ),
        if (cart.items.isNotEmpty)
          auth.isLoggedIn
              ? ElevatedButton(
                  onPressed: () => _showRazorpaySheet(context, auth, cart),
                  child: const Text('Pay & Book Now'),
                )
              : ElevatedButton(
                  onPressed: _openLoginSheet,
                  child: const Text('Login to Checkout'),
                ),
      ],
    );
  }
}
