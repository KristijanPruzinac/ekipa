import 'package:flutter/material.dart';
import 'data/supabase_client.dart';
import 'router.dart';
import 'theme/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initSupabase();
  runApp(const EkipaApp());
}

class EkipaApp extends StatelessWidget {
  const EkipaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Ekipa',
      debugShowCheckedModeBanner: false,
      theme: EkipaTheme.dusk,
      routerConfig: appRouter,
    );
  }
}
