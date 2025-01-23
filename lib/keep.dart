import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:watch_app/gpsservice.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:watch_app/two.dart';

class TrackerScreen extends StatefulWidget {
  const TrackerScreen({Key? key}) : super(key: key);

  @override
  _TrackerScreenState createState() => _TrackerScreenState();
}

class _TrackerScreenState extends State<TrackerScreen> {
  LatLng _currentLocation = LatLng(0, 0);
  LatLng? _previousLocation;
  late GPSService _gpsService;
  late NotificationService _notificationService;
  List<LatLng> _geofences = [];
  String? _userId;
  DateTime? _lastLogTime;
  DateTime? _lastLocationUpdateTime;
  double? _distanceToGeofence;
  bool _isInsideGeofence = false;
  bool _shouldNotify = false;
  double _speed = 0.0;
  final double _speedLimit = 10.0;

@override
void initState() {
  super.initState();
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    final gpsService = Provider.of<GPSService>(context, listen: false);
    final notificationService = Provider.of<NotificationService>(context, listen: false);

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _userId = user.uid;
      _listenForPersonalNotifications();
      _listenForClassNotifications();
      _listenForEmergencyNotifications(); 
    }

    if (gpsService.currentLocation != null) {
      setState(() {
        _currentLocation = gpsService.currentLocation!;
      });
    }

    await _fetchGeofences();
    gpsService.startTracking();
    _checkGeofence();
  });
}


  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _gpsService = Provider.of<GPSService>(context);
    _gpsService.addListener(_locationUpdate);
    _notificationService = Provider.of<NotificationService>(context);
  }

  Future<void> _fetchGeofences() async {
    try {
      final geofencesSnapshot = await FirebaseFirestore.instance.collection('geofences').get();
      setState(() {
        _geofences = geofencesSnapshot.docs.map((doc) {
          final data = doc.data();
          final double? latitude = data['latitude'];
          final double? longitude = data['longitude'];
          if (latitude != null && longitude != null) {
            return LatLng(latitude, longitude);
          } else {
            return null;
          }
        }).where((latLng) => latLng != null).toList().cast<LatLng>();
      });
    } catch (e) {
      print("Error fetching geofences: $e");
    }
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
    await Future.delayed(Duration(milliseconds: 500)); 
    if (_gpsService.currentLocation != null) {
      final now = DateTime.now();
      if (_previousLocation != null && _lastLocationUpdateTime != null) {
        final timeDiff = now.difference(_lastLocationUpdateTime!).inSeconds;
        if (timeDiff > 0) {
          final distance = Distance().as(LengthUnit.Meter, _previousLocation!, _currentLocation);
          _speed = distance / timeDiff;
          _checkSpeedLimit();
        }
      }
      if (!mounted) return;
      setState(() {
        _previousLocation = _currentLocation;
        _currentLocation = _gpsService.currentLocation!;
        _lastLocationUpdateTime = now;
      });
      
      _logCurrentLocationToFirestore();
      _checkGeofence();
    }
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
    _isInsideGeofence = false;
    _distanceToGeofence = null;
    _shouldNotify = false;

    for (var geofence in _geofences) {
      final meters = distance.as(LengthUnit.Meter, _currentLocation, geofence);
      if (meters < 100) {
        _isInsideGeofence = true;
        _distanceToGeofence = meters;
        break;
      } else if (_distanceToGeofence == null || meters < _distanceToGeofence!) {
        _distanceToGeofence = meters;
      }
    }

    if (!_isInsideGeofence) {
      _shouldNotify = true;
      _logBreachToFirestore();
      _notificationService.showNotification(
        "Geofence Alert",
        "You are outside the geofence!",
      );
    }
  }

  Future<void> _logBreachToFirestore() async {
    if (_userId != null) {
      final now = DateTime.now();
      if (_lastLogTime == null || now.difference(_lastLogTime!).inMinutes >= 30) {
        _lastLogTime = now;

        try {
          final userEmail = FirebaseAuth.instance.currentUser?.email;

          if (userEmail != null) {
            final userSnapshot = await FirebaseFirestore.instance
                .collection('users')
                .where('email', isEqualTo: userEmail)
                .get();

            if (userSnapshot.docs.isNotEmpty) {
              final userData = userSnapshot.docs.first.data();
              final String userClass = userData['class'];

              final breachLogRef = FirebaseFirestore.instance
                  .collection('breachLogs')
                  .doc(_userId);

              await breachLogRef.set({
                'userId': _userId,
                'timestamp': FieldValue.serverTimestamp(),
                'class': userClass,
              }, SetOptions(merge: true));
            }
          }
        } catch (e) {
          print("Error logging breach: $e");
        }
      }
    }
  }
