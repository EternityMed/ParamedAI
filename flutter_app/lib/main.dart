import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config/theme.dart';
import 'features/chat/chat_controller.dart';
import 'features/chat/chat_screen.dart';
import 'features/triage/triage_screen.dart';
import 'features/documentation/patients_screen.dart';
import 'features/documentation/patients_controller.dart';


void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Show detailed error info instead of red box
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Container(
      padding: const EdgeInsets.all(8),
      color: ParamedTheme.card,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Widget Error:', style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold, decoration: TextDecoration.none)),
          const SizedBox(height: 4),
          Text(
            details.exceptionAsString(),
            style: const TextStyle(color: Colors.white70, fontSize: 10, decoration: TextDecoration.none),
            maxLines: 10,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  };

  runApp(const ProviderScope(child: ParamedAIApp()));
}

class ParamedAIApp extends StatelessWidget {
  const ParamedAIApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ParaMed AI',
      debugShowCheckedModeBanner: false,
      theme: ParamedTheme.lightTheme,
      home: const MainScreen(),
    );
  }
}

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    ChatScreen(),
    TriageScreen(),
    DocScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    // Listen for "Send to Assistant" navigation events
    ref.listen(chatNavigationProvider, (prev, next) {
      if (next != null && (prev == null || prev.timestamp != next.timestamp)) {
        // Switch to Assistant tab
        setState(() => _currentIndex = 0);
        // Send the message to chat
        ref.read(chatControllerProvider.notifier).sendMessage(next.message);
        // Clear the navigation event
        ref.read(chatNavigationProvider.notifier).state = null;
      }
    });

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        backgroundColor: ParamedTheme.surface,
        indicatorColor: ParamedTheme.medicalBlue.withValues(alpha: 0.15),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.chat_outlined),
            selectedIcon: Icon(Icons.chat, color: ParamedTheme.medicalBlue),
            label: 'Assistant',
          ),
          NavigationDestination(
            icon: Icon(Icons.emergency_outlined),
            selectedIcon: Icon(Icons.emergency, color: ParamedTheme.emergencyRed),
            label: 'Triage',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outlined),
            selectedIcon: Icon(Icons.people, color: ParamedTheme.safeGreen),
            label: 'Patients',
          ),
        ],
      ),
    ),
    );
  }
}
