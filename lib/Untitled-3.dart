import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

class TrackerScreen extends StatefulWidget {
  const TrackerScreen({Key? key}) : super(key: key);

  @override
  _TrackerScreenState createState() => _TrackerScreenState();
}

class _TrackerScreenState extends State<TrackerScreen> {
  LatLng _currentLocation = LatLng(0, 0);
  double _speed = 0.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Location: ${_currentLocation.latitude}, ${_currentLocation.longitude}'),
            Text('Speed: $_speed m/s'),
            ElevatedButton(
              onPressed: () {
                // Action for Panic Button, e.g., a print statement
                print("Panic Button pressed");
              },
              child: const Text("Panic Button"),
            ),
          ],
        ),
      ),
    );
  }
}
