import 'package:flutter/material.dart';
import '../workers/background_workers.dart';

/// Widget for managing background tasks
class BackgroundTaskManager extends StatefulWidget {
  const BackgroundTaskManager({super.key});

  @override
  State<BackgroundTaskManager> createState() => _BackgroundTaskManagerState();
}

class _BackgroundTaskManagerState extends State<BackgroundTaskManager> {
  List<Map<String, dynamic>> _executions = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadExecutions();
  }

  Future<void> _loadExecutions() async {
    setState(() => _isLoading = true);
    final executions = await BackgroundWorkers.getExecutions();
    setState(() {
      _executions = executions.reversed.take(10).toList();
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const Key('background-task-manager'),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: const [
                    Icon(Icons.schedule, size: 24),
                    SizedBox(width: 12),
                    Text(
                      'Background Tasks',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  key: const Key('refresh-tasks-button'),
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadExecutions,
                ),
              ],
            ),
            const Divider(height: 24),
            
            // Task Cards
            _buildTaskCard(
              context,
              'Data Sync',
              BackgroundWorkers.syncDataTaskName,
              'Every 15 minutes',
              Icons.sync,
              Colors.blue,
            ),
            const SizedBox(height: 12),
            _buildTaskCard(
              context,
              'Cleanup',
              BackgroundWorkers.cleanupTaskName,
              'Daily',
              Icons.cleaning_services,
              Colors.orange,
            ),
            const SizedBox(height: 12),
            _buildTaskCard(
              context,
              'Health Check',
              BackgroundWorkers.healthCheckTaskName,
              'Every 30 minutes',
              Icons.health_and_safety,
              Colors.green,
            ),
            
            const SizedBox(height: 24),
            
            // Recent Executions
            Text(
              'Recent Executions',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_executions.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'No executions recorded yet',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _executions.length,
                itemBuilder: (context, index) {
                  final exec = _executions[index];
                  return _ExecutionTile(execution: exec);
                },
              ),
            
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('cancel-all-tasks-button'),
                    onPressed: () async {
                      await BackgroundWorkers.cancelAllTasks();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('All tasks cancelled')),
                      );
                    },
                    icon: const Icon(Icons.cancel),
                    label: const Text('Cancel All'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    key: const Key('reschedule-tasks-button'),
                    onPressed: () async {
                      await BackgroundWorkers.scheduleAllTasks();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Tasks rescheduled')),
                      );
                    },
                    icon: const Icon(Icons.schedule),
                    label: const Text('Reschedule'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskCard(
    BuildContext context,
    String title,
    String taskName,
    String frequency,
    IconData icon,
    Color color,
  ) {
    return Container(
      key: Key('task-card-$taskName'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: color.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(8),
        color: color.withOpacity(0.05),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  frequency,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          ElevatedButton(
            key: Key('run-now-$taskName'),
            onPressed: () async {
              await BackgroundWorkers.runTaskNow(taskName);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$title task queued')),
              );
              _loadExecutions();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: const Text('Run Now'),
          ),
        ],
      ),
    );
  }
}

class _ExecutionTile extends StatelessWidget {
  final Map<String, dynamic> execution;

  const _ExecutionTile({required this.execution});

  @override
  Widget build(BuildContext context) {
    final success = execution['success'] as bool? ?? false;
    final taskName = execution['taskName'] as String? ?? 'Unknown';
    final timestamp = execution['timestamp'] as String?;
    final durationMs = execution['duration_ms'] as int? ?? 0;

    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        success ? Icons.check_circle : Icons.error,
        color: success ? Colors.green : Colors.red,
        size: 20,
      ),
      title: Text(
        taskName,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: timestamp != null
          ? Text(
              _formatTimestamp(timestamp),
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            )
          : null,
      trailing: Text(
        '${durationMs}ms',
        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
      ),
    );
  }

  String _formatTimestamp(String isoTimestamp) {
    final dt = DateTime.tryParse(isoTimestamp);
    if (dt == null) return isoTimestamp;
    return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
