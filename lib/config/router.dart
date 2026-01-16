import 'package:go_router/go_router.dart';

import '../screen/splash/splash_screen.dart';
import '../screen/home/home_screen.dart';
import '../screen/database/database_detail_screen.dart';
import '../screen/table/table_detail_screen.dart';
import '../screen/scanner/qr_scanner_screen.dart';

final GoRouter router = GoRouter(
  initialLocation: '/', //root route
  routes: [
    // Splash Screen
    GoRoute(path: '/', builder: (context, state) => const SplashScreen()),

    // Home Screen (List Database)
    GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),

    GoRoute(
      path: '/table/:id',
      builder: (context, state) {
        final id = int.parse(state.pathParameters['id']!);
        return TableDetailScreen(tableId: id);
      },
    ),

    GoRoute(
      path: '/scanner',
      builder: (context, state) => const QrScannerScreen(),
    ),

    // Database Detail (Isi Tabel)
    GoRoute(
      path: '/database/:id',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return DatabaseDetailScreen(databaseId: id);
      },
    ),
  ],
);
