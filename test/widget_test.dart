import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:decide_for_me/main.dart';
import 'package:decide_for_me/services/version_enforcer.dart';

void main() {
  testWidgets('DecideForMeApp renders Coin Flip home', (WidgetTester tester) async {
    await tester.pumpWidget(const DecideForMeApp());
    await tester.pumpAndSettle();
    expect(find.text('Coin Flip'), findsOneWidget);
    expect(find.text('Flip'), findsOneWidget);
  });

  testWidgets('hard update blocks app until updated', (WidgetTester tester) async {
    final enforcer = VersionEnforcer(
      policyUri: Uri.parse('https://smolkapps.com/api/versions/decide-for-me.json'),
      appName: 'Decide For Me',
      defaultAppVersion: '0.9.0',
      defaultStoreUrl: 'https://apps.apple.com/app/id6785593979',
      isIosOverride: true,
      policyLoader: (_) async => {
        'app_id': 'org.smolkin.DecideForMe',
        'min_supported_version': '1.0.0',
        'latest_version': '1.0.0',
        'blocked_versions': <String>[],
        'maintenance_mode': false,
        'store_url_ios': 'itms-apps://itunes.apple.com/app/id6785593979',
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => VersionEnforcerGate(
          policyUri: enforcer.policyUri,
          appName: 'Decide For Me',
          defaultAppVersion: '0.9.0',
          defaultStoreUrl: enforcer.defaultStoreUrl,
          enforcer: enforcer,
          child: child!,
        ),
        home: const Scaffold(body: Text('Flip Screen')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Update Required'), findsOneWidget);
    expect(find.text('Update Now'), findsOneWidget);
    enforcer.dispose();
  });

  testWidgets('soft update dismisses via Not Now', (WidgetTester tester) async {
    final enforcer = VersionEnforcer(
      policyUri: Uri.parse('https://smolkapps.com/api/versions/decide-for-me.json'),
      appName: 'Decide For Me',
      defaultAppVersion: '1.0.0',
      defaultStoreUrl: 'https://apps.apple.com/app/id6785593979',
      isIosOverride: true,
      policyLoader: (_) async => {
        'app_id': 'org.smolkin.DecideForMe',
        'min_supported_version': '1.0.0',
        'latest_version': '1.1.0',
        'blocked_versions': <String>[],
        'maintenance_mode': false,
        'store_url_ios': 'itms-apps://itunes.apple.com/app/id6785593979',
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => VersionEnforcerGate(
          policyUri: enforcer.policyUri,
          appName: 'Decide For Me',
          defaultAppVersion: '1.0.0',
          defaultStoreUrl: enforcer.defaultStoreUrl,
          enforcer: enforcer,
          child: child!,
        ),
        home: const Scaffold(body: Text('Flip Screen')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('New Version Available'), findsOneWidget);
    await tester.tap(find.text('Not Now'));
    await tester.pumpAndSettle();
    expect(find.text('New Version Available'), findsNothing);
    enforcer.dispose();
  });
}
