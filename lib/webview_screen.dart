import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:free_medium/appstate.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:html/dom.dart' as dom;

class WebviewScreen extends StatefulWidget {
  const WebviewScreen({Key? key, required this.link}) : super(key: key);

  final String link;

  @override
  State<WebviewScreen> createState() => _WebviewScreenState();
}

class _WebviewScreenState extends State<WebviewScreen> {
  String title = "Loading page...";
  int? progress;
  WebViewController? _webViewController;

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(builder: (context, appState, child) {
      if (appState.isNewLinkAvailable) {
        if (_webViewController != null) {
          _webViewController?.loadUrl(appState.link);
          appState.setNewLinkAvailablitiy = false;
        }
      }

      return Scaffold(
        appBar: AppBar(
          title: Text(title),
          actions: [
            IconButton(
              onPressed: () async => _webViewController!.reload(),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: WillPopScope(
          onWillPop: () async {
            await _webViewController!.goBack();
            await _webViewController!.runJavascriptReturningResult(
                "localStorage.clear();sessionStorage.clear();");
            await _webViewController!.runJavascriptReturningResult(
                r'document.cookie.split(";").forEach(function(c) { document.cookie = c.replace(/^ +/, "").replace(/=.*/, "=;expires=" + new Date().toUTCString() + ";path=/"); });');
            await _webViewController!.clearCacheWithoutReload();
            return Future.value(false);
          },
          child: Column(
            children: [
              if (progress != null)
                LinearProgressIndicator(
                  value: progress == 0 ? null : progress!.toDouble(),
                  backgroundColor: Colors.black,
                ),
              Expanded(
                child: WebView(
                  initialUrl: widget.link,
                  javascriptMode: JavascriptMode.unrestricted,
                  allowsInlineMediaPlayback: true,
                  zoomEnabled: true,
                  gestureNavigationEnabled: true,
                  onWebViewCreated: (controller) async {
                    _webViewController = controller;

                    if (appState.isNewLinkAvailable) {
                      _webViewController?.loadUrl(appState.link);
                      appState.setNewLinkAvailablitiy = false;
                    }
                  },
                  onProgress: (value) {
                    setState(() => progress = value);
                    if (value == 100) progress = null;
                  },
                  onPageFinished: (value) async {
                    final html = await _webViewController!
                        .runJavascriptReturningResult(
                            "new XMLSerializer().serializeToString(document)");

                    dom.Document doc = dom.Document.html(jsonDecode(html));
                    List<String> titles = doc
                        .getElementsByTagName("title")
                        .map((e) => e.text)
                        .toList();

                    setState(() =>
                        title = titles.isNotEmpty ? titles.first : "No title");
                  },
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}
