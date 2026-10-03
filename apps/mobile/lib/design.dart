import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'models.dart';

const paper = Color(0xfff5f3eb);
const ink = Color(0xff171a17);
const lime = Color(0xffdfff00);
const muted = Color(0xff65685f);
const line = Color(0xffd8d9cd);

ThemeData wagzTheme() => ThemeData(
  fontFamily: 'DM Sans',
  useMaterial3: true,
  scaffoldBackgroundColor: paper,
  colorScheme: ColorScheme.fromSeed(seedColor: ink).copyWith(
    primary: ink,
    onPrimary: paper,
    secondary: lime,
    surface: paper,
    onSurface: ink,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: paper,
    foregroundColor: ink,
    elevation: 0,
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white.withValues(alpha: 0.45),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
    enabledBorder: const OutlineInputBorder(
      borderSide: BorderSide(color: line),
    ),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      minimumSize: const Size(48, 52),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
    ),
  ),
  chipTheme: ChipThemeData(
    selectedColor: lime,
    backgroundColor: paper,
    side: const BorderSide(color: line),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    labelStyle: const TextStyle(color: ink, fontWeight: FontWeight.w600),
  ),
);

class Brand extends StatelessWidget {
  const Brand({super.key});
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'WagZ — We Are Gen Z',
    excludeSemantics: true,
    child: const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'WagZ',
              style: TextStyle(
                fontFamily: 'Space Grotesk',
                fontSize: 31,
                height: 1,
                fontWeight: FontWeight.w900,
                letterSpacing: -2,
              ),
            ),
            SizedBox(width: 3),
            Icon(Icons.emergency, size: 21, color: Color(0xff728400)),
          ],
        ),
        Text(
          'WE ARE GEN Z',
          style: TextStyle(
            fontSize: 8,
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
          ),
        ),
      ],
    ),
  );
}

class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.2,
    ),
  );
}

class Notice extends StatelessWidget {
  const Notice(this.message, {super.key, this.error = false});
  final String message;
  final bool error;
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: error ? const Color(0xffffe9df) : const Color(0xffe9efca),
        border: Border.all(color: error ? const Color(0xffac4f34) : line),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(message, style: const TextStyle(height: 1.5)),
    ),
  );
}

Future<void> openSource(BuildContext context, String url) async {
  final uri = safeLink(url);
  if (uri == null) return;
  try {
    if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
  } catch (_) {
    // A missing browser is recoverable and should not dismiss the event.
  }
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Poveznicu nije moguće otvoriti na ovom uređaju.'),
      ),
    );
  }
}
