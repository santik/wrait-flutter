import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'data/entries/entry_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final appConfig = AppConfig.fromEnvironment();
  final entryDatabase = await bootstrapLocalEntryDatabase();
  final appContainer = ProviderContainer(
    overrides: [
      appConfigProvider.overrideWithValue(appConfig),
      localEntryDatabaseProvider.overrideWithValue(entryDatabase),
    ],
  );

  runApp(
    UncontrolledProviderScope(container: appContainer, child: const WraitApp()),
  );
}
