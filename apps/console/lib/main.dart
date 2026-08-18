import 'package:flutter/material.dart';

/// Composition root for the master console.
///
/// Zone 1.5 in the trust model: separate app, separate auth realm, separate
/// deployment, MFA required. It holds **no service-role key** — every read and
/// write is an audited RPC that re-checks the caller's role server-side (AC-4).
///
/// It is also pseudonymous by default: analytical views show `P-7F3A`, never a
/// name, and identity is never joinable with ratings (`docs/v3/12_CONSOLE.md`
/// §2).
void main() => runApp(const ConsoleApp());

/// The console shell.
class ConsoleApp extends StatelessWidget {
  /// Creates the shell.
  const ConsoleApp({super.key});

  @override
  Widget build(BuildContext context) => const MaterialApp(
    title: 'ekipa console',
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      body: Center(child: Text('ekipa console')),
    ),
  );
}
