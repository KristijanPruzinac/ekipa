import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as timezone;
import 'api.dart';
import 'design.dart';
import 'home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  timezone.initializeTimeZones();
  await initializeDateFormatting('hr');
  final preferences = await SharedPreferences.getInstance();
  runApp(
    WagzApp(
      api: WagzApi(baseUrl: const String.fromEnvironment('WAGZ_API_BASE_URL')),
      preferences: preferences,
    ),
  );
}

class WagzApp extends StatelessWidget {
  const WagzApp({super.key, required this.api, required this.preferences});
  final WagzApi api;
  final SharedPreferences preferences;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'WagZ — We Are Gen Z',
    debugShowCheckedModeBanner: false,
    theme: wagzTheme(),
    locale: const Locale('hr'),
    supportedLocales: const [Locale('hr')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    home: HomeScreen(api: api, preferences: preferences),
  );
}
