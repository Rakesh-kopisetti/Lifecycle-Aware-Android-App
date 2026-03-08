import 'package:flutter/material.dart';
import '../services/foreground_service.dart';

/// Widget for controlling the foreground service
class ServiceControls extends StatelessWidget {
  final ForegroundServiceManager serviceManager;
  final VoidCallback? onStateChanged;

  const ServiceControls({
    super.key,
    required this.serviceManager,
    this.onStateChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const Key('service-controls'),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.settings_applications,
                  size: 24,
                  color: serviceManager.isRunning ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 12),
                Text(
                  'Foreground Service',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Status',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
                Container(
                  key: const Key('service-status'),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: serviceManager.isRunning
                        ? Colors.green.withOpacity(0.1)
                        : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: serviceManager.isRunning
                          ? Colors.green
                          : Colors.grey,
                    ),
                  ),
                  child: Text(
                    serviceManager.isRunning ? 'RUNNING' : 'STOPPED',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: serviceManager.isRunning
                          ? Colors.green
                          : Colors.grey,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow(
              context,
              'Session Uptime',
              serviceManager.formattedSessionUptime,
              testId: 'session-uptime',
            ),
            _buildInfoRow(
              context,
              'Total Uptime',
              serviceManager.formattedTotalUptime,
              testId: 'total-uptime',
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    key: const Key('start-service-button'),
                    onPressed: serviceManager.isRunning
                        ? null
                        : () async {
                            await serviceManager.startService();
                            onStateChanged?.call();
                          },
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    key: const Key('stop-service-button'),
                    onPressed: !serviceManager.isRunning
                        ? null
                        : () async {
                            await serviceManager.stopService();
                            onStateChanged?.call();
                          },
                    icon: const Icon(Icons.stop),
                    label: const Text('Stop'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                key: const Key('reset-uptime-button'),
                onPressed: () async {
                  await serviceManager.resetTotalUptime();
                  onStateChanged?.call();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Reset Total Uptime'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    String label,
    String value, {
    String? testId,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
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
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}
