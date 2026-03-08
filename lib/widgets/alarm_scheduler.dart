import 'package:flutter/material.dart';
import '../services/alarm_service.dart';

/// Widget for scheduling and managing alarms
class AlarmScheduler extends StatefulWidget {
  final AlarmService alarmService;

  const AlarmScheduler({
    super.key,
    required this.alarmService,
  });

  @override
  State<AlarmScheduler> createState() => _AlarmSchedulerState();
}

class _AlarmSchedulerState extends State<AlarmScheduler> {
  DateTime _selectedTime = DateTime.now().add(const Duration(minutes: 5));

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const Key('alarm-scheduler'),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.alarm, size: 24),
                SizedBox(width: 12),
                Text(
                  'Exact Alarms',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            
            // Schedule New Alarm
            Text(
              'Schedule New Alarm',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('select-alarm-time-button'),
                    onPressed: () => _selectDateTime(context),
                    icon: const Icon(Icons.access_time),
                    label: Text(
                      _formatDateTime(_selectedTime),
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  key: const Key('schedule-alarm-button'),
                  onPressed: () async {
                    await widget.alarmService.scheduleExactAlarm(
                      alarmTime: _selectedTime,
                      title: 'Scheduled Alarm',
                      body: 'Your alarm at ${_formatDateTime(_selectedTime)} has triggered!',
                    );
                    setState(() {});
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Alarm scheduled for ${_formatDateTime(_selectedTime)}'),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.add_alarm),
                  label: const Text('Schedule'),
                ),
              ],
            ),
            
            // Quick Schedule Buttons
            const SizedBox(height: 12),
            Row(
              children: [
                _buildQuickButton('1 min', const Duration(minutes: 1)),
                const SizedBox(width: 8),
                _buildQuickButton('5 min', const Duration(minutes: 5)),
                const SizedBox(width: 8),
                _buildQuickButton('15 min', const Duration(minutes: 15)),
                const SizedBox(width: 8),
                _buildQuickButton('1 hour', const Duration(hours: 1)),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Pending Alarms
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Pending Alarms',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(
                  '${widget.alarmService.pendingAlarms.length} pending',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            if (widget.alarmService.pendingAlarms.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'No pending alarms',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: widget.alarmService.pendingAlarms.length,
                itemBuilder: (context, index) {
                  final alarm = widget.alarmService.pendingAlarms[index];
                  return _AlarmTile(
                    alarm: alarm,
                    onCancel: () async {
                      await widget.alarmService.cancelAlarm(alarm.id);
                      setState(() {});
                    },
                  );
                },
              ),
            
            // Triggered Alarms
            if (widget.alarmService.triggeredAlarms.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Triggered Alarms',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: widget.alarmService.triggeredAlarms.take(5).length,
                itemBuilder: (context, index) {
                  final alarm = widget.alarmService.triggeredAlarms[index];
                  return _AlarmTile(
                    alarm: alarm,
                    isTriggered: true,
                    onCancel: () async {
                      await widget.alarmService.cancelAlarm(alarm.id);
                      setState(() {});
                    },
                  );
                },
              ),
            ],
            
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                key: const Key('cancel-all-alarms-button'),
                onPressed: widget.alarmService.alarms.isEmpty
                    ? null
                    : () async {
                        await widget.alarmService.cancelAllAlarms();
                        setState(() {});
                      },
                icon: const Icon(Icons.clear_all),
                label: const Text('Cancel All Alarms'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickButton(String label, Duration duration) {
    return Expanded(
      child: OutlinedButton(
        onPressed: () {
          setState(() {
            _selectedTime = DateTime.now().add(duration);
          });
        },
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 4),
        ),
        child: Text(label, style: const TextStyle(fontSize: 12)),
      ),
    );
  }

  Future<void> _selectDateTime(BuildContext context) async {
    final now = DateTime.now();
    
    // Select date
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedTime,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    
    if (date == null || !mounted) return;
    
    // Select time
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedTime),
    );
    
    if (time == null || !mounted) return;
    
    setState(() {
      _selectedTime = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _AlarmTile extends StatelessWidget {
  final ScheduledAlarm alarm;
  final bool isTriggered;
  final VoidCallback onCancel;

  const _AlarmTile({
    required this.alarm,
    this.isTriggered = false,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        isTriggered ? Icons.alarm_on : Icons.alarm,
        color: isTriggered ? Colors.green : Colors.orange,
        size: 20,
      ),
      title: Text(
        _formatDateTime(alarm.scheduledTime),
        style: TextStyle(
          fontWeight: FontWeight.w500,
          decoration: isTriggered ? TextDecoration.lineThrough : null,
        ),
      ),
      subtitle: Text(
        'ID: ${alarm.id.substring(0, 8)}...',
        style: TextStyle(fontSize: 10, color: Colors.grey[500]),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline, size: 20),
        onPressed: onCancel,
        color: Colors.red,
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.month}/${dt.day}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
