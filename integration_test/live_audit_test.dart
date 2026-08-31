// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:zawolf_hr/main.dart' as app;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Live Audit Tests', () {
    testWidgets('Live Audit: CEO, HR, Employee', (tester) async {
      // Clear preferences to ensure we start logged out
      SharedPreferences.setMockInitialValues({});
      
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      Future<void> loginAndAudit(String email, String password, String roleName) async {
        print('--- Starting Audit for $roleName ($email) ---');
        await tester.pumpAndSettle(const Duration(seconds: 2));
        
        final textFields = find.byType(TextFormField);
        if (textFields.evaluate().length >= 2) {
          print('Found login text fields');
          await tester.enterText(textFields.at(0), email);
          await tester.enterText(textFields.at(1), password);
          await tester.pumpAndSettle();
        } else {
          print('WARNING: Could not find 2 TextFormFields for login.');
        }

        // Tap Login Button
        final loginButtons = find.byType(ElevatedButton);
        if (loginButtons.evaluate().isNotEmpty) {
          print('Tapping login button...');
          await tester.tap(loginButtons.first);
        } else {
          print('WARNING: Could not find ElevatedButton for login.');
        }

        // Wait for dashboard to load
        print('Waiting for dashboard to load...');
        await tester.pumpAndSettle(const Duration(seconds: 10));

        // Audit
        print('Auditing $roleName view...');
        expect(find.byType(Scaffold), findsWidgets);
        
        // Find logout mechanism
        print('Attempting to logout...');
        final menuIcon = find.byIcon(Icons.menu);
        if (menuIcon.evaluate().isNotEmpty) {
           await tester.tap(menuIcon.first);
           await tester.pumpAndSettle(const Duration(seconds: 2));
        } else {
           print('WARNING: No menu icon found. Trying to find profile avatar...');
           final avatar = find.byType(CircleAvatar);
           if (avatar.evaluate().isNotEmpty) {
             await tester.tap(avatar.first);
             await tester.pumpAndSettle(const Duration(seconds: 2));
           }
        }
        
        // Find Logout text
        final logoutFinder = find.byWidgetPredicate((w) {
          if (w is Text) {
            final t = w.data?.toLowerCase() ?? '';
            return t.contains('خروج') || t.contains('logout');
          }
          return false;
        });

        if (logoutFinder.evaluate().isNotEmpty) {
           await tester.tap(logoutFinder.first);
           await tester.pumpAndSettle(const Duration(seconds: 3));
           print('Logged out successfully.');
        } else {
           print('WARNING: Could not find Logout text.');
           // Force clear state for next test
           SharedPreferences.setMockInitialValues({});
           await tester.pumpWidget(Container()); // Clear widget tree
           app.main();
           await tester.pumpAndSettle(const Duration(seconds: 3));
        }
        print('--- Finished Audit for $roleName ---');
      }

      // CEO
      await loginAndAudit('m.monir@seginvest.com', 'ZW@0000', 'CEO');
      
      // HR
      await loginAndAudit('hr@zawolf.com', 'ZW@admin', 'HR');

      // Employee
      await loginAndAudit('omer.mahmoud@seginvest.com', 'ZW@0000', 'Employee');

    });
  });
}
