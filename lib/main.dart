import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'models/app_state_provider.dart';
import 'utils/configuration_handler.dart';
import 'widgets/lifecycle_status_dashboard.dart';
import 'widgets/event_timeline.dart';
import 'widgets/service_controls.dart';
import 'widgets/background_task_manager.dart';
import 'widgets/alarm_scheduler.dart';
import 'widgets/state_persistence_panel.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize the app state provider
  final appState = AppStateProvider();
  await appState.initialize();
  
  runApp(
    ChangeNotifierProvider.value(
      value: appState,
      child: const LifecycleMasterApp(),
    ),
  );
}

/// Main application widget
class LifecycleMasterApp extends StatelessWidget {
  const LifecycleMasterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppStateProvider>(
      builder: (context, appState, child) {
        return MaterialApp(
          title: 'Lifecycle Master',
          debugShowCheckedModeBanner: false,
          themeMode: appState.themeMode,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue,
              brightness: Brightness.light,
            ),
            cardTheme: CardThemeData(
              elevation: 2,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue,
              brightness: Brightness.dark,
            ),
            cardTheme: CardThemeData(
              elevation: 2,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          ),
          home: const MainDashboard(),
        );
      },
    );
  }
}

/// Main dashboard screen
class MainDashboard extends StatefulWidget {
  const MainDashboard({super.key});

  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard> with WidgetsBindingObserver {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkOrientation();
    });
  }

  void _checkOrientation() {
    final orientation = MediaQuery.of(context).orientation;
    context.read<AppStateProvider>().configurationHandler.onOrientationChanged(orientation);
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _checkOrientation();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppStateProvider>(
      builder: (context, appState, child) {
        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                Icon(
                  Icons.monitor_heart,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                const Text('Lifecycle Master'),
              ],
            ),
            actions: [
              IconButton(
                key: const Key('toggle-theme-button'),
                icon: Icon(
                  appState.themeMode == ThemeMode.dark
                      ? Icons.light_mode
                      : Icons.dark_mode,
                ),
                onPressed: () => appState.toggleTheme(),
                tooltip: 'Toggle Theme',
              ),
              IconButton(
                key: const Key('save-state-button'),
                icon: const Icon(Icons.save),
                onPressed: () async {
                  await appState.saveState();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('State saved')),
                    );
                  }
                },
                tooltip: 'Save State',
              ),
              PopupMenuButton<String>(
                key: const Key('menu-button'),
                onSelected: (value) async {
                  switch (value) {
                    case 'clear':
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Clear All Data?'),
                          content: const Text(
                            'This will clear all saved state, events, and logs. This action cannot be undone.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.red,
                              ),
                              child: const Text('Clear'),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await appState.clearAllState();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('All data cleared')),
                          );
                        }
                      }
                      break;
                    case 'about':
                      showAboutDialog(
                        context: context,
                        applicationName: 'Lifecycle Master',
                        applicationVersion: '1.0.0',
                        applicationLegalese: '© 2024 Lifecycle Master App',
                        children: [
                          const SizedBox(height: 16),
                          const Text(
                            'An advanced Android application for mastering app lifecycle, state management, and background processing.',
                          ),
                        ],
                      );
                      break;
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'clear',
                    child: Row(
                      children: [
                        Icon(Icons.delete_forever, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Clear All Data'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'about',
                    child: Row(
                      children: [
                        Icon(Icons.info_outline),
                        SizedBox(width: 8),
                        Text('About'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          body: IndexedStack(
            index: _currentIndex,
            children: [
              _buildOverviewTab(appState),
              _buildServicesTab(appState),
              _buildStateTab(appState),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            key: const Key('bottom-navigation'),
            selectedIndex: _currentIndex,
            onDestinationSelected: (index) {
              setState(() => _currentIndex = index);
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: 'Overview',
              ),
              NavigationDestination(
                icon: Icon(Icons.miscellaneous_services_outlined),
                selectedIcon: Icon(Icons.miscellaneous_services),
                label: 'Services',
              ),
              NavigationDestination(
                icon: Icon(Icons.storage_outlined),
                selectedIcon: Icon(Icons.storage),
                label: 'State',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOverviewTab(AppStateProvider appState) {
    return ListenableBuilder(
      listenable: appState.lifecycleManager,
      builder: (context, _) {
        return RefreshIndicator(
          onRefresh: () async {
            setState(() {});
          },
          child: SingleChildScrollView(
            key: const Key('overview-scroll'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              children: [
                LifecycleStatusDashboard(
                  lifecycleManager: appState.lifecycleManager,
                ),
                EventTimeline(
                  events: appState.lifecycleManager.events,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildServicesTab(AppStateProvider appState) {
    return SingleChildScrollView(
      key: const Key('services-scroll'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          ListenableBuilder(
            listenable: appState.foregroundServiceManager,
            builder: (context, _) {
              return ServiceControls(
                serviceManager: appState.foregroundServiceManager,
                onStateChanged: () => setState(() {}),
              );
            },
          ),
          const BackgroundTaskManager(),
          ListenableBuilder(
            listenable: appState.alarmService,
            builder: (context, _) {
              return AlarmScheduler(
                alarmService: appState.alarmService,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStateTab(AppStateProvider appState) {
    return SingleChildScrollView(
      key: const Key('state-scroll'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          ListenableBuilder(
            listenable: appState.stateRecoveryManager,
            builder: (context, _) {
              return StatePersistencePanel(
                recoveryManager: appState.stateRecoveryManager,
              );
            },
          ),
          _buildConfigurationChangesCard(appState),
        ],
      ),
    );
  }

  Widget _buildConfigurationChangesCard(AppStateProvider appState) {
    return ListenableBuilder(
      listenable: appState.configurationHandler,
      builder: (context, _) {
        final changes = appState.configurationHandler.changes;
        return Card(
          key: const Key('configuration-changes-card'),
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
                        Icon(Icons.settings_suggest, size: 24),
                        SizedBox(width: 12),
                        Text(
                          'Configuration Changes',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${changes.length} changes',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
                const Divider(height: 24),
                if (changes.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'No configuration changes recorded',
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: changes.take(10).length,
                    itemBuilder: (context, index) {
                      final change = changes[index];
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          _getConfigIcon(change.type),
                          color: Colors.blue,
                          size: 20,
                        ),
                        title: Text(
                          '${change.oldValue} → ${change.newValue}',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        subtitle: Text(
                          '${change.type.name} • ${_formatTime(change.timestamp)}',
                          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  IconData _getConfigIcon(ConfigChangeType type) {
    switch (type) {
      case ConfigChangeType.orientation:
        return Icons.screen_rotation;
      case ConfigChangeType.theme:
        return Icons.palette;
      case ConfigChangeType.locale:
        return Icons.language;
      case ConfigChangeType.fontScale:
        return Icons.text_fields;
    }
  }

  String _formatTime(DateTime timestamp) {
    return '${timestamp.hour.toString().padLeft(2, '0')}:'
        '${timestamp.minute.toString().padLeft(2, '0')}:'
        '${timestamp.second.toString().padLeft(2, '0')}';
  }
}
