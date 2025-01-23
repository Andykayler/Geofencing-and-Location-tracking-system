import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    // Initialize notification plugin with Android specific settings
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('app_icon');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  Future<void> showNotification(String title, String body) async {
    // Define Android specific notification settings
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'your_channel_id', // Replace with your channel ID
      'your_channel_name', // Replace with your channel name
      channelDescription: 'your_channel_description', // Replace with your channel description
      importance: Importance.max,
      priority: Priority.high,
      showWhen: false, // Set to true if you want to show the notification timestamp
      icon: '@mipmap/ic_launcher', // Replace with the resource name of your small icon
    );

    // Combine platform-specific and general notification settings
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    // Show the notification using the initialized plugin
    await flutterLocalNotificationsPlugin.show(
      0, // Notification ID, unique for each notification
      title,
      body,
      platformChannelSpecifics,
      payload: 'item x', // Optional payload for notification
    );
  }
}
