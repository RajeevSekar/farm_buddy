import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:convert';

class CustomBluetoothService {
  void startScan() {
    FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));
    print("Bluetooth scanning started...");
  }

  Stream<List<ScanResult>> get scanResultsStream => FlutterBluePlus.scanResults;

  void listenToData(BluetoothDevice device, Function(String) onDataReceived) async {
    List<BluetoothService> services = await device.discoverServices();

    final targetUUID = Guid("12345678-1234-5678-1234-56789abcdef1");

    for (BluetoothService service in services) {
      for (BluetoothCharacteristic characteristic in service.characteristics) {
        if (characteristic.uuid == targetUUID && characteristic.properties.notify) {
          await characteristic.setNotifyValue(true);
          characteristic.value.listen((value) {
            String data = utf8.decode(value);
            print("Received Data: $data");
            onDataReceived(data);
          });
        }
      }
    }
  }
}
