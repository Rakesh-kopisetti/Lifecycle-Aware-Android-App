import 'package:flutter/material.dart';
import '../managers/lifecycle_manager.dart';

/// Widget displaying the current lifecycle status
class LifecycleStatusDashboard extends StatelessWidget {
  final LifecycleManager lifecycleManager;

  const LifecycleStatusDashboard({
    super.key,
    required this.lifecycleManager,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const Key('lifecycle-status-dashboard'),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getStateIcon(),
                  color: _getStateColor(),
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  'Lifecycle Status',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const Divider(height: 24),
            _buildInfoRow(
              context,
              'Current State',
              lifecycleManager.lifecycleStateString.toUpperCase(),
              _getStateColor(),
              testId: 'current-lifecycle-state',
            ),
            _buildInfoRow(
              context,
              'Configuration Changes',
              '${lifecycleManager.configurationChangeCount}',
              null,
              testId: 'config-change-count',
            ),
            _buildInfoRow(
              context,
              'Total Resumed Time',
              _formatDuration(lifecycleManager.totalResumedTime),
              null,
              testId: 'total-resumed-time',
            ),
            _buildInfoRow(
              context,
              'Total Background Time',
              _formatDuration(lifecycleManager.totalBackgroundTime),
              null,
              testId: 'total-background-time',
            ),
            if (lifecycleManager.lastPauseTimestamp != null) ...[
              _buildInfoRow(
                context,
                'Last Paused',
                _formatTimestamp(lifecycleManager.lastPauseTimestamp!),
                null,
                testId: 'last-pause-timestamp',
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    String label,
    String value,
    Color? valueColor, {
    String? testId,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          Text(
            value,
            key: testId != null ? Key(testId) : null,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getStateIcon() {
    switch (lifecycleManager.lifecycleState) {
      case AppLifecycleState.resumed:
        return Icons.play_circle_filled;
      case AppLifecycleState.paused:
        return Icons.pause_circle_filled;
      case AppLifecycleState.inactive:
        return Icons.pending;
      case AppLifecycleState.detached:
        return Icons.power_off;
      case AppLifecycleState.hidden:
        return Icons.visibility_off;
    }
  }

  Color _getStateColor() {
    switch (lifecycleManager.lifecycleState) {
      case AppLifecycleState.resumed:
        return Colors.green;
      case AppLifecycleState.paused:
        return Colors.orange;
      case AppLifecycleState.inactive:
        return Colors.yellow[700]!;
      case AppLifecycleState.detached:
        return Colors.red;
      case AppLifecycleState.hidden:
        return Colors.grey;
    }
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    return '${hours}h ${minutes}m ${secs}s';
  }

  String _formatTimestamp(DateTime timestamp) {
    return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}';
  }
}