Set<String> _notifiedEmergencyIds = {}; // Track notified emergency notification IDs

void _listenForEmergencyNotifications() {
  FirebaseFirestore.instance
      .collection('Enotifications')
      .orderBy('timestamp', descending: true) // Ensure messages are ordered by timestamp
      .snapshots()
      .listen((snapshot) {
    for (var doc in snapshot.docs) {
      final String notificationId = doc.id; // Unique ID for each document
      if (!_notifiedEmergencyIds.contains(notificationId)) {
        final data = doc.data();
        final String subject = data['subject'];
        final String message = data['message'];

        _notificationService.showNotification(subject, message);
        _notifiedEmergencyIds.add(notificationId); // Mark this notification as shown
      }
    }
  });
}
Set<String> _notifiedPersonalIds = {}; // Track notified personal notification IDs
Set<String> _notifiedClassIds = {};   // Track notified class notification IDs

void _listenForPersonalNotifications() {
  if (_userId != null) {
    FirebaseFirestore.instance
        .collection('PersonalNotifications')
        .where('userId', isEqualTo: _userId)
        .snapshots()
        .listen((snapshot) {
      for (var doc in snapshot.docs) {
        final String notificationId = doc.id; // Unique ID for each document
        if (!_notifiedPersonalIds.contains(notificationId)) {
          final data = doc.data();
          final String subject = data['subject'];
          final String message = data['message'];

          _notificationService.showNotification(subject, message);
          _notifiedPersonalIds.add(notificationId); // Mark this notification as shown
        }
      }
    });
  }
}

void _listenForClassNotifications() {
  if (_userId != null) {
    final userEmail = FirebaseAuth.instance.currentUser?.email;

    if (userEmail != null) {
      FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: userEmail)
          .get()
          .then((snapshot) {
        if (snapshot.docs.isNotEmpty) {
          final userData = snapshot.docs.first.data();
          final String userClass = userData['class'];

          FirebaseFirestore.instance
              .collection('ClassNotifications')
              .where('class', isEqualTo: userClass)
              .snapshots()
              .listen((snapshot) {
            for (var doc in snapshot.docs) {
              final String notificationId = doc.id; // Unique ID for each document
              if (!_notifiedClassIds.contains(notificationId)) {
                final data = doc.data();
                final String subject = data['subject'];
                final String message = data['message'];

                _notificationService.showNotification(subject, message);
                _notifiedClassIds.add(notificationId); // Mark this notification as shown
              }
            }
          });
        }
      });
    }
  }
}


  Future<void> _logPanicToFirestore() async {
    if (_userId != null) {
      try {
        final panicData = {
          'userId': _userId,
          'latitude': _currentLocation.latitude,
          'longitude': _currentLocation.longitude,
          'timestamp': FieldValue.serverTimestamp(),
          'speed': _speed,
          'distanceToGeofence': _distanceToGeofence,
          'insideGeofence': _isInsideGeofence,
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
    _gpsService.removeListener(_locationUpdate);
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
              Text('Distance to nearest geofence: ${_distanceToGeofence?.toStringAsFixed(2)} meters'),
              Text(_isInsideGeofence ? 'Inside a geofence' : 'Outside geofence'),
              Text('Speed: ${_speed.toStringAsFixed(2)} m/s'),
              if (_speed > _speedLimit) const Text('Speed limit exceeded!'),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _logPanicToFirestore,
                child: const Text("Panic Button"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
