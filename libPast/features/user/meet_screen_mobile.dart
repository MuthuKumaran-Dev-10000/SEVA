import 'dart:io';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../core/theme.dart';

Widget getInAppMeetScreen(String url) => MobileMeetScreen(url: url);

class MobileMeetScreen extends StatefulWidget {
  final String url;
  const MobileMeetScreen({super.key, required this.url});

  @override
  State<MobileMeetScreen> createState() => _MobileMeetScreenState();
}

class _MobileMeetScreenState extends State<MobileMeetScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _isTest = false;

  @override
  void initState() {
    super.initState();
    _isTest = Platform.environment.containsKey('FLUTTER_TEST');
    if (!_isTest) {
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (_) {
              if (mounted) {
                setState(() => _isLoading = true);
              }
            },
            onPageFinished: (_) {
              if (mounted) {
                setState(() => _isLoading = false);
              }
            },
            onWebResourceError: (error) {
              debugPrint("WebView Error: ${error.description}");
            },
          ),
        )
        ..loadRequest(Uri.parse(widget.url));
    } else {
      _isLoading = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('In-App Video Stream', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: DivineTheme.maroon,
        elevation: 0,
      ),
      body: Stack(
        children: [
          _isTest
              ? const Center(child: Text('WebView Placeholder'))
              : WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(color: DivineTheme.maroon),
            ),
        ],
      ),
    );
  }
}
