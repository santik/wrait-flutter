import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'data/api/backend_providers.dart';
import 'data/entries/entry_providers.dart';
import 'data/entries/local_entry_database.dart';
import 'data/preferences/preferences_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final appConfig = AppConfig.fromEnvironment();
  final entryDatabase = await bootstrapLocalEntryDatabase();
  final sharedPreferences = await SharedPreferences.getInstance();
  final appContainer = createAppContainer(
    appConfig: appConfig,
    entryDatabase: entryDatabase,
    sharedPreferences: sharedPreferences,
  );
  startAppLaunchWork(appContainer);

  runApp(
    UncontrolledProviderScope(container: appContainer, child: const WraitApp()),
  );
}

ProviderContainer createAppContainer({
  required AppConfig appConfig,
  SharedPreferences? sharedPreferences,
  LocalEntryDatabase? entryDatabase,
  Iterable overrides = const [],
}) {
  return ProviderContainer(
    overrides: [
      appConfigProvider.overrideWithValue(appConfig),
      if (entryDatabase != null)
        localEntryDatabaseProvider.overrideWithValue(entryDatabase),
      if (sharedPreferences != null)
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
      ...overrides,
    ],
  );
}

void startAppLaunchWork(ProviderContainer appContainer) {
  unawaited(appContainer.read(registerDeviceOnLaunchUseCaseProvider).call());
}
