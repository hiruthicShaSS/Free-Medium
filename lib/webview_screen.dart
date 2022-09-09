import 'dart:convert';

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
  int progress = 0;
  late WebViewController _webViewController;

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(builder: (context, appState, child) {
      if (appState.isNewLinkAvailable) {
        _webViewController.loadUrl(appState.link);
        appState.setNewLinkAvailablitiy = false;
      }

      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: WillPopScope(
          onWillPop: () async {
            _webViewController.goBack();
            return Future.value(false);
          },
          child: Column(
            children: [
              if (progress != 100)
                LinearProgressIndicator(
                  value: progress.toDouble(),
                  backgroundColor: Colors.black,
                ),
              Expanded(
                child: WebView(
                  initialUrl: widget.link,
                  javascriptMode: JavascriptMode.unrestricted,
                  onWebViewCreated: (controller) {
                    _webViewController = controller;
                  },
                  onProgress: (value) {
                    setState(() => progress = value);
                  },
                  onPageFinished: (value) async {
                    final html =
                        await _webViewController.runJavascriptReturningResult(
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
