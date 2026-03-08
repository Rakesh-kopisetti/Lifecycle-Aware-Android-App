import 'package:flutter/material.dart';
import '../managers/lifecycle_manager.dart';

/// Widget displaying a timeline of lifecycle events
class EventTimeline extends StatelessWidget {
  final List<LifecycleEvent> events;
  final int maxEvents;

  const EventTimeline({
    super.key,
    required this.events,
    this.maxEvents = 20,
  });

  @override
  Widget build(BuildContext context) {
    final displayEvents = events.take(maxEvents).toList();

    return Card(
      key: const Key('event-timeline'),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.timeline, size: 24),
                    const SizedBox(width: 12),
                    Text(
                      'Event Timeline',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
                Text(
                  '${events.length} events',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            if (displayEvents.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Text(
                    'No events recorded yet',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[500],
                    ),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: displayEvents.length,
                itemBuilder: (context, index) {
                  final event = displayEvents[index];
                  return _EventTimelineItem(
                    event: event,
                    isFirst: index == 0,
                    isLast: index == displayEvents.length - 1,
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _EventTimelineItem extends StatelessWidget {
  final LifecycleEvent event;
  final bool isFirst;
  final bool isLast;

  const _EventTimelineItem({
    required this.event,
    required this.isFirst,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 32,
            child: Column(
              children: [
                if (!isFirst)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: Colors.grey[300],
                    ),
                  ),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _getEventColor(),
                    border: Border.all(
                      color: _getEventColor(),
                      width: 2,
                    ),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: Colors.grey[300],
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _getEventColor().withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _getEventColor().withOpacity(0.5),
                          ),
                        ),
                        child: Text(
                          event.eventType.replaceAll('_', ' ').toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _getEventColor(),
                          ),
                        ),
                      ),
                      Text(
                        _formatTime(event.timestamp),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                  if (event.metadata.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      _formatMetadata(event.metadata),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getEventColor() {
    switch (event.eventType) {
      case 'app_resumed':
        return Colors.green;
      case 'app_paused':
        return Colors.orange;
      case 'app_inactive':
        return Colors.yellow[700]!;
      case 'app_detached':
        return Colors.red;
      case 'app_hidden':
        return Colors.grey;
      case 'config_changed':
        return Colors.blue;
      case 'foreground_service_started':
        return Colors.purple;
      case 'foreground_service_stopped':
        return Colors.purple[300]!;
      case 'alarm_scheduled':
      case 'alarm_triggered':
        return Colors.teal;
      case 'state_restored':
      case 'state_snapshot_saved':
        return Colors.indigo;
      default:
        return Colors.grey;
    }
  }

  String _formatTime(DateTime timestamp) {
    return '${timestamp.hour.toString().padLeft(2, '0')}:'
        '${timestamp.minute.toString().padLeft(2, '0')}:'
        '${timestamp.second.toString().padLeft(2, '0')}';
  }

  String _formatMetadata(Map<String, dynamic> metadata) {
    return metadata.entries
        .map((e) => '${e.key}: ${e.value}')
        .join(', ');
  }
}
