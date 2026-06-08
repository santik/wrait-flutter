import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';

class HomePlaceholderScreen extends ConsumerWidget {
  const HomePlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appConfig = ref.watch(appConfigProvider);
    final recordingHardCapSeconds = appConfig.recordingHardCapMs ~/ 1000;
    final proxySecretState = appConfig.proxySecret.isEmpty
        ? 'Not configured'
        : 'Configured';

    return Scaffold(
      appBar: AppBar(title: const Text('Wrait')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Foundation ready',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 12),
                Text(
                  'This placeholder verifies app launch, routing, and runtime configuration without introducing feature logic.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),
                const Text('Backend host'),
                SelectableText(
                  appConfig.backendUri.host,
                  key: const ValueKey('backendHostValue'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                const Text('Recording hard cap'),
                Text(
                  '$recordingHardCapSeconds seconds',
                  key: const ValueKey('recordingHardCapValue'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                const Text('Proxy secret'),
                Text(
                  proxySecretState,
                  key: const ValueKey('proxySecretStateValue'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
