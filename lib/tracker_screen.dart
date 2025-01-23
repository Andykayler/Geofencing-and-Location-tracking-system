import 'dart:async';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geolocator_android/geolocator_android.dart'; // Import GeolocatorAndroid
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:watch_app/two.dart';

class TrackerScreen extends StatefulWidget {
  const TrackerScreen({Key? key}) : super(key: key);

  @override
  _TrackerScreenState createState() => _TrackerScreenState();
}

class _TrackerScreenState extends State<TrackerScreen> {
  LatLng _currentLocation = LatLng(0, 0);
  LatLng? _previousLocation;
  late NotificationService _notificationService;
  List<LatLng> _geofences = [];
  String? _userId;
  DateTime? _lastLocationUpdateTime;
  double _speed = 0.0;
  Timer? _locationUpdateTimer;
  final double _speedLimit = 10.0;

  // Notification IDs to avoid duplicates
  Set<String> _notifiedPersonalIds = {};
  Set<String> _notifiedClassIds = {};
  Set<String> _notifiedEmergencyIds = {};

 @override
void initState() {
  super.initState();

  // Remove incorrect use of geolocatorAndroid.useAndroidView()
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    await _initializeServices();
  });
}

Future<void> _initializeServices() async {
  _notificationService = Provider.of<NotificationService>(context, listen: false);

  final user = FirebaseAuth.instance.currentUser;
  if (user != null) {
    _userId = user.uid;
    _setupNotificationListeners();
  }

  bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    print("Location services are disabled. Please enable them.");
    return;
  }

  LocationPermission permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      print("Location permissions are denied");
      return;
    }
  }

  if (permission == LocationPermission.deniedForever) {
    print("Location permissions are permanently denied");
    return;
  }

  Geolocator.getPositionStream(
    locationSettings: LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    ),
  ).listen((position) {
    setState(() {
      _currentLocation = LatLng(position.latitude, position.longitude);
    });
    _locationUpdate();
  });

  await _fetchGeofences();
  _startLocationLogging();
}
  Future<void> _fetchGeofences() async {
    try {
      final geofencesSnapshot = await FirebaseFirestore.instance.collection('geofences').get();
      setState(() {
        _geofences = geofencesSnapshot.docs
            .map((doc) {
              final data = doc.data();
              final latitude = data['latitude'] as double?;
              final longitude = data['longitude'] as double?;
              return latitude != null && longitude != null ? LatLng(latitude, longitude) : null;
            })
            .whereType<LatLng>()
            .toList();
      });
    } catch (e) {
      print("Error fetching geofences: $e");
    }
  }

  void _startLocationLogging() {
    _locationUpdateTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _logCurrentLocationToFirestore();
    });
  }

  Future<void> _logCurrentLocationToFirestore() async {
    if (_userId != null) {
      try {
        final locationData = {
          'userId': _userId,
          'latitude': _currentLocation.latitude,
          'longitude': _currentLocation.longitude,
          'timestamp': FieldValue.serverTimestamp(),
        };
        await FirebaseFirestore.instance
            .collection('location')
            .doc(_userId)
            .set(locationData, SetOptions(merge: true));
      } catch (e) {
        print("Error updating location in Firestore: $e");
      }
    }
  }

  Future<void> _locationUpdate() async {
    if (_previousLocation != null && _lastLocationUpdateTime != null) {
      final now = DateTime.now();
      final timeDiff = now.difference(_lastLocationUpdateTime!).inSeconds;
      if (timeDiff > 0) {
        final distance = Distance().as(LengthUnit.Meter, _previousLocation!, _currentLocation);
        _speed = distance / timeDiff;
        _checkSpeedLimit();
      }
    }

    setState(() {
      _previousLocation = _currentLocation;
      _lastLocationUpdateTime = DateTime.now();
    });

    _logCurrentLocationToFirestore();
    _checkGeofence();
  }

  void _checkSpeedLimit() {
    if (_speed > _speedLimit) {
      _notificationService.showNotification(
        "Speed Limit Exceeded",
        "You are moving too fast! Your speed is ${_speed.toStringAsFixed(2)} m/s, which exceeds the limit of $_speedLimit m/s.",
      );
    }
  }

  void _checkGeofence() {
    final distance = Distance();
    final isInsideGeofence = _geofences.any((geofence) {
      final meters = distance.as(LengthUnit.Meter, _currentLocation, geofence);
      return meters < 100; // Threshold distance for geofence
    });

    if (!isInsideGeofence) {
      _logBreachToFirestore();
      _notificationService.showNotification("Geofence Alert", "You are outside the geofence!");
    }
  }
