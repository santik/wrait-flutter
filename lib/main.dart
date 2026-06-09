import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'data/entries/entry_providers.dart';
import 'data/preferences/preferences_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final appConfig = AppConfig.fromEnvironment();
  final entryDatabase = await bootstrapLocalEntryDatabase();
  final sharedPreferences = await SharedPreferences.getInstance();
  final appContainer = ProviderContainer(
    overrides: [
      appConfigProvider.overrideWithValue(appConfig),
      localEntryDatabaseProvider.overrideWithValue(entryDatabase),
      sharedPreferencesProvider.overrideWithValue(sharedPreferences),
    ],
  );

  runApp(
    UncontrolledProviderScope(container: appContainer, child: const WraitApp()),
  );
}
