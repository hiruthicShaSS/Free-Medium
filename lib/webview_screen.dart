import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:free_medium/appstate.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
              onPressed: toggleDarkMode,
              icon: const Icon(Icons.dark_mode),
            ),
            IconButton(
              onPressed: () async {
                await clearCache();

                await _webViewController!.reload();
              },
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: WillPopScope(
          onWillPop: () async {
            SharedPreferences prefs = await SharedPreferences.getInstance();
            prefs.remove("lastLinkLoaded");
            await _webViewController!.goBack();
            await clearCache();

            return _webViewController!.canGoBack();
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
                  backgroundColor: Colors.black,
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

                    SharedPreferences prefs =
                        await SharedPreferences.getInstance();
                    prefs.setString("lastLinkLoaded",
                        (await _webViewController!.currentUrl())!);

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

  Future<void> clearCache() async {
    String tempDir = (await getTemporaryDirectory()).path;
    String appDir = (await getApplicationDocumentsDirectory()).path;

    try {
      await Directory(tempDir).delete(recursive: true);
      await Directory(appDir).delete(recursive: true);
    } catch (_) {}

    await _webViewController!.clearCacheWithoutReload();
    await _webViewController!.runJavascriptReturningResult("""
      (function () {
        var cookies = document.cookie.split("; ");
        for (var c = 0; c < cookies.length; c++) {
            var d = window.location.hostname.split(".");
            while (d.length > 0) {
                var cookieBase = encodeURIComponent(cookies[c].split(";")[0].split("=")[0]) + '=; expires=Thu, 01-Jan-1970 00:00:01 GMT; domain=' + d.join('.') + ' ;path=';
                var p = location.pathname.split('/');
                document.cookie = cookieBase + '/';
                while (p.length > 0) {
                    document.cookie = cookieBase + p.join('/');
                    p.pop();
                };
                d.shift();
            }
        }
    })();
  """);

    CookieManager c = CookieManager();
    await c.clearCookies();
  }

  Future<void> toggleDarkMode() async {
    await _webViewController!
        .runJavascript("""var body=document.getElementsByTagName("BODY")[0];
                          var html=document.getElementsByTagName("HTML")[0];
                          html.style.backgroundColor="#303000";
                          body.style.backgroundColor="black";
                          body.style.color="#fff";
                          var tags=["FOOTER","HEADER","MAIN","SECTION",
                            "NAV","FORM",
                            "FONT","EM","B","I","U",
                            "INPUT","P","BUTTON","OL","UL","A","DIV",
                            "TD","TH","SPAN","LI",
                            "H1","H2","H3","H4","H5","H6",
                            "DD","DT",
                            "INCLUDE-FRAGMENT","ARTICLE"
                          ];
                          for(let tag of tags){
                            for(let item of document.getElementsByTagName(tag)){
                            item.style.backgroundColor="black";
                            item.style.color="#fff";
                            }
                          }
                          for(let tag of["CODE","PRE"]){
                            for(let item of document.getElementsByTagName(tag)){
                            item.style.backgroundColor="black";
                            item.style.color="green";
                            }
                          }
                          for(let tag of document.getElementsByTagName("INPUT")){
                            tag.style.border="solid 1px #bbb";
                          }
                          var videos=document.getElementsByTagName("VIDEO");
                          for(let video of videos){
                            video.style.backgroundColor="black";
                          }
                          for(let tag of document.getElementsByTagName("TH")){
                            tag.style.borderBottom="solid 1px yellow";
                          }
                          for(let tag of document.getElementsByTagName("A")){
                            tag.style.color="cyan";
                          }
 """);
  }
}
