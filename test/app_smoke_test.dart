import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wrait/app.dart';
import 'package:wrait/core/config/app_config.dart';
import 'package:wrait/core/router/app_router.dart';
import 'package:wrait/presentation/theme/design_tokens.dart';

void main() {
  testWidgets('renders the root placeholder shell', (tester) async {
    await tester.pumpWidget(_buildTestApp());

    await tester.pumpAndSettle();

    expect(find.text('Capture'), findsOneWidget);
    expect(find.byKey(const ValueKey('shellTitle')), findsOneWidget);
    expect(find.byKey(const ValueKey('adaptiveButtonPreview')), findsOneWidget);
  });

  testWidgets('preserves reserved status and quota space', (tester) async {
    await tester.pumpWidget(_buildTestApp());

    await tester.pumpAndSettle();

    expect(
      tester.getSize(find.byKey(const ValueKey('statusLineSlot'))).height,
      WraitStatusLineTokens.reservedHeight,
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('quotaLineSlot'))).height,
      WraitQuotaLineTokens.reservedHeight,
    );
  });
}

Widget _buildTestApp({String initialLocation = '/'}) {
  return ProviderScope(
    overrides: [
      appConfigProvider.overrideWithValue(
        const AppConfig(
          backendUrl: 'https://wrait-backend.vercel.app',
          proxySecret: '',
          recordingHardCapMs: 120000,
        ),
      ),
      appRouterProvider.overrideWithValue(
        buildAppRouter(initialLocation: initialLocation),
      ),
    ],
    child: const WraitApp(),
  );
}
