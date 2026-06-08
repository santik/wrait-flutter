import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/config/app_config.dart';
import 'core/router/app_router.dart';

final appConfigProvider = Provider<AppConfig>(
  (ref) =>
      throw UnimplementedError('AppConfig must be provided at app startup.'),
);

final appRouterProvider = Provider<GoRouter>((ref) => buildAppRouter());

class WraitApp extends ConsumerWidget {
  const WraitApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Wrait',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1E6A5A)),
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}
