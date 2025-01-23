import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  initializeNotifications(); // Initialize notifications
  runApp(MyApp());
}

void initializeNotifications() {
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  final InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  flutterLocalNotificationsPlugin.initialize(initializationSettings);

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'location_updates', // Channel ID
    'Location Updates', // Channel Name
    description: 'Notifications for location updates', // Channel Description
    importance: Importance.max,
  );

  flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GPSService _gpsService = GPSService();

  @override
  void initState() {
    super.initState();
    _gpsService.startTracking();
  }

  @override
  void dispose() {
    _gpsService.stopTracking();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Watch App Home'),
      ),
      body: Center(
        child: Text('Tracking location and receiving notifications'),
      ),
    );
  }
}

class GPSService with ChangeNotifier {
  LatLng _currentLocation = LatLng(0, 0);
  LatLng get currentLocation => _currentLocation;

  StreamSubscription<Position>? _positionStreamSubscription;
  Timer? _updateTimer;
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  GPSService() {
    _setupFirebaseMessaging();
    _initializeLocalNotifications();
  }

  Future<void> startTracking() async {
    try {
      // Check location permissions
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('Location services are disabled.');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('Location permissions are denied.');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print('Location permissions are permanently denied.');
        return;
      }

      // Start listening to the position stream
      _positionStreamSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 50,
        ),
      ).listen(
        (Position position) {
          _currentLocation = LatLng(position.latitude, position.longitude);
          notifyListeners();
          _updateLocationInFirestore(_currentLocation);
          print('New Position: $_currentLocation');
        },
        onError: (error) {
          print('Error in getting location: $error');
        },
      );

      // Set up a timer to update location at regular intervals
      _updateTimer = Timer.periodic(Duration(minutes: 1), (Timer t) {
        _updateLocationInFirestore(_currentLocation);
      });

      print('GPS tracking started');
    } catch (e) {
      print('Error starting GPS tracking: $e');
    }
  }

  void stopTracking() {
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
    _updateTimer?.cancel();
    _updateTimer = null;
    print('GPS tracking stopped');
  }

  Future<void> _updateLocationInFirestore(LatLng location) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance.collection('locations').doc(user.uid).set({
          'userId': user.uid,
          'latitude': location.latitude,
          'longitude': location.longitude,
          'timestamp': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        print('Error updating location in Firestore: $e');
      }
    }
  }

  void _setupFirebaseMessaging() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      // Handle foreground messages
      print('Message received: ${message.notification?.title}');
      _showNotification(message.notification?.title, message.notification?.body);
    });

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  void _initializeLocalNotifications() {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );
    flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  void _showNotification(String? title, String? body) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'location_updates', // Same Channel ID
      'Location Updates', // Channel Name
      channelDescription: 'Notifications for location updates', // Channel Description
      importance: Importance.max,
      priority: Priority.high,
      showWhen: false,
    );
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );
    await flutterLocalNotificationsPlugin.show(
      0,
      title,
      body,
      platformChannelSpecifics,
      payload: 'item x',
    );
  }

  static Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
    await Firebase.initializeApp();
    print('Background message received: ${message.notification?.title}');
  }
}