Future<void> _logBreachToFirestore() async {
  if (_userId != null) {
    try {
      final userEmail = FirebaseAuth.instance.currentUser?.email;
      if (userEmail != null) {
        final userSnapshot = await FirebaseFirestore.instance
            .collection('students')
            .where('email', isEqualTo: userEmail)
            .get();

        if (userSnapshot.docs.isNotEmpty) {
          final userData = userSnapshot.docs.first.data();
          final String userClass = userData['class'];

          // Check if a breach has already been logged today
          final breachSnapshot = await FirebaseFirestore.instance
              .collection('breachLogs')
              .doc(_userId)
              .get();

          if (breachSnapshot.exists) {
            final breachData = breachSnapshot.data();
            final timestamp = breachData?['timestamp']?.toDate();

            if (timestamp != null && _isSameDay(timestamp, DateTime.now())) {
              print("Breach already logged today.");
              return; // Skip logging the breach if it's the same day
            }
          }

          // Log the breach if not logged today
          await FirebaseFirestore.instance
              .collection('breachLogs')
              .doc(_userId)
              .set({
            'userId': _userId,
            'timestamp': FieldValue.serverTimestamp(),
            'class': userClass,
          }, SetOptions(merge: true));

          print("Breach logged successfully.");
        }
      }
    } catch (e) {
      print("Error logging breach: $e");
    }
  }
}

// Helper function to check if two DateTime objects are on the same day
bool _isSameDay(DateTime date1, DateTime date2) {
  return date1.year == date2.year &&
      date1.month == date2.month &&
      date1.day == date2.day;
}



  /// Sets up notification listeners for personal, class, and emergency notifications
  void _setupNotificationListeners() {
    _listenForPersonalNotifications();
    _listenForClassNotifications();
    _listenForEmergencyNotifications();
  }

  /// Listens for personal notifications
  void _listenForPersonalNotifications() {
    if (_userId != null) {
      FirebaseFirestore.instance
          .collection('PersonalNotifications')
          .where('userId', isEqualTo: _userId)
          .snapshots()
          .listen((snapshot) {
        for (var doc in snapshot.docs) {
          final String notificationId = doc.id;
          if (_notifiedPersonalIds.add(notificationId)) {
            final data = doc.data();
            _notificationService.showNotification(data['subject'], data['message']);
          }
        }
      });
    }
  }

  /// Listens for class notifications
  void _listenForClassNotifications() {
    final userEmail = FirebaseAuth.instance.currentUser?.email;
    if (userEmail != null) {
      FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: userEmail)
          .get()
          .then((snapshot) {
        if (snapshot.docs.isNotEmpty) {
          final userClass = snapshot.docs.first.data()['class'];
          FirebaseFirestore.instance
              .collection('ClassNotifications')
              .where('class', isEqualTo: userClass)
              .snapshots()
              .listen((snapshot) {
            for (var doc in snapshot.docs) {
              final String notificationId = doc.id;
              if (_notifiedClassIds.add(notificationId)) {
                final data = doc.data();
                _notificationService.showNotification(data['subject'], data['message']);
              }
            }
          });
        }
      });
    }
  }

  /// Listens for emergency notifications
  void _listenForEmergencyNotifications() {
    FirebaseFirestore.instance
        .collection('Enotifications')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen((snapshot) {
      for (var doc in snapshot.docs) {
        final String notificationId = doc.id;
        if (_notifiedEmergencyIds.add(notificationId)) {
          final data = doc.data();
          _notificationService.showNotification(data['subject'], data['message']);
        }
      }
    });
  }

  /// Logs a panic alert to Firestore
  Future<void> _logPanicToFirestore() async {
    if (_userId != null) {
      try {
        final panicData = {
          'userId': _userId,
          'latitude': _currentLocation.latitude,
          'longitude': _currentLocation.longitude,
          'timestamp': FieldValue.serverTimestamp(),
          'speed': _speed,
        };
        await FirebaseFirestore.instance.collection('panic').add(panicData);
        _notificationService.showNotification("Panic Alert", "Panic button pressed. Assistance needed!");
      } catch (e) {
        print("Error logging panic data: $e");
      }
    }
  }

  @override
  void dispose() {
    _locationUpdateTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Current location: ${_currentLocation.latitude}, ${_currentLocation.longitude}'),
              Text('Speed: ${_speed.toStringAsFixed(2)} m/s'),
              if (_speed > _speedLimit) const Text('Speed limit exceeded!'),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _logPanicToFirestore,
                child: const Icon(
                  Icons.warning,
                  color: Colors.white,
                  size: 30.0,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.all(15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}