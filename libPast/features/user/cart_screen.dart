import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../core/services/app_provider.dart';
import 'checkout_screen.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = Provider.of<AppProvider>(context);

    // Bill Calculations
    final double itemTotal = app.cartTotal;
    final double sacredFee = itemTotal * 0.05; // 5% Sacred Maintenance Fee
    final double platformFee = itemTotal > 0 ? 10.0 : 0.0;
    final double grandTotal = itemTotal + sacredFee + platformFee;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      appBar: AppBar(
        title: const Text('Spiritual Cart', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
        backgroundColor: DivineTheme.maroon,
        elevation: 0,
      ),
      body: app.cart.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: DivineTheme.creamDark,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.shopping_basket_outlined, size: 64, color: DivineTheme.maroon),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Your cart is empty',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: DivineTheme.textDark),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Explore services and add them to your cart to book virtual/in-person pujas.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: DivineTheme.textLight),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: DivineTheme.maroon,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 16),
                      ),
                      child: const Text('EXPLORE SERVICES', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Selected Services Section
                        const Text(
                          'Selected Services',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: DivineTheme.textDark),
                        ),
                        const SizedBox(height: 10),
                        Card(
                          color: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: Colors.grey.shade200),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: app.cart.length,
                              separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade100),
                              itemBuilder: (context, index) {
                                final s = app.cart[index];
                                  return ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    title: Text(
                                      s.service.name,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: DivineTheme.textDark),
                                    ),
                                    subtitle: Text(
                                      'Slot: ${s.selectedDate} @ ${s.selectedTimeSlot}\n₹${s.service.amount.toStringAsFixed(0)} each',
                                      style: const TextStyle(color: DivineTheme.textLight, fontSize: 11, height: 1.4),
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          '₹${(s.service.amount * s.quantity).toStringAsFixed(0)}',
                                          style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13),
                                        ),
                                        const SizedBox(width: 16),
                                        Container(
                                          height: 30,
                                          width: 80,
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(15),
                                            border: Border.all(color: DivineTheme.saffron, width: 1.5),
                                          ),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              InkWell(
                                                onTap: () => app.decrementQuantity(s),
                                                child: const Padding(
                                                  padding: EdgeInsets.symmetric(horizontal: 6),
                                                  child: Icon(Icons.remove, size: 12, color: DivineTheme.saffron),
                                                ),
                                              ),
                                              Text(
                                                '${s.quantity}',
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: DivineTheme.saffron),
                                              ),
                                              InkWell(
                                                onTap: () => app.incrementQuantity(s),
                                                child: const Padding(
                                                  padding: EdgeInsets.symmetric(horizontal: 6),
                                                  child: Icon(Icons.add, size: 12, color: DivineTheme.saffron),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Bill Details Card
                        const Text(
                          'Bill Details',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: DivineTheme.textDark),
                        ),
                        const SizedBox(height: 10),
                        Card(
                          color: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: Colors.grey.shade200),
                          ),
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
                                    const Text('Platform Donation (SevaSetu)', style: TextStyle(fontSize: 12, color: DivineTheme.textLight)),
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
                        const SizedBox(height: 16),
                        // Safe and Clean details disclaimer
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: Row(
                            children: const [
                              Icon(Icons.shield_outlined, color: DivineTheme.saffron, size: 16),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Your contribution directly supports temple priests and maintenance.',
                                  style: TextStyle(fontSize: 11, color: DivineTheme.textLight),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const CheckoutScreen()),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: DivineTheme.saffron,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text(
                              'PROCEED TO CHECKOUT',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white, letterSpacing: 0.5),
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

