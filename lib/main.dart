import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'firebase_bootstrap.dart';
import 'screens/dashboard_screen.dart';
import 'screens/login_screen.dart';
import 'services/auth_service.dart';
import 'services/course_firestore_service.dart';
import 'services/simulation_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeFirebaseApp();
  final authService = AuthService();
  final courseFirestoreService = CourseFirestoreService();
  final simulationService = SimulationService();
  runApp(
    MultiProvider(
      providers: [
        Provider<AuthService>.value(value: authService),
        Provider<CourseFirestoreService>.value(value: courseFirestoreService),
        ChangeNotifierProvider<SimulationService>.value(value: simulationService),
        StreamProvider<User?>(
          create: (_) => authService.authStateChanges,
          initialData: authService.currentUser,
        ),
      ],
      child: const GradeMasterApp(),
    ),
  );
}

class GradeMasterApp extends StatelessWidget {
  const GradeMasterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GradeMaster',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: Builder(
        builder: (context) {
          final auth = context.read<AuthService>();
          return StreamBuilder<User?>(
            stream: auth.authStateChanges,
            initialData: auth.currentUser,
            builder: (context, snapshot) {
              final user = snapshot.data;
              if (user == null) {
                return const LoginScreen();
              }
              return const DashboardScreen();
            },
          );
        },
      ),
    );
  }
}
