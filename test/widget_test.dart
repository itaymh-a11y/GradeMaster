import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:grade_master/main.dart';
import 'package:grade_master/services/auth_service.dart';
import 'package:grade_master/services/course_firestore_service.dart';

void main() {
  testWidgets('GradeMasterApp shows login when wrapped with providers', (
    WidgetTester tester,
  ) async {
    final mockAuth = MockFirebaseAuth(signedIn: false);
    final fakeFs = FakeFirebaseFirestore();
    final auth = AuthService(auth: mockAuth, firestore: fakeFs);
    final courses = CourseFirestoreService(auth: mockAuth, firestore: fakeFs);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AuthService>.value(value: auth),
          Provider<CourseFirestoreService>.value(value: courses),
          StreamProvider<User?>(
            create: (_) => auth.authStateChanges,
            initialData: auth.currentUser,
          ),
        ],
        child: const GradeMasterApp(),
      ),
    );
    await tester.pump();
    expect(find.text('התחברות'), findsOneWidget);
  });
}
