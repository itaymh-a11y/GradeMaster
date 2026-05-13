import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:grade_master/grade_master.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../services/course_firestore_service.dart';
import 'dashboard_screen.dart';
import 'degree_selection_screen.dart';
import 'login_screen.dart';

/// מחובר → [DegreeSelectionScreen] אם חסר מוסד/חוג, אחרת [DashboardScreen].
class AuthGateScreen extends StatelessWidget {
  const AuthGateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: context.read<AuthService>().authStateChanges,
      initialData: context.read<AuthService>().currentUser,
      builder: (context, authSnap) {
        final user = authSnap.data;
        if (user == null) {
          return const LoginScreen();
        }
        // Web: ודא ש־ID token מצורף לבקשות Firestore לפני snapshot ל־`users/{uid}`.
        return FutureBuilder<void>(
          key: ValueKey(user.uid),
          future: user.getIdToken(),
          builder: (context, tokenSnap) {
            if (tokenSnap.connectionState != ConnectionState.done) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            if (tokenSnap.hasError) {
              return Scaffold(
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('שגיאת אימות: ${tokenSnap.error}'),
                  ),
                ),
              );
            }
            final courses = context.read<CourseFirestoreService>();
            return StreamBuilder<UserModel>(
              stream: courses.watchUserModel(user.uid),
              builder: (context, profileSnap) {
                if (profileSnap.hasError) {
                  return Scaffold(
                    body: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text('שגיאה בטעינת פרופיל: ${profileSnap.error}'),
                      ),
                    ),
                  );
                }
                if (profileSnap.connectionState == ConnectionState.waiting &&
                    !profileSnap.hasData) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }
                final profile = profileSnap.data ?? UserModel(uid: user.uid);
                if (profile.needsInstitutionOnboarding) {
                  return const DegreeSelectionScreen();
                }
                return const DashboardScreen();
              },
            );
          },
        );
      },
    );
  }
}
