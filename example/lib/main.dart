import 'package:flutter/material.dart';
import 'package:xue_hua_device_info/xue_hua_device_info.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await XueHuaDeviceInfo.initialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Device Info',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const DeviceInfoDashboard(),
    );
  }
}

class DeviceInfoDashboard extends StatefulWidget {
  const DeviceInfoDashboard({super.key});

  @override
  State<DeviceInfoDashboard> createState() => _DeviceInfoDashboardState();
}

class _DeviceInfoDashboardState extends State<DeviceInfoDashboard> {
  bool _loading = true;
  String? _error;

  DeviceInfoResponse? _device;
  BatteryInfo? _battery;
  NetworkInfo? _network;
  StorageInfo? _storage;
  DisplayInfo? _display;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        XueHuaDeviceInfo.getDeviceInfo(),
        XueHuaDeviceInfo.getBatteryInfo(),
        XueHuaDeviceInfo.getNetworkInfo(),
        XueHuaDeviceInfo.getStorageInfo(),
        XueHuaDeviceInfo.getDisplayInfo(),
      ]);

      setState(() {
        _device = results[0] as DeviceInfoResponse;
        _battery = results[1] as BatteryInfo;
        _network = results[2] as NetworkInfo;
        _storage = results[3] as StorageInfo;
        _display = results[4] as DisplayInfo;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Device Info'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _refresh,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _InfoCard(
                    title: 'Device',
                    icon: Icons.devices,
                    rows: {
                      'UUID': _device?.uuid,
                      'Manufacturer': _device?.manufacturer,
                      'Model': _device?.model,
                      'Serial': _device?.serial,
                      'Android ID': _device?.androidId,
                      'Device Name': _device?.deviceName,
                    },
                  ),
                  _InfoCard(
                    title: 'Battery',
                    icon: Icons.battery_charging_full,
                    rows: {
                      'Level': _battery?.level != null
                          ? '${_battery!.level!.toStringAsFixed(0)}%'
                          : null,
                      'Charging': _battery?.isCharging?.toString(),
                      'Health': _battery?.health,
                    },
                  ),
                  _InfoCard(
                    title: 'Network',
                    icon: Icons.wifi,
                    rows: {
                      'IP Address': _network?.ipAddress,
                      'Type': _network?.networkType,
                      'MAC': _network?.macAddress,
                    },
                  ),
                  _InfoCard(
                    title: 'Storage',
                    icon: Icons.storage,
                    rows: {
                      'Total': _formatBytes(_storage?.totalSpace),
                      'Free': _formatBytes(_storage?.freeSpace),
                      'Type': _storage?.storageType,
                    },
                  ),
                  _InfoCard(
                    title: 'Display',
                    icon: Icons.monitor,
                    rows: {
                      'Resolution':
                          '${_display?.width ?? 0} x ${_display?.height ?? 0}',
                      'Scale': _display?.scaleFactor.toString(),
                      'Refresh Rate': _display?.refreshRate != null
                          ? '${_display!.refreshRate} Hz'
                          : null,
                    },
                  ),
                ],
              ),
            ),
    );
  }

  String? _formatBytes(BigInt? bytes) {
    if (bytes == null) return null;
    final gb = bytes.toDouble() / (1024 * 1024 * 1024);
    return '${gb.toStringAsFixed(2)} GB';
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.icon,
    required this.rows,
  });

  final String title;
  final IconData icon;
  final Map<String, String?> rows;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20),
                const SizedBox(width: 8),
                Text(title, style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const Divider(height: 24),
            ...rows.entries.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 120,
                      child: Text(
                        e.key,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        e.value ?? '—',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
