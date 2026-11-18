import 'package:material_ui/material_ui.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../state/device_info_signals.dart';

/// Data descriptor for a single key-value row inside a section card.
class InfoMetricItem {
  const InfoMetricItem({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;
}

/// Reusable section card that subscribes only to its own [SectionSignalState]
/// via [SignalBuilder], ensuring surgical widget rebuilds without `setState`.
class DeviceSectionCard<T> extends StatelessWidget {
  const DeviceSectionCard({
    super.key,
    required this.sectionKeyPrefix,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.state,
    required this.metricsBuilder,
    this.progressBuilder,
  });

  final String sectionKeyPrefix;
  final String title;
  final String subtitle;
  final IconData icon;
  final SectionSignalState<T> state;
  final List<InfoMetricItem> Function(T data) metricsBuilder;
  final double? Function(T data)? progressBuilder;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      key: Key('${sectionKeyPrefix}_card'),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    color: colorScheme.onPrimaryContainer,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        key: Key('${sectionKeyPrefix}_title'),
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                SignalBuilder(
                  builder: (context) {
                    final loading = state.isLoading.value;
                    final count = state.fetchCount.value;
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (count > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.secondaryContainer,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '#$count',
                              style: textTheme.labelSmall?.copyWith(
                                color: colorScheme.onSecondaryContainer,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        const SizedBox(width: 8),
                        FilledButton.tonalIcon(
                          key: Key('${sectionKeyPrefix}_fetch_button'),
                          onPressed: loading ? null : state.fetch,
                          icon: loading
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.refresh, size: 16),
                          label: Text(count == 0 ? '获取' : '单独刷新'),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            SignalBuilder(
              builder: (context) {
                final loading = state.isLoading.value;
                final err = state.error.value;
                final current = state.data.value;
                final updated = state.lastUpdated.value;

                if (loading && current == null) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final Widget? errorBanner = err == null
                    ? null
                    : Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: SelectableText(
                          'Error: $err',
                          key: Key('${sectionKeyPrefix}_error'),
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onErrorContainer,
                          ),
                        ),
                      );

                if (current == null) {
                  if (errorBanner != null) {
                    return errorBanner;
                  }
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      '尚未获取该模块数据，点击右上角「获取」按钮独立读取。',
                      key: Key('${sectionKeyPrefix}_empty'),
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                }

                final metrics = metricsBuilder(current);
                final progress = progressBuilder?.call(current);

                return Column(
                  key: Key('${sectionKeyPrefix}_content'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (errorBanner != null) ...[
                      errorBanner,
                      const SizedBox(height: 12),
                    ],
                    if (progress != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: progress.clamp(0.0, 1.0),
                          minHeight: 8,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    for (final item in metrics)
                      _MetricRowTile(
                        sectionKeyPrefix: sectionKeyPrefix,
                        item: item,
                      ),
                    if (updated != null) ...[
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          '更新时间: ${_formatTime(updated)}',
                          style: textTheme.labelSmall?.copyWith(
                            color: colorScheme.outline,
                          ),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  static String _formatTime(DateTime time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    final s = time.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}

class _MetricRowTile extends StatelessWidget {
  const _MetricRowTile({
    required this.sectionKeyPrefix,
    required this.item,
  });

  final String sectionKeyPrefix;
  final InfoMetricItem item;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 148,
            child: Text(
              item.label,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SelectableText(
              item.value,
              key: Key('${sectionKeyPrefix}_field_${item.label}'),
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: item.highlight ? FontWeight.w700 : FontWeight.w500,
                color: item.highlight
                    ? colorScheme.primary
                    : colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
