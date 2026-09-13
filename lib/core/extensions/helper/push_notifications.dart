// ignore_for_file: empty_catches

import 'dart:collection';
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import '../../services/config.dart';
import '../../utils/common_widget.dart';
import '../workspace.dart';
 import '../../services/http.dart';

late AndroidNotificationChannel channel;
bool isFlutterLocalNotificationsInitialized = false;
late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;
bool isOneSignalListenerAdded = false;
final Set<String> processedNotificationIds = HashSet<String>();

bool markNotificationAsProcessed(String? notificationId) {
  if (notificationId == null) return false;
  if (processedNotificationIds.contains(notificationId)) {
    return false;
  }
  processedNotificationIds.add(notificationId);
  return true;
}

Future<void> setupFlutterNotifications() async {
  if (isFlutterLocalNotificationsInitialized) {
    return;
  }
  channel = const AndroidNotificationChannel(
    'high_importance_channel',
    'High Importance Notifications',
    description: 'This channel is used for important notifications.',
    importance: Importance.high,
  );

  flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);
  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );
  isFlutterLocalNotificationsInitialized = true;
}

void showFlutterNotificationfromFirebase(RemoteMessage message) async {
  RemoteNotification? notification = message.notification;
  AndroidNotification? android = message.notification?.android;
  if (notification != null && android != null && !kIsWeb) {
    flutterLocalNotificationsPlugin.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          icon: 'launch_background',
        ),
      ),
    );
  }
}

Future<void> showOneSignalNotification(OSNotification notification) async {
  final AndroidNotificationDetails androidPlatformChannelSpecifics =
      AndroidNotificationDetails(
    channel.id,
    channel.name,
    channelDescription: channel.description,
    importance: Importance.max,
    priority: Priority.high,
    icon: 'launch_background', // Ensure this icon exists in Android resources
  );

  const DarwinNotificationDetails iOSPlatformChannelSpecifics =
      DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
  );

  final NotificationDetails platformChannelSpecifics = NotificationDetails(
    android: androidPlatformChannelSpecifics,
    iOS: iOSPlatformChannelSpecifics,
  );

  String payloadData = jsonEncode({
    'route': 'desired_route',
    'data': notification.additionalData,
  });

  try {
    await flutterLocalNotificationsPlugin.show(
      notification.hashCode,
      notification.title,
      notification.body,
      platformChannelSpecifics,
      payload: payloadData,
    );
  } catch (e) {}
}

Future<void> setupOneSignal() async {
  OneSignal.initialize(Config.oneSiginalAppid);
  OneSignal.Notifications.requestPermission(true);
  await getFCMTokenInitialToSetThedata();
  await fetchPlayerId();
}

Future<void> getFCMTokenInitialToSetThedata() async {
  try {
    var fcmToken = await FirebaseMessaging.instance.getToken();
    if (fcmToken != null) {
      await OneSignal.login(fcmToken);
      await addTagWithKey(fcmToken);
      await fetchPlayerId();
    }
  } catch (error) {
    //
  }
}

Future<void> getFCMToken() async {
  try {
    var fcmToken = await FirebaseMessaging.instance.getToken();
    if (fcmToken != null) {
  await httpPost(
        Config.fcmUpdate,
        {"fcm": fcmToken, "player_id": oneSignalPlayerId??""},
        context: navigatorKey.currentContext!,
      );

      await OneSignal.login(fcmToken);
      await addTagWithKey(fcmToken);
      await fetchPlayerId();
    }
  } catch (error) {}
}

Future<void> addTagWithKey(String token) async {
  await OneSignal.User.addTagWithKey("FCMToken", token);
}

Future<void> fetchPlayerId() async {
  try {
    oneSignalPlayerId = OneSignal.User.pushSubscription.id;
    oneSignalToken = OneSignal.User.pushSubscription.token;
    oneSignalOptedIn = OneSignal.User.pushSubscription.optedIn;
    if (oneSignalPlayerId != null) {
      // add set the notification
    } else {}
  } catch (error) {}
}

Future<void> showNotification(context) async {
  FirebaseMessaging.onMessage.listen((RemoteMessage event) async {
    showFlutterNotificationfromFirebase(event);
  });
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {});
  await setupFlutterNotifications();
  if (!isOneSignalListenerAdded) {
    OneSignal.Notifications.addForegroundWillDisplayListener((event) {
      if (markNotificationAsProcessed(event.notification.notificationId)) {
        showOneSignalNotification(event.notification);
      }
      event.preventDefault();
    });
    isOneSignalListenerAdded = true; // Mark the listener as added
  }

  OneSignal.Notifications.addClickListener((event) {
    if (markNotificationAsProcessed(event.notification.notificationId)) {
      handleNotificationClick(event.notification.additionalData!['route'],
          event.notification.additionalData);
    }
  });
}

void handleNotificationClick(String? route, var data) {
  if (token.isEmpty) {
    showErrorToastMessage("Please Login first");

    return;
  }
  if (route != null) {

    // userEnd notification routing================
  }
}

Future<void> initializeNotifications() async {
  flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('launch_background');

  const DarwinInitializationSettings initializationSettingsDarwin =
      DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );

  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsDarwin,
  );

  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse:
        (NotificationResponse notificationResponse) async {
      if (notificationResponse.payload != null) {
        try {
          final Map<String, dynamic> data =
              jsonDecode(notificationResponse.payload!);
          handleNotificationClick(data["route"], data);
        } catch (e) {}
      }
    },
  );
}
