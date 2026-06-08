import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wrait/app.dart';
import 'package:wrait/core/config/app_config.dart';

void main() {
  testWidgets('renders the placeholder shell', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(
              backendUrl: 'https://wrait-backend.vercel.app',
              proxySecret: '',
              recordingHardCapMs: 120000,
            ),
          ),
        ],
        child: const WraitApp(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Foundation ready'), findsOneWidget);
    expect(find.byKey(const ValueKey('backendHostValue')), findsOneWidget);
    expect(find.text('wrait-backend.vercel.app'), findsOneWidget);
    expect(find.byKey(const ValueKey('recordingHardCapValue')), findsOneWidget);
    expect(find.text('120 seconds'), findsOneWidget);
    expect(find.byKey(const ValueKey('proxySecretStateValue')), findsOneWidget);
    expect(find.text('Not configured'), findsOneWidget);
  });
}
