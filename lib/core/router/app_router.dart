import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../presentation/main/main_screen.dart';
import '../../presentation/shell/shell_placeholder_screen.dart';

GoRouter buildAppRouter({String? initialLocation}) {
  return GoRouter(
    initialLocation: _resolveInitialLocation(initialLocation),
    routes: [
      GoRoute(path: '/', builder: (context, state) => const MainScreen()),
      GoRoute(
        path: '/entries',
        builder: (context, state) => const ShellPlaceholderScreen(
          title: 'Entries',
          description:
              'The entries route is ready to host browsing and summary views once entry data arrives.',
        ),
      ),
      GoRoute(
        path: '/entry/:id',
        redirect: (context, state) {
          final entryId = state.pathParameters['id']?.trim() ?? '';
          return entryId.isEmpty ? '/entries' : null;
        },
        builder: (context, state) {
          final entryId = state.pathParameters['id']!.trim();

          return ShellPlaceholderScreen(
            title: 'Entry preview',
            description:
                'Individual entry content will render here once entry loading and detail flows are implemented.',
            entryId: entryId,
          );
        },
      ),
    ],
  );
}

String _resolveInitialLocation(String? initialLocation) {
  if (initialLocation case final explicitLocation?) {
    return explicitLocation;
  }

  final platformRoute =
      WidgetsBinding.instance.platformDispatcher.defaultRouteName;
  if (platformRoute.isNotEmpty && platformRoute != Navigator.defaultRouteName) {
    return platformRoute;
  }

  return '/';
}
