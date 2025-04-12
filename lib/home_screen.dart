import 'package:flutter/material.dart';
import 'image_detection_screen.dart';
import 'multimodal_detection_screen.dart';
import 'bluetooth_screen.dart';

class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Rice Sheath Blight Detection')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ImageDetectionScreen()),
                );
              },
              child: Text('Image Detection'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => MultiModalDetectionScreen()),
                );
              },
              child: Text('Multimodal Detection'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => BluetoothScreen()),
                );
              },
              child: Text('Bluetooth Data'),
            ),
          ],
        ),
      ),
    );
  }
}
