import 'package:signals_flutter/signals_flutter.dart';
import 'package:xue_hua_device_info/xue_hua_device_info.dart';

/// Fine-grained reactive state container for a single device info section.
class SectionSignalState<T> {
  SectionSignalState(this._loader);

  final Future<T> Function() _loader;

  /// Current loaded domain model, or `null` before first successful load.
  final Signal<T?> data = signal<T?>(null);

  /// Whether this specific section is currently fetching from the native host.
  final Signal<bool> isLoading = signal<bool>(false);

  /// Error message from the most recent fetch attempt, or `null` if succeeded.
  final Signal<String?> error = signal<String?>(null);

  /// Timestamp of the last completed refresh for this section.
  final Signal<DateTime?> lastUpdated = signal<DateTime?>(null);

  /// Number of times this section has been fetched independently.
  final Signal<int> fetchCount = signal<int>(0);

  bool _disposed = false;

  /// Independently fetches only this section's data from the native host.
  Future<void> fetch() async {
    if (_disposed || isLoading.peek()) return;
    batch(() {
      isLoading.value = true;
      error.value = null;
    });
    try {
      final result = await _loader();
      if (_disposed) return;
      batch(() {
        data.value = result;
        lastUpdated.value = DateTime.now();
        fetchCount.value = fetchCount.peek() + 1;
        isLoading.value = false;
      });
    } catch (e) {
      if (_disposed) return;
      batch(() {
        error.value = '$e';
        isLoading.value = false;
      });
    }
  }

  /// Releases all reactive signals owned by this section state.
  void dispose() {
    _disposed = true;
    data.dispose();
    isLoading.dispose();
    error.dispose();
    lastUpdated.dispose();
    fetchCount.dispose();
  }
}

/// Independent reactive controller managing each device subsystem separately.
///
/// Every subsystem (`device`, `battery`, `network`, `storage`, `display`) holds
/// its own isolated [SectionSignalState] so refreshing one subsystem never
/// triggers platform calls or UI rebuilds for the other four subsystems.
class DeviceInfoDashboardController {
  final SectionSignalState<DeviceInfo> deviceSection =
      SectionSignalState<DeviceInfo>(XueHuaDeviceInfo.getDeviceInfo);

  final SectionSignalState<BatteryInfo> batterySection =
      SectionSignalState<BatteryInfo>(XueHuaDeviceInfo.getBatteryInfo);

  final SectionSignalState<NetworkInfo> networkSection =
      SectionSignalState<NetworkInfo>(XueHuaDeviceInfo.getNetworkInfo);

  final SectionSignalState<StorageInfo> storageSection =
      SectionSignalState<StorageInfo>(XueHuaDeviceInfo.getStorageInfo);

  final SectionSignalState<DisplayInfo> displaySection =
      SectionSignalState<DisplayInfo>(XueHuaDeviceInfo.getDisplayInfo);

  /// Computed count of sections that have completed at least one successful fetch.
  late final ReadonlySignal<int> loadedSectionCount = computed<int>(() {
    var count = 0;
    if (deviceSection.data.value != null) count++;
    if (batterySection.data.value != null) count++;
    if (networkSection.data.value != null) count++;
    if (storageSection.data.value != null) count++;
    if (displaySection.data.value != null) count++;
    return count;
  });

  /// Computed flag indicating whether any individual section is currently loading.
  late final ReadonlySignal<bool> isAnySectionLoading = computed<bool>(() {
    return deviceSection.isLoading.value ||
        batterySection.isLoading.value ||
        networkSection.isLoading.value ||
        storageSection.isLoading.value ||
        displaySection.isLoading.value;
  });

  /// Fetches only the device identity section.
  Future<void> fetchDeviceOnly() => deviceSection.fetch();

  /// Fetches only the battery status section.
  Future<void> fetchBatteryOnly() => batterySection.fetch();

  /// Fetches only the network connection section.
  Future<void> fetchNetworkOnly() => networkSection.fetch();

  /// Fetches only the storage volume section.
  Future<void> fetchStorageOnly() => storageSection.fetch();

  /// Fetches only the display metrics section.
  Future<void> fetchDisplayOnly() => displaySection.fetch();

  bool _disposed = false;

  /// Sequentially triggers each section's independent fetch without coupling them
  /// into a single monolithic payload.
  Future<void> fetchAllSequentially() async {
    if (_disposed) return;
    await fetchDeviceOnly();
    if (_disposed) return;
    await fetchBatteryOnly();
    if (_disposed) return;
    await fetchNetworkOnly();
    if (_disposed) return;
    await fetchStorageOnly();
    if (_disposed) return;
    await fetchDisplayOnly();
  }

  /// Releases all section and computed signals managed by this controller.
  void dispose() {
    _disposed = true;
    loadedSectionCount.dispose();
    isAnySectionLoading.dispose();
    deviceSection.dispose();
    batterySection.dispose();
    networkSection.dispose();
    storageSection.dispose();
    displaySection.dispose();
  }
}
