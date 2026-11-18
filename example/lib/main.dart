import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:xue_hua_device_info/xue_hua_device_info.dart';

import 'state/device_info_signals.dart';
import 'widgets/device_section_card.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'XueHua Device Info',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF0066CC),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: const Color(0xFF0066CC),
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: const DeviceInfoDashboardPage(),
    );
  }
}

class DeviceInfoDashboardPage extends SignalStatefulWidget {
  const DeviceInfoDashboardPage({super.key});

  @override
  State<DeviceInfoDashboardPage> createState() =>
      _DeviceInfoDashboardPageState();
}

class _DeviceInfoDashboardPageState extends State<DeviceInfoDashboardPage> {
  final DeviceInfoDashboardController _controller =
      DeviceInfoDashboardController();

  @override
  void initState() {
    super.initState();
    // Trigger each subsystem's independent fetch rather than a single monolithic Future.wait.
    _controller.fetchAllSequentially();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('XueHua Device Info (Pigeon 2.1.0)'),
        actions: [
          SignalBuilder(
            builder: (context) {
              final loaded = _controller.loadedSectionCount.value;
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Center(
                  child: Chip(
                    key: const Key('loaded_sections_badge'),
                    label: Text('已加载 $loaded / 5 模块'),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
        children: [
          _QuickFetchToolbar(controller: _controller),
          const SizedBox(height: 16),
          DeviceSectionCard<DeviceInfo>(
            sectionKeyPrefix: 'device_section',
            title: '1. 设备标识与系统信息 (Device Identity)',
            subtitle: '通过 Pigeon getDeviceInfo() 独立获取硬件标识与系统架构',
            icon: Icons.devices_other_outlined,
            state: _controller.deviceSection,
            metricsBuilder: (info) => [
              InfoMetricItem(
                label: '显示名称 (displayTitle)',
                value: info.displayTitle,
                highlight: true,
              ),
              InfoMetricItem(
                label: '设备唯一标识 (deviceId)',
                value: info.deviceId ?? 'null (不可用)',
              ),
              InfoMetricItem(
                label: '制造商 (manufacturer)',
                value: info.manufacturer ?? 'null (不可用)',
              ),
              InfoMetricItem(
                label: '设备型号 (model)',
                value: info.model ?? 'null (不可用)',
              ),
              InfoMetricItem(
                label: '硬件序列号 (serial)',
                value: info.serial ?? 'null (移动端不公开/无权限)',
              ),
              InfoMetricItem(
                label: '包含序列号 (hasSerial)',
                value: '${info.hasSerial}',
              ),
              InfoMetricItem(
                label: '主机/设备名 (name)',
                value: info.name ?? 'null (不可用)',
              ),
              InfoMetricItem(
                label: '操作系统 (operatingSystem)',
                value: info.operatingSystem ?? 'null',
              ),
              InfoMetricItem(
                label: '系统版本 (osVersion)',
                value: info.osVersion ?? 'null',
              ),
              InfoMetricItem(
                label: '处理器架构 (architecture)',
                value: info.architecture ?? 'null',
              ),
            ],
          ),
          const SizedBox(height: 14),
          DeviceSectionCard<BatteryInfo>(
            sectionKeyPrefix: 'battery_section',
            title: '2. 电池与电源状态 (Battery Status)',
            subtitle: '通过 Pigeon getBatteryInfo() 独立获取电量、充放电状态与电池健康度',
            icon: Icons.battery_charging_full_outlined,
            state: _controller.batterySection,
            progressBuilder: (info) => info.levelRatio,
            metricsBuilder: (info) => [
              InfoMetricItem(
                label: '格式化电量 (formattedLevel)',
                value: info.formattedLevel,
                highlight: true,
              ),
              InfoMetricItem(
                label: '原始电量百分比 (level)',
                value: info.level == null ? 'null' : '${info.level}%',
              ),
              InfoMetricItem(
                label: '电量比例 (levelRatio)',
                value: info.levelRatio == null
                    ? 'null'
                    : info.levelRatio!.toStringAsFixed(3),
              ),
              InfoMetricItem(
                label: '存在物理电池 (hasBattery)',
                value: '${info.hasBattery}',
              ),
              InfoMetricItem(
                label: '正在充电 (isCharging)',
                value: '${info.isCharging}',
              ),
              InfoMetricItem(
                label: '充电状态枚举 (chargingState)',
                value: '${info.chargingState.name} (${info.chargingState.code})',
              ),
              InfoMetricItem(
                label: '健康状态枚举 (healthStatus)',
                value: '${info.healthStatus.name} (${info.healthStatus.code})',
              ),
              InfoMetricItem(
                label: '原生健康标签 (health)',
                value: info.health ?? 'null (当前平台未暴露)',
              ),
            ],
          ),
          const SizedBox(height: 14),
          DeviceSectionCard<NetworkInfo>(
            sectionKeyPrefix: 'network_section',
            title: '3. 网络连接与网卡详情 (Network Connection)',
            subtitle: '通过 Pigeon getNetworkInfo() 独立获取主用网卡、IPv4 与物理地址',
            icon: Icons.lan_outlined,
            state: _controller.networkSection,
            metricsBuilder: (info) => [
              InfoMetricItem(
                label: '连接类型代码 (networkType)',
                value: info.networkType,
                highlight: true,
              ),
              InfoMetricItem(
                label: '连接类型枚举 (connectionType)',
                value: '${info.connectionType.name} (${info.connectionType.code})',
              ),
              InfoMetricItem(
                label: '是否已连接 (isConnected)',
                value: '${info.isConnected}',
              ),
              InfoMetricItem(
                label: '是否无线网络 (isWireless)',
                value: '${info.isWireless}',
              ),
              InfoMetricItem(
                label: '局域网 IPv4 (ipAddress)',
                value: info.ipAddress ?? 'null (未连接或无 IPv4)',
              ),
              InfoMetricItem(
                label: '物理 MAC 地址 (macAddress)',
                value: info.macAddress ?? 'null (移动端隐私限制/不可用)',
              ),
              InfoMetricItem(
                label: '主用网卡名称 (interfaceName)',
                value: info.interfaceName ?? 'null',
              ),
            ],
          ),
          const SizedBox(height: 14),
          DeviceSectionCard<StorageInfo>(
            sectionKeyPrefix: 'storage_section',
            title: '4. 主存储空间与介质类型 (Storage Capacity)',
            subtitle: '通过 Pigeon getStorageInfo() 独立获取磁盘总容量、已用/可用空间与介质类型',
            icon: Icons.storage_outlined,
            state: _controller.storageSection,
            progressBuilder: (info) => info.usageRatio,
            metricsBuilder: (info) => [
              InfoMetricItem(
                label: '已用百分比 (usedPercentage)',
                value: '${info.usedPercentage.toStringAsFixed(1)}%',
                highlight: true,
              ),
              InfoMetricItem(
                label: '介质类型枚举 (mediumType)',
                value: '${info.mediumType.name} (${info.mediumType.code})',
              ),
              InfoMetricItem(
                label: '介质原始标识 (storageType)',
                value: info.storageType ?? 'null (未知介质)',
              ),
              InfoMetricItem(
                label: '总容量 GiB (totalGigabytes)',
                value: '${info.totalGigabytes.toStringAsFixed(2)} GiB',
              ),
              InfoMetricItem(
                label: '已用容量 GiB (usedGigabytes)',
                value: '${info.usedGigabytes.toStringAsFixed(2)} GiB',
              ),
              InfoMetricItem(
                label: '可用容量 GiB (freeGigabytes)',
                value: '${info.freeGigabytes.toStringAsFixed(2)} GiB',
              ),
              InfoMetricItem(
                label: '总字节数 (totalBytes)',
                value: '${info.totalBytes} B',
              ),
              InfoMetricItem(
                label: '已用字节数 (usedBytes)',
                value: '${info.usedBytes} B',
              ),
              InfoMetricItem(
                label: '可用字节数 (freeBytes)',
                value: '${info.freeBytes} B',
              ),
            ],
          ),
          const SizedBox(height: 14),
          DeviceSectionCard<DisplayInfo>(
            sectionKeyPrefix: 'display_section',
            title: '5. 显示屏分辨率与刷新率 (Display Metrics)',
            subtitle: '通过 Pigeon getDisplayInfo() 独立获取物理像素、逻辑分辨率、缩放比与刷新率',
            icon: Icons.monitor_outlined,
            state: _controller.displaySection,
            metricsBuilder: (info) => [
              InfoMetricItem(
                label: '物理分辨率 (physicalResolution)',
                value: '${info.physicalResolution} px',
                highlight: true,
              ),
              InfoMetricItem(
                label: '逻辑分辨率 (logicalResolution)',
                value: '${info.logicalResolution} pt',
              ),
              InfoMetricItem(
                label: '物理宽度 (width)',
                value: '${info.width} px',
              ),
              InfoMetricItem(
                label: '物理高度 (height)',
                value: '${info.height} px',
              ),
              InfoMetricItem(
                label: '逻辑宽度 (logicalWidth)',
                value: '${info.logicalWidth.toStringAsFixed(1)} pt',
              ),
              InfoMetricItem(
                label: '逻辑高度 (logicalHeight)',
                value: '${info.logicalHeight.toStringAsFixed(1)} pt',
              ),
              InfoMetricItem(
                label: '缩放因子 (scaleFactor)',
                value: '${info.scaleFactor}x',
              ),
              InfoMetricItem(
                label: '刷新率 (refreshRate)',
                value: info.refreshRate == null
                    ? 'null (未知)'
                    : '${info.refreshRate!.toStringAsFixed(1)} Hz',
              ),
              InfoMetricItem(
                label: '高刷新率屏幕 (isHighRefreshRate)',
                value: '${info.isHighRefreshRate}',
              ),
              InfoMetricItem(
                label: '宽高比 (aspectRatio)',
                value: info.aspectRatio.toStringAsFixed(3),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: SignalBuilder(
        builder: (context) {
          final busy = _controller.isAnySectionLoading.value;
          return FloatingActionButton.extended(
            key: const Key('refresh_fab'),
            onPressed: busy ? null : _controller.fetchAllSequentially,
            icon: const Icon(Icons.sync),
            label: const Text('按模块依次获取'),
          );
        },
      ),
    );
  }
}

class _QuickFetchToolbar extends StatelessWidget {
  const _QuickFetchToolbar({required this.controller});

  final DeviceInfoDashboardController controller;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '分模块独立获取控制栏 (Signals Fine-Grained State)',
            style: textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '点击任意按钮仅调用对应模块的 Pigeon 接口并局部更新该卡片，不触发其他模块请求或全局 setState。',
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _QuickActionButton(
                buttonKey: const Key('quick_fetch_device'),
                label: '获取设备标识',
                icon: Icons.devices_other_outlined,
                state: controller.deviceSection,
              ),
              _QuickActionButton(
                buttonKey: const Key('quick_fetch_battery'),
                label: '获取电池状态',
                icon: Icons.battery_charging_full_outlined,
                state: controller.batterySection,
              ),
              _QuickActionButton(
                buttonKey: const Key('quick_fetch_network'),
                label: '获取网络信息',
                icon: Icons.lan_outlined,
                state: controller.networkSection,
              ),
              _QuickActionButton(
                buttonKey: const Key('quick_fetch_storage'),
                label: '获取存储容量',
                icon: Icons.storage_outlined,
                state: controller.storageSection,
              ),
              _QuickActionButton(
                buttonKey: const Key('quick_fetch_display'),
                label: '获取屏幕参数',
                icon: Icons.monitor_outlined,
                state: controller.displaySection,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickActionButton<T> extends StatelessWidget {
  const _QuickActionButton({
    required this.buttonKey,
    required this.label,
    required this.icon,
    required this.state,
  });

  final Key buttonKey;
  final String label;
  final IconData icon;
  final SectionSignalState<T> state;

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(
      builder: (context) {
        final loading = state.isLoading.value;
        return OutlinedButton.icon(
          key: buttonKey,
          onPressed: loading ? null : state.fetch,
          icon: Icon(icon, size: 16),
          label: Text(label),
        );
      },
    );
  }
}
