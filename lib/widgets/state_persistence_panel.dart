import 'package:flutter/material.dart';
import '../managers/state_recovery_manager.dart';

/// Widget for managing state persistence and recovery
class StatePersistencePanel extends StatefulWidget {
  final StateRecoveryManager recoveryManager;

  const StatePersistencePanel({
    super.key,
    required this.recoveryManager,
  });

  @override
  State<StatePersistencePanel> createState() => _StatePersistencePanelState();
}

class _StatePersistencePanelState extends State<StatePersistencePanel> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _notesController = TextEditingController();
  bool _hasSnapshot = false;
  int _snapshotSize = 0;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final snapshot = widget.recoveryManager.currentSnapshot;
    if (snapshot != null) {
      _nameController.text = snapshot.formData['name']?.toString() ?? '';
      _emailController.text = snapshot.formData['email']?.toString() ?? '';
      _notesController.text = snapshot.formData['notes']?.toString() ?? '';
    }
    
    _hasSnapshot = await widget.recoveryManager.hasSnapshot();
    _snapshotSize = await widget.recoveryManager.getSnapshotSize();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const Key('state-persistence-panel'),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.save, size: 24),
                SizedBox(width: 12),
                Text(
                  'State Persistence',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            
            // Status
            _buildStatusRow(
              context,
              'Snapshot Available',
              _hasSnapshot ? 'Yes' : 'No',
              _hasSnapshot ? Colors.green : Colors.grey,
            ),
            _buildStatusRow(
              context,
              'Snapshot Size',
              _formatBytes(_snapshotSize),
              null,
            ),
            if (widget.recoveryManager.lastSaveTimestamp != null)
              _buildStatusRow(
                context,
                'Last Saved',
                _formatTimestamp(widget.recoveryManager.lastSaveTimestamp!),
                null,
              ),
            
            const SizedBox(height: 16),
            
            // Form Data Demo
            Text(
              'Form Data (survives process death)',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 12),
            
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    key: const Key('form-name-field'),
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                    onChanged: (value) => _saveFormField('name', value),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('form-email-field'),
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    onChanged: (value) => _saveFormField('email', value),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('form-notes-field'),
                    controller: _notesController,
                    decoration: const InputDecoration(
                      labelText: 'Notes',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.note),
                    ),
                    maxLines: 3,
                    onChanged: (value) => _saveFormField('notes', value),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    key: const Key('save-snapshot-button'),
                    onPressed: () async {
                      await widget.recoveryManager.saveSnapshot(
                        formData: {
                          'name': _nameController.text,
                          'email': _emailController.text,
                          'notes': _notesController.text,
                        },
                      );
                      await _loadState();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('State snapshot saved')),
                        );
                      }
                    },
                    icon: const Icon(Icons.save),
                    label: const Text('Save Snapshot'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('restore-snapshot-button'),
                    onPressed: !_hasSnapshot
                        ? null
                        : () async {
                            await widget.recoveryManager.restoreFromSnapshot();
                            await _loadState();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('State restored from snapshot')),
                              );
                            }
                          },
                    icon: const Icon(Icons.restore),
                    label: const Text('Restore'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                key: const Key('clear-state-button'),
                onPressed: () async {
                  await widget.recoveryManager.clearState();
                  _nameController.clear();
                  _emailController.clear();
                  _notesController.clear();
                  await _loadState();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('All state cleared')),
                    );
                  }
                },
                icon: const Icon(Icons.delete_forever),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                ),
                label: const Text('Clear All State'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(
    BuildContext context,
    String label,
    String value,
    Color? valueColor,
  ) {
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
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveFormField(String key, String value) async {
    await widget.recoveryManager.updateFormField(key, value);
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatTimestamp(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
  }
}
