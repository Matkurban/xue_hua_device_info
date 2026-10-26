import 'package:flutter/material.dart';
import 'package:xue_hua_device_info/xue_hua_device_info.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _summary = 'Loading...';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        XueHuaDeviceInfo.getDeviceInfo(),
        XueHuaDeviceInfo.getBatteryInfo(),
        XueHuaDeviceInfo.getNetworkInfo(),
        XueHuaDeviceInfo.getStorageInfo(),
        XueHuaDeviceInfo.getDisplayInfo(),
      ]);
      final device = results[0] as DeviceInfo;
      final battery = results[1] as BatteryInfo;
      final network = results[2] as NetworkInfo;
      final storage = results[3] as StorageInfo;
      final display = results[4] as DisplayInfo;
      setState(() {
        _summary = [
          'Device: ${device.manufacturer} ${device.model}',
          'ID: ${device.deviceId}',
          'Name: ${device.name}',
          'Battery: ${battery.level}% charging=${battery.isCharging} health=${battery.health}',
          'Network: ${network.networkType} ${network.ipAddress} mac=${network.macAddress}',
          'Storage: ${storage.freeBytes}/${storage.totalBytes} type=${storage.storageType}',
          'Display: ${display.width}x${display.height} scale=${display.scaleFactor} @${display.refreshRate}',
        ].join('\n');
      });
    } catch (e) {
      setState(() => _summary = 'Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('XueHua Device Info')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: SelectableText(
            _summary,
            key: const Key('device_info_summary'),
          ),
        ),
        floatingActionButton: FloatingActionButton(
          key: const Key('refresh_fab'),
          onPressed: _load,
          child: const Icon(Icons.refresh),
        ),
      ),
    );
  }
}
