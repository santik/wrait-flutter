import 'package:go_router/go_router.dart';

import '../../presentation/home/home_placeholder_screen.dart';

GoRouter buildAppRouter() {
  return GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const HomePlaceholderScreen(),
      ),
    ],
  );
}
