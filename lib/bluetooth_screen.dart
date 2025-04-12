import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../services/bluetooth_service.dart' as CustomBluetoothService;

class BluetoothScreen extends StatefulWidget {
  @override
  _BluetoothScreenState createState() => _BluetoothScreenState();
}

class _BluetoothScreenState extends State<BluetoothScreen> {
  final CustomBluetoothService.CustomBluetoothService bluetoothService =
  CustomBluetoothService.CustomBluetoothService();

  BluetoothDevice? connectedDevice;
  String sensorData = "Waiting for data...";

  @override
  void initState() {
    super.initState();
    bluetoothService.startScan();
  }

  void connectToDevice(BluetoothDevice device) async {
    try {
      await device.connect();
      setState(() {
        connectedDevice = device;
      });
      print("Connected to ${device.name}");

      // Start receiving data
      bluetoothService.listenToData(device, (data) {
        setState(() {
          sensorData = data;
        });
      });
    } catch (e) {
      print("Failed to connect: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Bluetooth Devices')),
      body: connectedDevice == null
          ? StreamBuilder<List<ScanResult>>(
        stream: bluetoothService.scanResultsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('No devices found'));
          }

          return ListView.builder(
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              final result = snapshot.data![index];
              return ListTile(
                title: Text(result.device.name.isEmpty
                    ? 'Unknown Device'
                    : result.device.name),
                subtitle: Text(result.device.id.toString()),
                trailing: ElevatedButton(
                  onPressed: () => connectToDevice(result.device),
                  child: Text('Connect'),
                ),
              );
            },
          );
        },
      )
          : Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("Connected to ${connectedDevice!.name}"),
            SizedBox(height: 20),
            Text("Sensor Data:", style: TextStyle(fontSize: 20)),
            Text(sensorData, style: TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }
}
