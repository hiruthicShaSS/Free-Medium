import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:free_medium/appstate.dart';
import 'package:free_medium/webview_screen.dart';
import 'package:notifications/notifications.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:uni_links/uni_links.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  AwesomeNotifications().initialize(
    null,
    [
      NotificationChannel(
        channelGroupKey: 'basic_channel_group',
        channelKey: 'basic_channel',
        channelName: 'Basic notifications',
        channelDescription: 'Notification channel for basic tests',
        defaultColor: const Color(0xFF9D50DD),
        ledColor: Colors.white,
        criticalAlerts: true,
        importance: NotificationImportance.Max,
        playSound: true,
      )
    ],
    // Channel groups are only visual and are not required
    channelGroups: [
      NotificationChannelGroup(
          channelGroupkey: 'basic_channel_group',
          channelGroupName: 'Basic group')
    ],
    debug: kDebugMode,
  );

  final appDir = (await getTemporaryDirectory()).path;
  await Directory(appDir).delete(recursive: true);

  var appDocDir = await getApplicationDocumentsDirectory();

  if (appDocDir.existsSync()) {
    appDocDir.deleteSync(recursive: true);
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(link: "https://www.medium.com"),
      builder: (_, __) => MaterialApp(
        title: 'Free Medium',
        themeMode: ThemeMode.dark,
        darkTheme: ThemeData.dark(),
        home: const MyHomePage(title: 'Flutter Demo Home Page'),
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late StreamSubscription _intentDataStreamSubscription;
  late StreamSubscription _sub;
  String? link;

  late Future<String?> _initialDeepLinkFuture;

  int progress = 0;

  @override
  void initState() {
    super.initState();
    _initialDeepLinkFuture = initUniLinks();

    Notifications notifications = Notifications();
    notifications.notificationStream!.listen((event) {
      if (event.packageName == "com.medium.reader") {
        log("Captured a notification: $event");

        AwesomeNotifications().createNotification(
          content: NotificationContent(
            id: 1,
            channelKey: "basic_channel",
            title: event.title,
            body: "Read this on Free Medium",
            criticalAlert: true,
          ),
        );
      }
    });
  }

  @override
  void didChangeDependencies() async {
    _intentDataStreamSubscription =
        ReceiveSharingIntent.getTextStream().listen((String value) {
      Provider.of<AppState>(context, listen: false).updateLink(value.trim());
    }, onError: (err) {
      log("getLinkStream error:", error: err);
    });

    String? initialSharedLink = await ReceiveSharingIntent.getInitialText();

    if (initialSharedLink != null) {
      if (!mounted) return;

      Provider.of<AppState>(context, listen: false)
          .updateLink(initialSharedLink);
    }

    _sub = linkStream.listen(
      (link) {
        if (link != null) {
          Provider.of<AppState>(context, listen: false).updateLink(link.trim());
        }
      },
      onError: (e) => log("Error on deeplink stream:", error: e),
    );

    super.didChangeDependencies();
  }

  @override
  void dispose() {
    _sub.cancel();
    _intentDataStreamSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _initialDeepLinkFuture,
      builder: (_, future) {
        if (future.hasError) {
          log("Error in deep link future:", error: future.error);
        }

        if (future.connectionState == ConnectionState.done) {
          if (future.data != null) {
            Provider.of<AppState>(context, listen: false).link =
                future.data!.trim();
          }

          return WebviewScreen(
              link: Provider.of<AppState>(context, listen: false).link);
        }

        return const CircularProgressIndicator();
      },
    );
  }

  Future<String?> initUniLinks() async {
    try {
      final initialLink = await getInitialLink();
      log("Deep link: $initialLink");

      return initialLink;
    } on PlatformException catch (e) {
      log("Error getting deep link", error: e);
    }

    return null;
  }
}
