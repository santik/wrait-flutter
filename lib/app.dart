import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/config/app_config.dart';
import 'core/router/app_router.dart';
import 'presentation/theme/wrait_theme.dart';

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
      debugShowCheckedModeBanner: false,
      theme: wraitLightTheme,
      darkTheme: wraitDarkTheme,
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
