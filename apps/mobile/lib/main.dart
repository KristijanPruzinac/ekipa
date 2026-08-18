import 'package:flutter/material.dart';

/// Composition root for the mobile app.
///
/// Deliberately empty of behaviour. The app is a thin cache over server truth
/// and owns no rules: every privacy and trust decision is made server-side and
/// rendered here (`docs/v3/11_SECURITY.md` §2).
///
/// Note what is *not* imported: `package:ekipa_core/matching.dart`. Directive
/// D9 keeps the matcher out of every user build, and `tools/lint` fails the
/// build if it ever appears here.
void main() => runApp(const EkipaApp());

/// The application shell.
class EkipaApp extends StatelessWidget {
  /// Creates the shell.
  const EkipaApp({super.key});

  @override
  Widget build(BuildContext context) => const MaterialApp(
    title: 'ekipa',
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      backgroundColor: Color(0xFF131719),
      body: Center(
        child: Text(
          'ekipa',
          style: TextStyle(
            color: Color(0xFFF2F4F3),
            fontSize: 32,
            fontWeight: FontWeight.w800,
            letterSpacing: -1,
          ),
        ),
      ),
    ),
  );
}
