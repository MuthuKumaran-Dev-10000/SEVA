import 'package:flutter/material.dart';
import 'dart:ui_web' as ui_web;
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import '../../core/theme.dart';

Widget getInAppMeetScreen(String url) => WebMeetScreen(url: url);

class WebMeetScreen extends StatefulWidget {
  final String url;
  const WebMeetScreen({super.key, required this.url});

  @override
  State<WebMeetScreen> createState() => _WebMeetScreenState();
}

class _WebMeetScreenState extends State<WebMeetScreen> {
  late final String _viewId;

  @override
  void initState() {
    super.initState();
    _viewId = 'iframe-meet-${DateTime.now().millisecondsSinceEpoch}';
    
    // Register the iframe element dynamically
    ui_web.platformViewRegistry.registerViewFactory(_viewId, (int viewId) {
      final iframe = html.IFrameElement()
        ..src = urlWithConfig(widget.url)
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..allow = 'camera; microphone; display-capture; autoplay; clipboard-write';
      return iframe;
    });
  }

  String urlWithConfig(String originalUrl) {
    // Add Jitsi meeting configurations for web to hide unnecessary chrome
    if (originalUrl.contains('#')) {
      return '$originalUrl&config.prejoinPageEnabled=false&config.startWithVideoMuted=false';
    } else {
      return '$originalUrl#config.prejoinPageEnabled=false&config.startWithVideoMuted=false';
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
      body: HtmlElementView(viewType: _viewId),
    );
  }
}
