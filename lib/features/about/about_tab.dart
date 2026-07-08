import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme.dart';

class AboutTab extends StatefulWidget {
  const AboutTab({super.key});

  @override
  State<AboutTab> createState() => _AboutTabState();
}

class _AboutTabState extends State<AboutTab> {
  final _formKey = GlobalKey<FormState>();
  final _messageController = TextEditingController();
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _messageController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _sendFeedback() {
    if (_formKey.currentState?.validate() ?? false) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Message sent successfully! We will get back to you soon.'),
          backgroundColor: SevaTheme.primaryMaroon,
        ),
      );
      _messageController.clear();
      _emailController.clear();
    }
  }

  Future<void> _launchEmail() async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: 'muthukumarandeveloper@gmail.com',
      queryParameters: {
        'subject': 'Inquiry regarding Seva App',
      },
    );
    try {
      if (await canLaunchUrl(emailLaunchUri)) {
        await launchUrl(emailLaunchUri);
      } else {
        throw 'Could not launch $emailLaunchUri';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open email client: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Banner/Logo
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24),
            decoration: BoxDecoration(
              color: SevaTheme.primaryMaroon.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: SevaTheme.primaryMaroon.withOpacity(0.1)),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.temple_hindu,
                  size: 64,
                  color: SevaTheme.secondaryGold,
                ),
                const SizedBox(height: 12),
                Text(
                  'SEVA',
                  style: GoogleFonts.outfit(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: SevaTheme.primaryMaroon,
                  ),
                ),
                Text(
                  'Connecting Devotion & Convenience',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: SevaTheme.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // About Section
          Text(
            'About Seva',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: SevaTheme.primaryMaroon,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Seva is a modern, premium spiritual booking platform built to connect devotees with historic temples and priests. Our goal is to preserve divine traditions by offering seamless online slot reservations, archana bookings, and special prayers directly through a unified mobile and web interface. By coordinating directly with temple administrations, Seva ensures that every ritual is handled with care, reverence, and transparency.',
            style: GoogleFonts.outfit(
              fontSize: 14,
              height: 1.5,
              color: SevaTheme.textCharcoal,
            ),
          ),
          const SizedBox(height: 24),

          // Contact developer section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: SevaTheme.secondaryGold.withOpacity(0.2),
                        child: const Icon(Icons.person, color: SevaTheme.primaryMaroon),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Developer & Owner',
                            style: GoogleFonts.outfit(fontSize: 12, color: SevaTheme.textMuted, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Muthukumaran S',
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: SevaTheme.primaryMaroon,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'For custom software inquiries, technical queries, or deployment help, feel free to contact us:',
                    style: GoogleFonts.outfit(fontSize: 13, color: SevaTheme.textMuted),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: _launchEmail,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                      decoration: BoxDecoration(
                        color: SevaTheme.primaryMaroon.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.email_outlined, size: 18, color: SevaTheme.primaryMaroon),
                          const SizedBox(width: 8),
                          Text(
                            'muthukumarandeveloper@gmail.com',
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: SevaTheme.primaryMaroon,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Quick Inquiry Form
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Quick Inquiry',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: SevaTheme.primaryMaroon,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Your Email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (value) => value == null || value.isEmpty ? 'Please enter email' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _messageController,
                  decoration: const InputDecoration(
                    labelText: 'Message / Query',
                    prefixIcon: Icon(Icons.message_outlined),
                  ),
                  maxLines: 3,
                  validator: (value) => value == null || value.isEmpty ? 'Please enter a message' : null,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _sendFeedback,
                  child: const Text('Submit Query'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
